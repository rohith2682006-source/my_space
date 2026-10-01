import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { AppError, InternalError, NotFoundError, UnauthorizedError } from '../../utils/errors';
import { env } from '../../config/env';
import { ChatInput, DeepSearchInput, IndexCallbackInput, QuickSearchInput } from './ai.schema';
import { aiService } from './ai.service';
import { AiCreditsService, CREDIT_COSTS } from './ai.credits.service';
import { AiUsageService } from './ai.usage.service';

export class AiController {
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

      // 1. Deduct credits for deep search
      await AiCreditsService.deductCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', {
        endpoint: '/deep-search',
      });
      creditsDeducted = true;

      const input = req.body as DeepSearchInput;
      const queryVector = await aiService.requestEmbedding(input.message);
      const { candidates } = await aiService.searchAccessibleChunks(
        userId,
        input.message,
        queryVector,
        input.spaceIds,
      );
      if (candidates.length === 0) {
        await aiService.logSearch(input.message, userId, [], performance.now() - started);
        const balance = await AiCreditsService.getBalance(userId);
        res.status(200).json({
          success: true,
          data: {
            reply: "I couldn't find enough relevant information in your accessible documents to answer this question.",
            answer: "I couldn't find enough relevant information in your accessible documents to answer this question.",
            sources: [],
            searchMetadata: { chunksRetrieved: 0, chunksUsed: 0 },
            creditsCharged: CREDIT_COSTS.DEEP_SEARCH,
            remainingCredits: balance.balance,
          },
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
          message: input.message,
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
        input.message,
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

      res.status(200).json({
        success: true,
        data: {
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
        },
      });
    } catch (error: any) {
      if (creditsDeducted && !(error instanceof AppError && error.statusCode === 402)) {
        await AiCreditsService.refundCredits(userId, CREDIT_COSTS.DEEP_SEARCH, 'DEEP_SEARCH', error.message || 'Request failure');
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