import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { AppError, ForbiddenError, InternalError, NotFoundError, UnauthorizedError } from '../../utils/errors';
import { env } from '../../config/env';
import { ChatInput, DeepSearchInput, FeedbackInput, IndexCallbackInput, QuickSearchInput, VisionInput } from './ai.schema';
import { aiService } from './ai.service';
import { AiCreditsService, CREDIT_COSTS } from './ai.credits.service';
import { AiUsageService } from './ai.usage.service';
import { prisma } from '../../config/database';

async function streamDirectGemini(
  options: {
    systemPrompt?: string;
    message: string;
    history?: Array<{ role: string; content?: string; message?: string }>;
    citations?: any[];
  },
  res: Response
): Promise<boolean> {
  const geminiApiKey = env.GEMINI_API_KEY || process.env.GEMINI_API_KEY || '';
  if (!geminiApiKey) return false;

  const candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];
  const contents: any[] = [];

  if (options.history && Array.isArray(options.history)) {
    for (const h of options.history) {
      const text = h.content || (h as any).message || '';
      if (!text) continue;
      const role = h.role === 'assistant' || h.role === 'model' ? 'model' : 'user';
      contents.push({
        role,
        parts: [{ text }],
      });
    }
  }

  contents.push({
    role: 'user',
    parts: [{ text: options.message }],
  });

  const requestBody: any = { contents };
  if (options.systemPrompt) {
    requestBody.systemInstruction = {
      parts: [{ text: options.systemPrompt }],
    };
  }

  for (const model of candidateModels) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${geminiApiKey}`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
        signal: AbortSignal.timeout(10_000),
      });

      if (!response.ok || !response.body) {
        console.warn(`[DIRECT GEMINI] Model ${model} returned ${response.status}. Trying next candidate...`);
        continue;
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed.startsWith('data:')) {
            const jsonStr = trimmed.slice(5).trim();
            if (!jsonStr) continue;
            try {
              const data = JSON.parse(jsonStr);
              const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                res.write(`data: ${JSON.stringify({ text })}\n\n`);
              }
            } catch (_) {}
          }
        }
      }

      res.write(`data: ${JSON.stringify({ done: true, citations: options.citations || [] })}\n\n`);
      res.end();
      return true;
    } catch (err: any) {
      console.warn(`[DIRECT GEMINI] Error with ${model}:`, err.message);
    }
  }

  return false;
}

export class AiController {
  async vision(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    const started = performance.now();
    let creditsDeducted = false;

    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }

      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', {
        endpoint: '/vision',
      });
      creditsDeducted = true;

      const body = req.body as VisionInput;
      const response = await fetch(`${env.AI_SERVICE_URL}/vision/analyze`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt: body.prompt || 'Analyze this image in detail and describe what you see, including key objects, scene details, and any visible text.',
          imageBase64: body.imageBase64,
          imageMimeType: body.imageMimeType || 'image/jpeg',
          history: body.history || [],
        }),
        signal: AbortSignal.timeout(45_000),
      });

      if (!response.ok) {
        if (creditsDeducted) {
          await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', 'Upstream AI error');
        }
        const errorBody = await response.json().catch(() => ({}));
        const detail = (errorBody as { detail?: string }).detail;
        if (response.status === 401) {
          throw new AppError(detail || 'AI authentication failed. Invalid API credentials.', 401, 'AI_AUTH_ERROR');
        }
        if (response.status === 402) {
          throw new AppError(detail || 'Gemini quota or credit balance exhausted.', 402, 'AI_QUOTA_EXHAUSTED');
        }
        if (response.status === 429) {
          throw new AppError(detail || 'AI service rate limit reached. Please try again shortly.', 429, 'AI_RATE_LIMITED');
        }
        if (response.status === 502) {
          throw new AppError(detail || 'Upstream Vision AI error. Please try again.', 502, 'AI_PROVIDER_ERROR');
        }
        if (response.status >= 500) {
          throw new AppError('AI service is temporarily unavailable', 503, 'AI_UNAVAILABLE');
        }
        throw new InternalError(detail || 'Vision AI request could not be completed', 'AI_REQUEST_FAILED');
      }

      const data = (await response.json()) as { reply?: unknown };
      if (typeof data.reply !== 'string') {
        throw new InternalError('AI service returned an invalid response', 'AI_INVALID_RESPONSE');
      }

      const durationMs = Math.round(performance.now() - started);
      const balance = await AiCreditsService.getBalance(userId);

      AiUsageService.recordUsage({
        userId,
        operation: 'CHAT',
        query: body.prompt || 'Vision analysis',
        creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
        durationMs,
        status: 'SUCCESS',
      });

      res.status(200).json({
        success: true,
        data: {
          reply: data.reply,
          creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
          remainingCredits: balance.balance,
        },
      });
    } catch (error: any) {
      if (creditsDeducted && !(error instanceof AppError && error.statusCode === 402)) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', error.message || 'Request failure');
      }

      if (error instanceof AppError) {
        next(error);
      } else if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
        next(new AppError('Vision AI request timed out', 504, 'AI_TIMEOUT'));
      } else if (error?.cause?.code === 'ECONNREFUSED' || error?.message?.includes('fetch failed')) {
        next(new AppError(`Python AI service is offline or unreachable at ${env.AI_SERVICE_URL}`, 503, 'AI_UNAVAILABLE'));
      } else {
        next(new AppError('Vision AI is temporarily unavailable', 503, 'AI_UNAVAILABLE'));
      }
    }
  }
  async chat(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    const started = performance.now();
    let creditsDeducted = false;

    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }

      // 1. Deduct credits
      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', {
        endpoint: '/chat',
      });
      creditsDeducted = true;

      const response = await fetch(`${env.AI_SERVICE_URL}/chat`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(req.body as ChatInput),
        signal: AbortSignal.timeout(30_000),
      });

      if (!response.ok) {
        // Refund credits on upstream failure
        if (creditsDeducted) {
          await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', 'Upstream AI error');
        }
        const errorBody = await response.json().catch(() => ({}));
        const detail = (errorBody as { detail?: string }).detail;
        if (response.status === 401) {
          throw new AppError(detail || 'AI authentication failed. Invalid API credentials.', 401, 'AI_AUTH_ERROR');
        }
        if (response.status === 402) {
          throw new AppError(detail || 'Gemini quota or credit balance exhausted.', 402, 'AI_QUOTA_EXHAUSTED');
        }
        if (response.status === 429) {
          throw new AppError(detail || 'AI service rate limit reached. Please try again shortly.', 429, 'AI_RATE_LIMITED');
        }
        if (response.status === 502) {
          throw new AppError(detail || 'Upstream AI provider error. Please try again.', 502, 'AI_PROVIDER_ERROR');
        }
        if (response.status >= 500) {
          throw new AppError('AI service is temporarily unavailable', 503, 'AI_UNAVAILABLE');
        }
        throw new InternalError(detail || 'AI request could not be completed', 'AI_REQUEST_FAILED');
      }

      const data = (await response.json()) as { reply?: unknown };
      if (typeof data.reply !== 'string') {
        throw new InternalError('AI service returned an invalid response', 'AI_INVALID_RESPONSE');
      }

      const durationMs = Math.round(performance.now() - started);
      const balance = await AiCreditsService.getBalance(userId);

      // Record usage asynchronously
      AiUsageService.recordUsage({
        userId,
        operation: 'CHAT',
        query: (req.body as ChatInput).message,
        creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
        durationMs,
        status: 'SUCCESS',
      });

      res.status(200).json({
        success: true,
        data: {
          reply: data.reply,
          creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
          remainingCredits: balance.balance,
        },
      });
    } catch (error: any) {
      if (creditsDeducted && !(error instanceof AppError && error.statusCode === 402)) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', error.message || 'Request failure');
      }

      if (error instanceof AppError) {
        next(error);
      } else if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
        next(new AppError('AI service request timed out', 504, 'AI_TIMEOUT'));
      } else if (error?.cause?.code === 'ECONNREFUSED' || error?.message?.includes('fetch failed')) {
        next(new AppError(`Python AI service is offline or unreachable at ${env.AI_SERVICE_URL}`, 503, 'AI_UNAVAILABLE'));
      } else {
        next(new AppError('AI service is temporarily unavailable', 503, 'AI_UNAVAILABLE'));
      }
    }
  }

  async deepSearch(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    const started = performance.now();
    let creditsDeducted = false;

    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }

      const input = req.body as DeepSearchInput;
      const targetSpace = input.spaceIds[0] || 'all';
      const cacheKey = aiService.makeCacheKey(targetSpace, input.fileId, input.message);
      const cached = aiService.getQueryCache(cacheKey);

      if (cached) {
        res.status(200).json({
          success: true,
          data: {
            ...cached,
            cached: true,
          },
        });
        return;
      }

      // 1. Deduct credits for deep search
      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', {
        endpoint: '/deep-search',
      });
      creditsDeducted = true;

      // 2. Query rewrite for standalone context
      const standaloneQuery = await aiService.rewriteQuery(input.message, input.history);

      // 3. Request embedding
      const queryVector = await aiService.requestEmbedding(standaloneQuery);

      // 4. Hybrid search with RRF & distance cutoff
      const { candidates } = await aiService.searchAccessibleChunks(
        userId,
        standaloneQuery,
        queryVector,
        input.spaceIds,
        input.fileId,
      );

      if (candidates.length === 0) {
        await aiService.logSearch(standaloneQuery, userId, [], performance.now() - started);
        const balance = await AiCreditsService.getBalance(userId);

        const fallbackText = "I couldn't find that in your files. Try rephrasing or make sure the relevant file is uploaded to this space.";
        const fallbackData = {
          reply: fallbackText,
          answer: fallbackText,
          sources: [],
          searchMetadata: { chunksRetrieved: 0, chunksUsed: 0 },
          creditsCharged: CREDIT_COSTS.DEEP_SEARCH,
          remainingCredits: balance.balance,
        };

        aiService.setQueryCache(cacheKey, fallbackData);

        res.status(200).json({
          success: true,
          data: fallbackData,
        });
        return;
      }

      const response = await fetch(`${env.AI_SERVICE_URL}/rag/answer`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: standaloneQuery,
          history: input.history,
          sources: candidates,
        }),
        signal: AbortSignal.timeout(30_000),
      });

      if (!response.ok) {
        if (creditsDeducted) {
          await AiCreditsService.refundCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', 'Upstream AI error');
        }
        const errorBody = await response.json().catch(() => ({}));
        const detail = (errorBody as { detail?: string }).detail;
        if (response.status === 401) {
          throw new AppError(detail || 'AI authentication failed. Invalid API credentials.', 401, 'AI_AUTH_ERROR');
        }
        if (response.status === 402) {
          throw new AppError(detail || 'Gemini quota or credit balance exhausted.', 402, 'AI_QUOTA_EXHAUSTED');
        }
        if (response.status === 429) {
          throw new AppError(detail || 'AI service rate limit reached. Please try again shortly.', 429, 'AI_RATE_LIMITED');
        }
        if (response.status === 502) {
          throw new AppError(detail || 'Upstream AI provider error. Please try again.', 502, 'AI_PROVIDER_ERROR');
        }
        if (response.status >= 500) {
          throw new AppError('AI service is temporarily unavailable', 503, 'AI_UNAVAILABLE');
        }
        throw new InternalError(detail || 'AI request could not be completed', 'AI_REQUEST_FAILED');
      }

      const data = (await response.json()) as {
        answer?: unknown;
        citations?: Array<{
          id: number;
          document_id: string;
          file_id: string;
          space_id: string;
          file_name: string;
          file_type: string;
          space_name: string;
          updated_at: string;
          page_number: number | null;
          chunk_id: string;
          excerpt: string;
        }>;
        search_metadata?: Record<string, number>;
      };
      if (typeof data.answer !== 'string' || !Array.isArray(data.citations)) {
        throw new InternalError('AI service returned an invalid response', 'AI_INVALID_RESPONSE');
      }

      const durationMs = Math.round(performance.now() - started);
      await aiService.logSearch(
        standaloneQuery,
        userId,
        candidates,
        durationMs,
      );

      const balance = await AiCreditsService.getBalance(userId);

      // Record AI usage entry
      AiUsageService.recordUsage({
        userId,
        operation: 'DEEP_SEARCH',
        query: input.message,
        creditsCharged: CREDIT_COSTS.DEEP_SEARCH,
        durationMs,
        status: 'SUCCESS',
      });

      // Record to RAG usage log
      prisma.aiUsageLog.create({
        data: {
          userId,
          spaceId: input.spaceIds[0] || null,
          stage: 'answer',
          inputTokens: (data.search_metadata?.context_tokens as number) || 0,
          outputTokens: Math.round(data.answer.length / 4),
          latencyMs: durationMs,
        },
      }).catch(() => {});

      const responsePayload = {
        reply: data.answer,
        answer: data.answer,
        sources: data.citations.map((citation) => ({
          id: citation.file_id,
          name: citation.file_name,
          spaceId: citation.space_id,
          spaceName: citation.space_name,
          updatedAt: citation.updated_at,
          citationNumber: citation.id,
          pageNumber: citation.page_number,
          fileType: citation.file_type,
          chunkId: citation.chunk_id,
          excerpt: citation.excerpt,
        })),
        searchMetadata: data.search_metadata ?? {},
        creditsCharged: CREDIT_COSTS.DEEP_SEARCH,
        remainingCredits: balance.balance,
      };

      aiService.setQueryCache(cacheKey, responsePayload);

      res.status(200).json({
        success: true,
        data: responsePayload,
      });
    } catch (error: any) {
      if (creditsDeducted && !(error instanceof AppError && error.statusCode === 402)) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', error.message || 'Request failure');
      }
      next(error);
    }
  }

  async deepSearchStream(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    let creditsDeducted = false;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();

    try {
      if (!env.AI_SERVICE_TOKEN) {
        res.write(`data: ${JSON.stringify({ error: 'AI service is not configured', done: true })}\n\n`);
        res.end();
        return;
      }

      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', {
        endpoint: '/deep-search/stream',
      });
      creditsDeducted = true;

      const input = req.body as DeepSearchInput;
      const fileIds: string[] = Array.isArray(input.fileIds) ? [...input.fileIds] : [];
      if (input.fileId && !fileIds.includes(input.fileId)) {
        fileIds.push(input.fileId);
      }

      const hasSpace = Array.isArray(input.spaceIds) && input.spaceIds.length > 0;
      const hasFiles = fileIds.length > 0;

      // Privacy protection: Do not search through all user files unless explicitly granted
      if (!hasSpace && !hasFiles) {
        if (creditsDeducted) {
          await AiCreditsService.refundCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', 'No files or spaces attached').catch(() => {});
        }
        const privacyNotice = "I don't have access to any files or folders right now. To protect your privacy, I will not search through your files or reveal workspace details unless you grant folder access or attach specific files using the '+' button.";
        res.write(`data: ${JSON.stringify({ text: privacyNotice })}\n\n`);
        res.write(`data: ${JSON.stringify({ done: true, citations: [], search_metadata: { chunksRetrieved: 0, chunksUsed: 0 } })}\n\n`);
        res.end();
        return;
      }

      const targetSpace = input.spaceIds[0] || 'all';
      const cacheKey = aiService.makeCacheKey(targetSpace, fileIds[0] || input.fileId, input.message);
      const cached = aiService.getQueryCache(cacheKey);

      if (cached) {
        res.write(`data: ${JSON.stringify({ text: cached.answer, cached: true })}\n\n`);
        res.write(`data: ${JSON.stringify({ done: true, citations: cached.sources, search_metadata: cached.searchMetadata })}\n\n`);
        res.end();
        return;
      }

      // 1. Build folder manifest if space is provided
      let folderManifest: any = null;
      if (input.spaceIds && input.spaceIds.length > 0) {
        try {
          folderManifest = await aiService.buildFolderManifest(
            userId,
            input.spaceIds[0],
            fileIds.length > 0 ? fileIds : undefined,
          );
        } catch (manifestErr: any) {
          if (manifestErr instanceof ForbiddenError || manifestErr?.statusCode === 403) {
            res.write(`data: ${JSON.stringify({ error: 'You do not have permission to access this space', done: true })}\n\n`);
            res.end();
            return;
          }
          if (manifestErr instanceof NotFoundError || manifestErr?.statusCode === 404) {
            res.write(`data: ${JSON.stringify({ error: 'Space not found', done: true })}\n\n`);
            res.end();
            return;
          }
        }
      }

      // 2. Query rewrite and vector chunk search
      const standaloneQuery = await aiService.rewriteQuery(input.message, input.history);
      const queryVector = await aiService.requestEmbedding(standaloneQuery);
      const { candidates } = await aiService.searchAccessibleChunks(
        userId,
        standaloneQuery,
        queryVector,
        input.spaceIds,
        input.fileId,
        fileIds,
      );

      // 3. Call Python AI service /rag/answer/stream with resilient direct Gemini fallback
      let streamedOk = false;
      try {
        const aiResponse = await fetch(`${env.AI_SERVICE_URL}/rag/answer/stream`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: standaloneQuery || input.message,
            history: input.history,
            folder_manifest: folderManifest,
            sources: candidates,
          }),
          signal: AbortSignal.timeout(5_000),
        });

        if (aiResponse.ok && aiResponse.body) {
          const reader = aiResponse.body.getReader();
          const decoder = new TextDecoder();

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const text = decoder.decode(value, { stream: true });
            res.write(text);
          }
          res.end();
          streamedOk = true;
          return;
        }
      } catch (upstreamErr: any) {
        console.warn(`[AI RAG STREAM] Python AI service unreachable or error (${upstreamErr.message}). Activating direct Gemini fallback stream...`);
      }

      if (!streamedOk) {
        const excerpts = (candidates || [])
          .map((c: any, i: number) => `[Source ${i + 1}] (${c.fileName || 'Doc'}): ${c.content || c.excerpt || ''}`)
          .join('\n\n');
        const questionWithContext = excerpts
          ? `File excerpts:\n${excerpts}\n\nUser Question: ${standaloneQuery || input.message}`
          : (standaloneQuery || input.message);

        const directSuccess = await streamDirectGemini(
          {
            message: questionWithContext,
            history: input.history,
            citations: candidates,
            systemPrompt: 'You are Spaces AI. Answer questions based on the provided file excerpts. Cite sources using [Source 1], [Source 2], etc. If not in the excerpts, answer helpfully while noting context limitations.',
          },
          res
        );

        if (directSuccess) {
          return;
        }
        throw new Error('AI stream temporarily unavailable');
      }
    } catch (err: any) {
      if (creditsDeducted) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', err.message || 'Stream error').catch(() => {});
      }
      res.write(`data: ${JSON.stringify({ error: err.message || 'Streaming failed', done: true })}\n\n`);
      res.end();
    }
  }

  async chatStream(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    let creditsDeducted = false;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();

    try {
      AiCreditsService.deductCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', {
        endpoint: '/chat/stream',
      }).catch((e) => console.warn('[CREDITS] Non-blocking deduct error:', e));
      creditsDeducted = true;

      // Check if folder or files are attached for RAG context
      const spaceIds: string[] = Array.isArray(req.body.spaceIds) ? req.body.spaceIds : [];
      const fileIds: string[] = Array.isArray(req.body.fileIds)
        ? req.body.fileIds
        : (req.body.fileId ? [req.body.fileId] : []);

      let attachedContext = '';
      let citationsList: any[] = [];

      if (spaceIds.length > 0 || fileIds.length > 0) {
        try {
          const [spaces, files] = await Promise.all([
            spaceIds.length > 0
              ? prisma.space.findMany({
                  where: { id: { in: spaceIds }, ownerId: userId },
                  select: { id: true, name: true, description: true },
                })
              : Promise.resolve([]),
            prisma.file.findMany({
              where: {
                deletedAt: null,
                uploadedBy: userId,
                OR: [
                  ...(spaceIds.length > 0 ? [{ spaceId: { in: spaceIds } }] : []),
                  ...(fileIds.length > 0 ? [{ id: { in: fileIds } }] : []),
                ],
              },
              select: {
                id: true,
                name: true,
                mimeType: true,
                size: true,
                spaceId: true,
                fileChunks: {
                  take: 8,
                  select: { content: true, chunkIndex: true },
                  orderBy: { chunkIndex: 'asc' },
                },
              },
              take: 20,
            }),
          ]);

          if (spaces.length > 0 || files.length > 0) {
            attachedContext += `[Attached Knowledge Base / Workspace Files]\n`;
            if (spaces.length > 0) {
              attachedContext += `Selected Folder(s): ${spaces.map((s) => `"${s.name}"`).join(', ')}\n`;
            }
            if (files.length > 0) {
              attachedContext += `Files inside (${files.length} files total):\n`;
              citationsList = files.map((f, idx) => ({
                id: f.id,
                name: f.name,
                fileName: f.name,
                spaceId: f.spaceId,
                citationNumber: idx + 1,
                fileType: f.mimeType || 'unknown',
              }));

              for (const f of files) {
                attachedContext += `• ${f.name} (type: ${f.mimeType || 'unknown'}, size: ${f.size} bytes)\n`;
                if (f.fileChunks && f.fileChunks.length > 0) {
                  const excerpt = f.fileChunks.map((c: any) => c.content).join(' ').slice(0, 1000);
                  if (excerpt.trim()) {
                    attachedContext += `  Content Summary / Excerpt: ${excerpt}...\n`;
                  }
                }
              }
            }
            attachedContext += `\nInstructions: The user is asking about the above folder and files. Answer their questions accurately based on the files and contents listed above. Cite file names when referencing them.`;
          }
        } catch (dbErr) {
          console.warn('[AI CHAT] Failed to load attached folder context:', dbErr);
        }
      }

      // If attached context is present, stream directly with real-time prediction speed
      if (attachedContext) {
        const directSuccess = await streamDirectGemini(
          {
            message: `${attachedContext}\n\nUser Question: ${req.body.message}`,
            history: req.body.history,
            citations: citationsList,
            systemPrompt: 'You are Spaces AI, an intelligent, helpful assistant. You have full access to the attached folder and files provided in the context. Answer questions about this folder and its files warmly, accurately, and thoroughly.',
          },
          res
        );

        if (directSuccess) {
          return;
        }
      }

      let streamedOk = false;
      try {
        const aiResponse = await fetch(`${env.AI_SERVICE_URL}/chat/stream`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(req.body),
          signal: AbortSignal.timeout(3_000),
        });

        if (aiResponse.ok && aiResponse.body) {
          const reader = aiResponse.body.getReader();
          const decoder = new TextDecoder();

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            const text = decoder.decode(value, { stream: true });
            res.write(text);
          }
          res.end();
          streamedOk = true;
          return;
        }
      } catch (upstreamErr: any) {
        console.warn(`[AI STREAM] Python AI service unreachable or error (${upstreamErr.message}). Activating direct Gemini fallback stream...`);
      }

      if (!streamedOk) {
        const directSuccess = await streamDirectGemini(
          {
            message: attachedContext
              ? `${attachedContext}\n\nUser Question: ${req.body.message}`
              : req.body.message,
            history: req.body.history,
            citations: citationsList,
            systemPrompt: attachedContext
              ? 'You are Spaces AI. Answer questions about the user\'s attached folder and files accurately and thoroughly.'
              : 'You are Spaces AI, an intelligent, empathetic, and thoughtful conversational assistant. Provide natural, thorough, and clear answers.',
          },
          res
        );

        if (directSuccess) {
          return;
        }
        throw new Error('AI stream temporarily unavailable');
      }
    } catch (err: any) {
      if (creditsDeducted) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'CHAT', err.message || 'Stream error').catch(() => {});
      }
      res.write(`data: ${JSON.stringify({ error: err.message || 'Streaming failed', done: true })}\n\n`);
      res.end();
    }
  }

  /**
   * Fast semantic quick search: retrieves top snippets directly with lightweight indexing, costing only 1 credit.
   */
  async quickSearch(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const userId = req.user!.userId;
    const started = performance.now();
    let creditsDeducted = false;

    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }

      const input = req.body as QuickSearchInput;
      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'QUICK_SEARCH', {
        query: input.query,
      });
      creditsDeducted = true;

      const queryVector = await aiService.requestEmbedding(input.query);
      const { candidates } = await aiService.searchAccessibleChunks(
        userId,
        input.query,
        queryVector,
        input.spaceIds,
      );

      const durationMs = Math.round(performance.now() - started);
      const balance = await AiCreditsService.getBalance(userId);

      AiUsageService.recordUsage({
        userId,
        operation: 'QUICK_SEARCH',
        query: input.query,
        creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
        durationMs,
        status: 'SUCCESS',
      });

      res.status(200).json({
        success: true,
        data: {
          query: input.query,
          results: candidates.slice(0, 10).map((c, idx) => ({
            id: c.chunkId,
            fileId: c.fileId,
            fileName: c.fileName,
            fileType: c.fileType,
            spaceId: c.spaceId,
            spaceName: c.spaceName,
            score: c.score,
            pageNumber: c.pageNumber,
            content: c.excerpt,
            rank: idx + 1,
          })),
          count: Math.min(candidates.length, 10),
          durationMs,
          creditsCharged: CREDIT_COSTS.QUICK_SEARCH,
          remainingCredits: balance.balance,
        },
      });
    } catch (error: any) {
      if (creditsDeducted && !(error instanceof AppError && error.statusCode === 402)) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.QUICK_SEARCH, 'QUICK_SEARCH', error.message || 'Request failure');
      }
      next(error);
    }
  }

  async getCreditsBalance(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const balance = await AiCreditsService.getBalance(req.user!.userId);
      res.status(200).json({
        success: true,
        data: balance,
      });
    } catch (error) {
      next(error);
    }
  }

  async getCreditsHistory(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const history = await AiCreditsService.getHistory(req.user!.userId, limit, page);
      res.status(200).json({
        success: true,
        data: history,
      });
    } catch (error) {
      next(error);
    }
  }

  async getUsageStats(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const stats = await AiUsageService.getUserUsageStats(req.user!.userId);
      res.status(200).json({
        success: true,
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }

  async getIndexStatus(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await aiService.getIndexStatus(req.params.id as string, req.user!.userId);
      if (!result) throw new NotFoundError('Document not found');
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async reindexDocument(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }
      const result = await aiService.reindexFile(req.params.id as string, req.user!.userId);
      if (!result) throw new NotFoundError('Document not found');
      if (result.status === 'UNSUPPORTED') {
        throw new AppError('This file type cannot be indexed', 415, 'UNSUPPORTED_DOCUMENT_TYPE');
      }
      res.status(202).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async reindexExistingDocuments(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }
      const result = await aiService.reindexExistingDocuments(
        req.user!.userId,
        (req.body as { excludeFileIds: string[] }).excludeFileIds,
      );
      res.status(202).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async reindexSpace(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!env.AI_SERVICE_TOKEN) {
        throw new AppError('AI service is not configured', 503, 'AI_UNAVAILABLE');
      }
      const result = await aiService.reindexSpace(req.params.spaceId as string, req.user!.userId);
      res.status(202).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }


  async submitFeedback(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { spaceId, question, answer, rating, chunkIds } = req.body as FeedbackInput;

      const record = await prisma.answerFeedback.create({
        data: {
          userId,
          spaceId,
          question,
          answer,
          rating,
          chunkIds: JSON.stringify(chunkIds || []),
        },
      });

      res.status(201).json({ success: true, data: { id: record.id } });
    } catch (error) {
      next(error);
    }
  }

  hasValidServiceToken(authorization: string | undefined): boolean {
    return aiService.isServiceTokenValid(authorization);
  }


  async indexComplete(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!aiService.isServiceTokenValid(req.headers.authorization)) {
        throw new UnauthorizedError('Invalid AI service token');
      }
      await aiService.completeIndexing(req.body as IndexCallbackInput);
      res.status(200).json({ success: true });
    } catch (error) {
      next(error);
    }
  }
}

export const aiController = new AiController();