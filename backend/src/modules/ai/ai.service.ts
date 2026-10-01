import { createHash, timingSafeEqual } from 'crypto';
import { basename } from 'path';
import { prisma } from '../../config/database';
import { storage } from '../../services/storage';
import { AppError, ForbiddenError, InternalError } from '../../utils/errors';
import { env } from '../../config/env';
import { RealtimeService } from '../../services/realtime.service';

const MAX_CANDIDATES = Number(process.env.AI_MAX_CANDIDATES ?? 1000);
const TOP_K = Number(process.env.AI_TOP_K ?? 8);
const MIN_SIMILARITY = Number(process.env.AI_MIN_SIMILARITY ?? 0.18);
const MAX_INDEX_FILE_BYTES = Number(process.env.AI_MAX_INDEX_FILE_BYTES ?? 25_000_000);
const INDEXABLE_EXTENSIONS = new Set(['.pdf', '.docx', '.txt', '.md', '.markdown']);

export interface IndexedChunkInput {
  id: string;
  fileId: string;
  spaceId: string;
  ownerId: string;
  content: string;
  embedding: number[];
  metadata: Record<string, string>;
  pageNumber?: number | null;
  chunkIndex: number;
}

export interface IndexCallbackInput {
  fileId: string;
  status: 'INDEXING' | 'READY' | 'FAILED' | 'OCR_REQUIRED';
  error?: string | null;
  chunks: IndexedChunkInput[];
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

  async searchAccessibleChunks(userId: string, query: string, queryVector: number[], requestedSpaceIds: string[]) {
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

    const chunks = await prisma.fileChunk.findMany({
      where: {
        spaceId: { in: accessibleSpaceIds },
        file: {
          is: {
            spaceId: { in: accessibleSpaceIds },
            deletedAt: null,
            trashedAt: null,
            aiSearchEnabled: true,
            indexStatus: 'READY',
          },
        },
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

    const terms = [...new Set((query.toLocaleLowerCase().match(/[\p{L}\p{N}]{2,}/gu) ?? [])
      .filter((term) => !STOP_WORDS.has(term)))];
    const ranked = chunks.flatMap((chunk) => {
      const vector = parseEmbedding(chunk.embedding);
      if (!vector) return [];
      const semanticScore = cosineSimilarity(queryVector, vector);
      if (semanticScore < -1) return [];
      const text = chunk.content.toLocaleLowerCase();
      const matchedTerms = terms.filter((term) => text.includes(term)).length;
      const keywordScore = terms.length > 0 ? matchedTerms / terms.length : 0;
      const score = Math.max(0, Math.min(1, semanticScore * 0.85 + keywordScore * 0.15));
      return [{
        chunkId: chunk.id,
        documentId: chunk.fileId,
        fileId: chunk.fileId,
        spaceId: chunk.spaceId,
        fileName: chunk.file.originalName || chunk.file.name,
        fileType: chunk.file.extension.toLowerCase(),
        spaceName: chunk.file.space.name,
        updatedAt: chunk.file.updatedAt.toISOString(),
        excerpt: chunk.content,
        pageNumber: chunk.pageNumber,
        chunkIndex: chunk.chunkIndex,
        score,
      }];
    });

    return {
      candidates: ranked.sort((left, right) => right.score - left.score)
        .filter((candidate) => candidate.score >= MIN_SIMILARITY)
        .slice(0, TOP_K),
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

  async completeIndexing(input: IndexCallbackInput) {
    if (input.status === 'READY' && input.chunks.some((chunk) => chunk.fileId !== input.fileId)) {
      throw new Error('Index callback contains chunks for another document');
    }

    await prisma.$transaction(async (transaction) => {
      const file = await transaction.file.findUnique({
        where: { id: input.fileId },
        select: {
          id: true,
          spaceId: true,
          aiSearchEnabled: true,
          deletedAt: true,
          trashedAt: true,
          space: { select: { ownerId: true } },
        },
      });
      if (!file || !file.aiSearchEnabled || file.deletedAt || file.trashedAt) return;

      const chunks = input.status === 'READY'
        ? input.chunks.map((chunk) => ({
          id: chunk.id,
          fileId: file.id,
          spaceId: file.spaceId,
          ownerId: file.space.ownerId,
          content: chunk.content,
          embedding: JSON.stringify(chunk.embedding),
          metadata: JSON.stringify(chunk.metadata),
          pageNumber: chunk.pageNumber ?? null,
          chunkIndex: chunk.chunkIndex,
        }))
        : [];

      if (input.status !== 'INDEXING') {
        await transaction.fileChunk.deleteMany({ where: { fileId: file.id } });
      }
      for (let offset = 0; offset < chunks.length; offset += 50) {
        const batch = chunks.slice(offset, offset + 50);
        if (batch.length > 0) {
          await transaction.fileChunk.createMany({ data: batch });
        }
      }
      await transaction.file.update({
        where: { id: file.id },
        data: {
          indexStatus: input.status,
          indexError: input.status === 'READY' ? null : input.error ?? 'Document indexing failed.',
        },
      });

      RealtimeService.emitToUser(file.space.ownerId, input.status === 'READY' ? 'AI_READY' : 'AI_FAILED', {
        fileId: file.id,
        spaceId: file.spaceId,
        status: input.status,
        chunksIndexed: input.chunks.length,
      });
    });
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