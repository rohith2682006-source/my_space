import { createHash, timingSafeEqual } from 'crypto';
import { basename } from 'path';
import { prisma } from '../../config/database';
import { storage } from '../../services/storage';
import { AppError, ForbiddenError, InternalError, NotFoundError } from '../../utils/errors';
import { env } from '../../config/env';
import { RealtimeService } from '../../services/realtime.service';

const MAX_CANDIDATES = Number(process.env.AI_MAX_CANDIDATES ?? 1000);
const TOP_K = Number(process.env.AI_TOP_K ?? 8);
const MIN_SIMILARITY = Number(process.env.AI_MIN_SIMILARITY ?? 0.18);
const INDEXABLE_EXTENSIONS = new Set([
  '.pdf',
  '.pptx',
  '.ppt',
  '.docx',
  '.doc',
  '.txt',
  '.md',
  '.markdown',
  '.csv',
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.mp4',
  '.webm',
  '.mov',
  '.mp3',
  '.wav',
  '.m4a',
]);
const MAX_INDEX_FILE_BYTES = 50 * 1024 * 1024; // 50MB max file size for direct indexing

import { indexCallbackSchema, IndexCallbackInput } from './ai.schema';
export { IndexCallbackInput };

export interface IndexedChunkInput {
  id: string;
  fileId: string;
  spaceId: string;
  ownerId: string;
  content: string;
  prefixedContent?: string | null;
  location?: string | null;
  embedding: number[];
  metadata: Record<string, string>;
  pageNumber?: number | null;
  chunkIndex: number;
}

export interface FolderManifestFile {
  id: string;
  name: string;
  type: string;
  size_bytes: number;
  updated_at: string;
  status: string;
  summary: string | null;
  keywords: string[];
  page_count: number | null;
}

export interface FolderManifest {
  space_id: string;
  space_name: string;
  total_files: number;
  ready_files: number;
  indexing_files: number;
  failed_files: number;
  files: FolderManifestFile[];
}

function isValidServiceToken(candidate: string | undefined): boolean {
  const expected = process.env.AI_SERVICE_TOKEN ?? '';
  if (!candidate || !expected) return false;
  const candidateBuffer = Buffer.from(candidate);
  const expectedBuffer = Buffer.from(expected);
  return candidateBuffer.length === expectedBuffer.length && timingSafeEqual(candidateBuffer, expectedBuffer);
}

function parseEmbedding(serialized: string): number[] | null {
  try {
    const value: unknown = JSON.parse(serialized);
    return Array.isArray(value) && value.every((item) => typeof item === 'number' && Number.isFinite(item))
      ? value
      : null;
  } catch {
    return null;
  }
}

export function cosineSimilarity(left: number[], right: number[]): number {
  if (left.length === 0 || left.length !== right.length) return -1;
  let dotProduct = 0;
  let leftMagnitude = 0;
  let rightMagnitude = 0;
  for (let index = 0; index < left.length; index += 1) {
    dotProduct += left[index] * right[index];
    leftMagnitude += left[index] ** 2;
    rightMagnitude += right[index] ** 2;
  }
  if (leftMagnitude === 0 || rightMagnitude === 0) return -1;
  return dotProduct / (Math.sqrt(leftMagnitude) * Math.sqrt(rightMagnitude));
}

const STOP_WORDS = new Set([
  'about', 'after', 'and', 'are', 'can', 'did', 'for', 'from', 'find', 'help',
  'how', 'into', 'me', 'my', 'note', 'notes', 'please', 'show', 'that', 'the',
  'their', 'them', 'there', 'this', 'what', 'when', 'where', 'which', 'with',
  'would', 'write', 'written', 'you',
]);

export function filterAccessibleSpaceIds(
  accessibleSpaceIds: string[],
  requestedSpaceIds: string[],
): string[] {
  const allowedSpaceIds = new Set(accessibleSpaceIds);
  return requestedSpaceIds.length > 0
    ? [...new Set(requestedSpaceIds.filter((spaceId) => allowedSpaceIds.has(spaceId)))]
    : [...allowedSpaceIds];
}

export class AiService {
  isServiceTokenValid(authorization: string | undefined): boolean {
    const [scheme, token] = authorization?.split(/\s+/, 2) ?? [];
    return scheme?.toLowerCase() === 'bearer' && isValidServiceToken(token);
  }

  async requestEmbedding(text: string): Promise<number[]> {
    const aiUrl = env.AI_SERVICE_URL || 'http://127.0.0.1:8000';
    const aiToken = env.AI_SERVICE_TOKEN || '';
    let response: Response;
    try {
      response = await fetch(`${aiUrl}/embeddings`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${aiToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
        signal: AbortSignal.timeout(30_000),
      });
    } catch (err: any) {
      if (err?.name === 'TimeoutError' || err?.name === 'AbortError') {
        throw new AppError('AI embedding request timed out', 504, 'AI_TIMEOUT');
      }
      throw new AppError(`Python AI service is unreachable at ${aiUrl}`, 503, 'AI_UNAVAILABLE');
    }

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      const detail = (errorBody as { detail?: string }).detail;
      if (response.status === 401) {
        throw new AppError(detail || 'AI authentication failed. Invalid API credentials.', 401, 'AI_AUTH_ERROR');
      }
      if (response.status === 402) {
        throw new AppError(detail || 'Gemini quota or credit balance exhausted.', 402, 'AI_QUOTA_EXHAUSTED');
      }
      if (response.status === 429) {
        throw new AppError(detail || 'AI rate limit reached. Please try again shortly.', 429, 'AI_RATE_LIMITED');
      }
      if (response.status === 502) {
        throw new AppError(detail || 'Upstream AI provider error. Please try again.', 502, 'AI_PROVIDER_ERROR');
      }
      if (response.status >= 500) {
        throw new AppError('AI service is temporarily unavailable', 503, 'AI_UNAVAILABLE');
      }
      throw new AppError(detail || `Embedding service returned status ${response.status}`, response.status, 'AI_REQUEST_FAILED');
    }

    const data = (await response.json()) as { embedding?: unknown };
    if (!Array.isArray(data.embedding) || !data.embedding.every((value) => typeof value === 'number' && Number.isFinite(value))) {
      throw new InternalError('Embedding service returned an invalid vector', 'AI_INVALID_RESPONSE');
    }
    return data.embedding as number[];
  }

  private queryCache = new Map<string, { result: any; expiresAt: number }>();

  makeCacheKey(spaceId: string, fileId: string | undefined, query: string): string {
    const norm = query.trim().toLowerCase().replace(/\s+/g, ' ');
    return `${spaceId}:${fileId || 'all'}:${createHash('sha256').update(norm).digest('hex')}`;
  }

  getQueryCache(key: string): any | null {
    const entry = this.queryCache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.queryCache.delete(key);
      return null;
    }
    return entry.result;
  }

  setQueryCache(key: string, result: any, ttlMs: number = 3600_000) {
    this.queryCache.set(key, { result, expiresAt: Date.now() + ttlMs });
  }

  invalidateSpaceCache(spaceId: string) {
    for (const key of this.queryCache.keys()) {
      if (key.startsWith(`${spaceId}:`)) {
        this.queryCache.delete(key);
      }
    }
  }

  async rewriteQuery(message: string, history: Array<{ role: string; content: string }>): Promise<string> {
    if (!history || history.length === 0) return message.trim();
    const aiUrl = env.AI_SERVICE_URL || 'http://127.0.0.1:8000';
    const aiToken = env.AI_SERVICE_TOKEN || '';
    try {
      const response = await fetch(`${aiUrl}/rag/rewrite-query`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${aiToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message, history }),
        signal: AbortSignal.timeout(10_000),
      });
      if (response.ok) {
        const data = (await response.json()) as { query?: string };
        if (data.query && data.query.trim()) {
          return data.query.trim();
        }
      }
    } catch (err) {
      console.warn('Query rewrite service unreachable, using original query:', err);
    }
    return message.trim();
  }

  async buildFolderManifest(
    userId: string,
    spaceId: string,
    targetFileIds?: string[],
  ): Promise<FolderManifest> {
    const space = await prisma.space.findFirst({
      where: {
        id: spaceId,
        deletedAt: null,
      },
      select: {
        id: true,
        name: true,
        ownerId: true,
        isPrivate: true,
        members: {
          where: { userId, status: 'ACCEPTED' },
          select: { id: true },
        },
      },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    const isOwner = space.ownerId === userId;
    const isMember = space.members.length > 0;
    if (space.isPrivate && !isOwner && !isMember) {
      throw new ForbiddenError('You do not have access to this Space');
    }

    const fileWhere: any = {
      spaceId: space.id,
      deletedAt: null,
      trashedAt: null,
    };

    if (targetFileIds && targetFileIds.length > 0) {
      fileWhere.id = { in: targetFileIds };
    }

    const files = await prisma.file.findMany({
      where: fileWhere,
      select: {
        id: true,
        name: true,
        originalName: true,
        extension: true,
        size: true,
        updatedAt: true,
        indexStatus: true,
        summary: true,
        keywords: true,
        pageCount: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    const manifestFiles: FolderManifestFile[] = files.map((file) => {
      let parsedKeywords: string[] = [];
      try {
        if (file.keywords) {
          const parsed = JSON.parse(file.keywords);
          if (Array.isArray(parsed)) {
            parsedKeywords = parsed.map(String);
          }
        }
      } catch {
        parsedKeywords = [];
      }

      return {
        id: file.id,
        name: file.originalName || file.name,
        type: file.extension || 'file',
        size_bytes: Number(file.size),
        updated_at: file.updatedAt.toISOString(),
        status: file.indexStatus,
        summary: file.summary ?? null,
        keywords: parsedKeywords,
        page_count: file.pageCount ?? null,
      };
    });

    const readyFiles = manifestFiles.filter((f) => f.status === 'READY').length;
    const failedFiles = manifestFiles.filter((f) => f.status === 'FAILED').length;
    const indexingFiles = manifestFiles.filter((f) => !['READY', 'FAILED'].includes(f.status)).length;

    return {
      space_id: space.id,
      space_name: space.name,
      total_files: manifestFiles.length,
      ready_files: readyFiles,
      indexing_files: indexingFiles,
      failed_files: failedFiles,
      files: manifestFiles,
    };
  }

  async searchAccessibleChunks(
    userId: string,
    query: string,
    queryVector: number[],
    requestedSpaceIds: string[],
    fileId?: string,
    targetFileIds?: string[],
  ) {
    const spaces = await prisma.space.findMany({
      where: {
        deletedAt: null,
        OR: [
          { ownerId: userId },
          { isPrivate: false },
          { members: { some: { userId, status: 'ACCEPTED' } } },
        ],
      },
      select: { id: true },
    });
    const accessibleSpaceIds = filterAccessibleSpaceIds(
      spaces.map((space) => space.id),
      requestedSpaceIds,
    );
    if (accessibleSpaceIds.length === 0) return { candidates: [], accessibleSpaceCount: 0 };

    const fileFilter: any = {
      spaceId: { in: accessibleSpaceIds },
      deletedAt: null,
      trashedAt: null,
      aiSearchEnabled: true,
      indexStatus: 'READY',
    };
    if (fileId) {
      fileFilter.id = fileId;
    } else if (targetFileIds && targetFileIds.length > 0) {
      fileFilter.id = { in: targetFileIds };
    }

    const chunkFileIdCondition = fileId
      ? fileId
      : (targetFileIds && targetFileIds.length > 0 ? { in: targetFileIds } : undefined);

    // 1. Fetch chunks from new 'Chunk' model (with fallback to legacy 'FileChunk')
    const primaryChunks = await prisma.chunk.findMany({
      where: {
        spaceId: { in: accessibleSpaceIds },
        fileId: chunkFileIdCondition,
        file: fileFilter,
      },
      take: MAX_CANDIDATES,
      select: {
        id: true,
        fileId: true,
        spaceId: true,
        fileName: true,
        location: true,
        content: true,
        embedding: true,
        file: {
          select: {
            name: true,
            originalName: true,
            extension: true,
            updatedAt: true,
            space: { select: { name: true } },
          },
        },
      },
    });

    type NormalizedChunk = {
      chunkId: string;
      documentId: string;
      fileId: string;
      spaceId: string;
      fileName: string;
      fileType: string;
      spaceName: string;
      updatedAt: string;
      excerpt: string;
      pageNumber: number | null;
      location: string;
      chunkIndex?: number;
      embedding: string;
    };

    let allChunks: NormalizedChunk[] = [];

    if (primaryChunks.length > 0) {
      allChunks = primaryChunks.map((c) => {
        const pageMatch = c.location.match(/(?:page|slide)\s+(\d+)/i);
        const pageNumber = pageMatch ? parseInt(pageMatch[1], 10) : null;
        return {
          chunkId: c.id,
          documentId: c.fileId,
          fileId: c.fileId,
          spaceId: c.spaceId,
          fileName: c.file.originalName || c.fileName || c.file.name,
          fileType: c.file.extension.toLowerCase(),
          spaceName: c.file.space.name,
          updatedAt: c.file.updatedAt.toISOString(),
          excerpt: c.content,
          pageNumber,
          location: c.location,
          embedding: c.embedding,
        };
      });
    } else {
      // Fallback to legacy fileChunks
      const legacyChunks = await prisma.fileChunk.findMany({
        where: {
          spaceId: { in: accessibleSpaceIds },
          fileId: chunkFileIdCondition,
          file: fileFilter,
        },
        take: MAX_CANDIDATES,
        select: {
          id: true,
          fileId: true,
          spaceId: true,
          content: true,
          embedding: true,
          pageNumber: true,
          chunkIndex: true,
          file: {
            select: {
              name: true,
              originalName: true,
              extension: true,
              updatedAt: true,
              space: { select: { name: true } },
            },
          },
        },
      });

      allChunks = legacyChunks.map((c) => ({
        chunkId: c.id,
        documentId: c.fileId,
        fileId: c.fileId,
        spaceId: c.spaceId,
        fileName: c.file.originalName || c.file.name,
        fileType: c.file.extension.toLowerCase(),
        spaceName: c.file.space.name,
        updatedAt: c.file.updatedAt.toISOString(),
        excerpt: c.content,
        pageNumber: c.pageNumber,
        location: c.pageNumber ? `page ${c.pageNumber}` : 'document',
        embedding: c.embedding,
      }));
    }

    if (allChunks.length === 0) {
      return { candidates: [], accessibleSpaceCount: accessibleSpaceIds.length };
    }

    // If targeted to a single document (explicit fileId, targetFileIds of 1, or space with single file when query asks to explain/summarize),
    // return all chunks in sequential order (page/chunkIndex ASC) up to 100 chunks without distance cutoff.
    const uniqueFileIds = new Set(allChunks.map((c) => c.fileId));
    const isExplicitSingleDoc = Boolean(fileId || (targetFileIds && targetFileIds.length === 1));
    const isDocQuery = /\b(explain|summarize|review|analyze|analyse|walkthrough|slide by slide|page by page|tell me about|what is in|what's in)\b/i.test(query)
      || /\.(pptx?|pdf|docx?|txt|csv|xlsx?)\b/i.test(query);
    const isSingleDoc = isExplicitSingleDoc || (uniqueFileIds.size === 1 && isDocQuery);

    if (isSingleDoc) {
      const targetId = fileId || (targetFileIds && targetFileIds.length === 1 ? targetFileIds[0] : allChunks[0].fileId);
      const docChunks = allChunks.filter((c) => c.fileId === targetId);
      const sequentialCandidates = (docChunks.length > 0 ? docChunks : allChunks)
        .sort((a, b) => {
          const pageA = a.pageNumber ?? 0;
          const pageB = b.pageNumber ?? 0;
          if (pageA !== pageB) return pageA - pageB;
          return (a.chunkIndex ?? 0) - (b.chunkIndex ?? 0);
        })
        .slice(0, 100)
        .map((chunk) => ({
          chunkId: chunk.chunkId,
          documentId: chunk.documentId,
          fileId: chunk.fileId,
          spaceId: chunk.spaceId,
          fileName: chunk.fileName,
          fileType: chunk.fileType,
          spaceName: chunk.spaceName,
          updatedAt: chunk.updatedAt,
          excerpt: chunk.excerpt,
          pageNumber: chunk.pageNumber,
          location: chunk.location,
          chunkIndex: chunk.chunkIndex ?? 0,
          score: 1.0,
        }));

      return {
        candidates: sequentialCandidates,
        accessibleSpaceCount: accessibleSpaceIds.length,
      };
    }

    // 2. Parallel Hybrid Search for multi-document / general deep fact search:
    // A) Vector similarity ranking (top 20)
    const vectorScored = allChunks
      .map((chunk) => {
        const vec = parseEmbedding(chunk.embedding);
        const sim = vec ? cosineSimilarity(queryVector, vec) : -1;
        return { chunk, sim };
      })
      .filter((item) => item.sim > -1)
      .sort((a, b) => b.sim - a.sim)
      .slice(0, 20);

    // B) Keyword / full-text ranking (top 20)
    const terms = [...new Set((query.toLocaleLowerCase().match(/[\p{L}\p{N}]{2,}/gu) ?? [])
      .filter((term) => !STOP_WORDS.has(term)))];

    const keywordScored = allChunks
      .map((chunk) => {
        const text = (chunk.excerpt + ' ' + chunk.fileName).toLocaleLowerCase();
        let matches = 0;
        for (const term of terms) {
          if (text.includes(term)) matches++;
        }
        const kwScore = terms.length > 0 ? matches / terms.length : 0;
        return { chunk, kwScore };
      })
      .filter((item) => item.kwScore > 0)
      .sort((a, b) => b.kwScore - a.kwScore)
      .slice(0, 20);

    // C) Reciprocal Rank Fusion (RRF, k=60)
    const k = 60;
    const rrfMap = new Map<string, { chunk: NormalizedChunk; rrfScore: number; sim: number }>();

    vectorScored.forEach((item, rank) => {
      const existing = rrfMap.get(item.chunk.chunkId);
      const score = 1.0 / (k + rank + 1);
      if (existing) {
        existing.rrfScore += score;
        existing.sim = Math.max(existing.sim, item.sim);
      } else {
        rrfMap.set(item.chunk.chunkId, { chunk: item.chunk, rrfScore: score, sim: item.sim });
      }
    });

    keywordScored.forEach((item, rank) => {
      const existing = rrfMap.get(item.chunk.chunkId);
      const score = 1.0 / (k + rank + 1);
      if (existing) {
        existing.rrfScore += score;
      } else {
        const vec = parseEmbedding(item.chunk.embedding);
        const sim = vec ? cosineSimilarity(queryVector, vec) : 0;
        rrfMap.set(item.chunk.chunkId, { chunk: item.chunk, rrfScore: score, sim });
      }
    });

    const merged = Array.from(rrfMap.values())
      .sort((a, b) => b.rrfScore - a.rrfScore);

    // Distance Cutoff check:
    // If the best semantic similarity is below MIN_SIMILARITY and no keyword matches, return empty candidates
    const bestSim = merged.length > 0 ? Math.max(...merged.map((m) => m.sim)) : 0;
    if (bestSim < MIN_SIMILARITY && keywordScored.length === 0) {
      return { candidates: [], accessibleSpaceCount: accessibleSpaceIds.length };
    }

    const topCandidates = merged.slice(0, 20).map(({ chunk, rrfScore, sim }) => ({
      chunkId: chunk.chunkId,
      documentId: chunk.documentId,
      fileId: chunk.fileId,
      spaceId: chunk.spaceId,
      fileName: chunk.fileName,
      fileType: chunk.fileType,
      spaceName: chunk.spaceName,
      updatedAt: chunk.updatedAt,
      excerpt: chunk.excerpt,
      pageNumber: chunk.pageNumber,
      location: chunk.location,
      chunkIndex: chunk.chunkIndex ?? 0,
      score: Math.min(1.0, sim * 0.7 + rrfScore * 10 * 0.3),
    }));

    return {
      candidates: topCandidates,
      accessibleSpaceCount: accessibleSpaceIds.length,
    };
  }


  async queueFileIndex(fileId: string, fileName: string, fileType: string, content: Buffer, ownerId: string, spaceId: string): Promise<void> {
    const extension = `.${fileType.toLowerCase()}`;
    if (!INDEXABLE_EXTENSIONS.has(extension)) return;

    if (!process.env.AI_SERVICE_TOKEN) {
      await prisma.file.update({
        where: { id: fileId },
        data: { indexStatus: 'FAILED', indexError: 'AI service token is not configured.' },
      });
      return;
    }

    if (content.length > MAX_INDEX_FILE_BYTES) {
      await prisma.file.update({
        where: { id: fileId },
        data: { indexStatus: 'FAILED', indexError: 'File exceeds the indexing size limit.' },
      });
      return;
    }

    try {
      const form = new FormData();
      form.set('file_id', fileId);
      form.set('space_id', spaceId);
      form.set('owner_id', ownerId);
      form.set('file_name', basename(fileName));
      form.set('file_type', extension.slice(1));
      form.set('file', new Blob([new Uint8Array(content)], { type: 'application/octet-stream' }), basename(fileName));
      const aiUrl = env.AI_SERVICE_URL || 'http://127.0.0.1:8000';
      const aiToken = env.AI_SERVICE_TOKEN || '';
      const response = await fetch(`${aiUrl}/documents/index`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${aiToken}` },
        body: form,
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) {
        await prisma.file.update({
          where: { id: fileId },
          data: { indexStatus: 'FAILED', indexError: 'Document indexing service is unavailable.' },
        });
      }
    } catch {
      await prisma.file.update({
        where: { id: fileId },
        data: { indexStatus: 'FAILED', indexError: 'Document indexing service is unavailable.' },
      });
    }
  }

  async reindexFile(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null, trashedAt: null },
      include: {
        space: {
          select: {
            ownerId: true,
            members: { where: { userId, status: 'ACCEPTED' }, select: { role: true } },
          },
        },
      },
    });
    if (!file) return null;
    const membership = file.space.members[0];
    if (
      file.space.ownerId !== userId &&
      (!membership || !['EDITOR', 'ADMIN', 'OWNER'].includes(membership.role))
    ) {
      throw new ForbiddenError('Edit permissions are required to reindex this document');
    }
    if (!file.aiSearchEnabled) {
      throw new AppError('Enable AI Search for this file before indexing it', 409, 'AI_SEARCH_DISABLED');
    }
    if (!INDEXABLE_EXTENSIONS.has(`.${file.extension.toLowerCase()}`)) return { status: 'UNSUPPORTED' };

    await prisma.file.update({
      where: { id: fileId },
      data: { indexStatus: 'PROCESSING', indexError: null },
    });
    const content = file.content !== null && file.category === 'NOTE'
      ? Buffer.from(file.content, 'utf-8')
      : await storage.download(file.storageKey);
    await this.queueFileIndex(
      file.id,
      file.originalName || file.name,
      file.extension,
      content,
      file.space.ownerId || userId,
      file.spaceId,
    );
    return { status: 'PROCESSING' };
  }

  async reindexExistingDocuments(userId: string, excludeFileIds: string[] = []) {
    const spaces = await prisma.space.findMany({
      where: {
        deletedAt: null,
        OR: [
          { ownerId: userId },
          {
            members: {
              some: {
                userId,
                status: 'ACCEPTED',
                role: { in: ['EDITOR', 'ADMIN', 'OWNER'] },
              },
            },
          },
        ],
      },
      select: { id: true },
    });
    const spaceIds = spaces.map((space) => space.id);
    if (spaceIds.length === 0) return { queuedFileIds: [] };

    const files = await prisma.file.findMany({
      where: {
        spaceId: { in: spaceIds },
        deletedAt: null,
        trashedAt: null,
        id: { notIn: excludeFileIds },
        extension: { in: ['pdf', 'txt', 'md', 'markdown'] },
        aiSearchEnabled: true,
        indexStatus: { in: ['NOT_INDEXED', 'FAILED', 'OCR_REQUIRED'] },
      },
      take: 100,
      orderBy: { updatedAt: 'desc' },
      include: { space: { select: { ownerId: true } } },
    });

    for (const file of files) {
      await prisma.file.update({
        where: { id: file.id },
        data: { indexStatus: 'PROCESSING', indexError: null },
      });
      try {
        const content = file.content !== null && file.category === 'NOTE'
          ? Buffer.from(file.content, 'utf-8')
          : await storage.download(file.storageKey);
        await this.queueFileIndex(
          file.id,
          file.originalName || file.name,
          file.extension,
          content,
          file.space.ownerId,
          file.spaceId,
        );
      } catch {
        await prisma.file.update({
          where: { id: file.id },
          data: { indexStatus: 'FAILED', indexError: 'Document could not be loaded for indexing.' },
        });
      }
    }

    return { queuedFileIds: files.map((file) => file.id) };
  }

  async completeIndexing(rawInput: IndexCallbackInput) {
    const input = indexCallbackSchema.parse(rawInput);
    if (input.status === 'READY' && input.chunks.some((chunk) => chunk.fileId !== input.fileId)) {
      throw new Error('Index callback contains chunks for another document');
    }

    await prisma.$transaction(async (transaction) => {
      const file = await transaction.file.findUnique({
        where: { id: input.fileId },
        select: {
          id: true,
          spaceId: true,
          name: true,
          originalName: true,
          aiSearchEnabled: true,
          deletedAt: true,
          trashedAt: true,
          space: { select: { ownerId: true } },
        },
      });
      if (!file || !file.aiSearchEnabled || file.deletedAt || file.trashedAt) return;

      const fileName = file.originalName || file.name;

      const isIntermediate = [
        'EXTRACTING',
        'CHUNKING',
        'EMBEDDING',
        'SUMMARIZING',
        'INDEXING',
      ].includes(input.status);

      if (!isIntermediate) {
        await transaction.chunk.deleteMany({ where: { fileId: file.id } });
        await transaction.fileChunk.deleteMany({ where: { fileId: file.id } });
      }

      if (input.status === 'READY') {
        const ragChunks = input.chunks.map((chunk) => ({
          id: chunk.id,
          spaceId: file.spaceId,
          fileId: file.id,
          fileName: chunk.metadata?.fileName || fileName,
          location: chunk.location || (chunk.pageNumber ? `page ${chunk.pageNumber}` : 'document'),
          content: chunk.content,
          embedding: JSON.stringify(chunk.embedding),
          embedModel: 'gemini-embedding-2',
        }));

        for (let offset = 0; offset < ragChunks.length; offset += 50) {
          const batch = ragChunks.slice(offset, offset + 50);
          if (batch.length > 0) {
            await transaction.chunk.createMany({ data: batch });
          }
        }

        const legacyChunks = input.chunks.map((chunk) => ({
          id: chunk.id,
          fileId: file.id,
          spaceId: file.spaceId,
          ownerId: file.space.ownerId,
          content: chunk.content,
          embedding: JSON.stringify(chunk.embedding),
          metadata: JSON.stringify(chunk.metadata ?? {}),
          pageNumber: chunk.pageNumber ?? null,
          chunkIndex: chunk.chunkIndex,
        }));

        for (let offset = 0; offset < legacyChunks.length; offset += 50) {
          const batch = legacyChunks.slice(offset, offset + 50);
          if (batch.length > 0) {
            await transaction.fileChunk.createMany({ data: batch });
          }
        }
      }

      // Update both file and fileIndexStatus
      const ragStatus = input.status === 'READY'
        ? 'ready'
        : input.status === 'FAILED'
        ? 'failed'
        : input.status.toLowerCase();

      await transaction.fileIndexStatus.upsert({
        where: { fileId: file.id },
        create: {
          fileId: file.id,
          spaceId: file.spaceId,
          status: ragStatus,
          error: input.status === 'FAILED' ? input.error ?? 'Document indexing failed.' : null,
        },
        update: {
          status: ragStatus,
          error: input.status === 'FAILED' ? input.error ?? 'Document indexing failed.' : null,
        },
      });

      const updateData: any = {
        indexStatus: input.status,
        indexError: input.status === 'FAILED' ? input.error ?? 'Document indexing failed.' : null,
      };

      if (input.summary !== undefined && input.summary !== null) {
        updateData.summary = input.summary;
      }
      if (input.keywords && input.keywords.length > 0) {
        updateData.keywords = JSON.stringify(input.keywords);
      }
      if (input.pageCount !== undefined && input.pageCount !== null) {
        updateData.pageCount = input.pageCount;
      }
      if (input.extractedText !== undefined && input.extractedText !== null) {
        updateData.extractedText = input.extractedText;
      }

      await transaction.file.update({
        where: { id: file.id },
        data: updateData,
      });

      // Compute Space readiness metrics
      const totalFilesInSpace = await transaction.file.count({
        where: { spaceId: file.spaceId, deletedAt: null, trashedAt: null },
      });
      const readyFilesInSpace = await transaction.file.count({
        where: { spaceId: file.spaceId, indexStatus: 'READY', deletedAt: null, trashedAt: null },
      });

      const progressPayload = {
        fileId: file.id,
        spaceId: file.spaceId,
        fileName: file.originalName || file.name,
        status: input.status,
        stage: input.status.toLowerCase(),
        error: input.error ?? null,
        readyFiles: readyFilesInSpace,
        totalFiles: totalFilesInSpace,
        progressText: input.status === 'READY'
          ? `${readyFilesInSpace} of ${totalFilesInSpace} files ready`
          : `Indexing ${readyFilesInSpace} of ${totalFilesInSpace} files (${input.status.toLowerCase()})...`,
        chunksIndexed: input.chunks.length,
      };

      RealtimeService.emitToUser(file.space.ownerId, 'AI_PROGRESS', progressPayload);
      if (input.status === 'READY' || input.status === 'FAILED') {
        RealtimeService.emitToUser(
          file.space.ownerId,
          input.status === 'READY' ? 'AI_READY' : 'AI_FAILED',
          progressPayload,
        );
      }
    });
  }

  async reindexSpace(spaceId: string, userId: string) {
    const space = await prisma.space.findFirst({
      where: {
        id: spaceId,
        deletedAt: null,
        OR: [
          { ownerId: userId },
          { members: { some: { userId, status: 'ACCEPTED', role: { in: ['EDITOR', 'ADMIN', 'OWNER'] } } } },
        ],
      },
      select: { id: true, ownerId: true },
    });
    if (!space) {
      throw new ForbiddenError('You do not have permission to reindex files in this space');
    }

    const files = await prisma.file.findMany({
      where: {
        spaceId,
        deletedAt: null,
        trashedAt: null,
        aiSearchEnabled: true,
      },
      select: { id: true },
    });

    const queuedFileIds: string[] = [];
    for (const file of files) {
      try {
        await this.reindexFile(file.id, userId);
        queuedFileIds.push(file.id);
      } catch (err) {
        console.warn(`Failed to enqueue reindex for file ${file.id}:`, err);
      }
    }

    return { spaceId, queuedCount: queuedFileIds.length, queuedFileIds };
  }


  isSupportedDocument(fileName: string): boolean {
    return INDEXABLE_EXTENSIONS.has(`.${fileName.split('.').pop()?.toLowerCase() ?? ''}`);
  }

  async getIndexStatus(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: {
        id: fileId,
        deletedAt: null,
        trashedAt: null,
        space: {
          is: {
            deletedAt: null,
            OR: [
              { ownerId: userId },
              { isPrivate: false },
              { members: { some: { userId, status: 'ACCEPTED' } } },
            ],
          },
        },
      },
      select: { id: true, name: true, indexStatus: true, indexError: true },
    });
    return file;
  }

  async logSearch(
    query: string,
    userId: string,
    candidates: Array<{ chunkId: string; score: number }>,
    latencyMs: number,
  ): Promise<void> {
    const queryHash = createHash('sha256').update(query).digest('hex').slice(0, 12);
    console.info(JSON.stringify({
      event: 'deep_search',
      userId,
      queryHash,
      chunksRetrieved: candidates.length,
      retrievedChunkIds: candidates.map((candidate) => candidate.chunkId),
      similarityScores: candidates.map((candidate) => Number(candidate.score.toFixed(4))),
      latencyMs: Number(latencyMs.toFixed(1)),
    }));
  }
}

export const aiService = new AiService();