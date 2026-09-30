import { prisma } from '../../config/database';
import crypto from 'crypto';

export interface RecordUsageParams {
  userId: string;
  operation: string;
  query?: string;
  model?: string;
  promptTokens?: number;
  completionTokens?: number;
  totalTokens?: number;
  estimatedCostUsd?: number;
  creditsCharged: number;
  durationMs?: number;
  status?: string;
  errorMessage?: string;
  spaceId?: string;
  fileId?: string;
  metadata?: Record<string, any>;
}

export class AiUsageService {
  /**
   * Record an AI query usage entry.
   */
  static async recordUsage(params: RecordUsageParams) {
    try {
      const requestId = crypto.randomUUID();
      return await prisma.aiUsage.create({
        data: {
          userId: params.userId,
          requestId,
          requestType: params.operation,
          model: params.model || 'gpt-4o-mini',
          inputTokens: params.promptTokens || 0,
          cachedInputTokens: 0,
          outputTokens: params.completionTokens || 0,
          estimatedCostUsd: params.estimatedCostUsd || 0,
          latencyMs: params.durationMs || 0,
          success: params.status !== 'FAILED',
          errorCode: params.errorMessage || undefined,
          metadata: JSON.stringify({
            query: params.query ? params.query.slice(0, 300) : undefined,
            spaceId: params.spaceId,
            fileId: params.fileId,
            creditsCharged: params.creditsCharged,
            ...params.metadata,
          }),
        },
      });
    } catch (err) {
      console.error('Failed to log AI usage:', err);
      return null;
    }
  }

  /**
   * Get user usage summary and recent queries.
   */
  static async getUserUsageStats(userId: string) {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalQueries,
      monthlyQueries,
      tokensAgg,
      recentQueries,
      balance,
    ] = await Promise.all([
      prisma.aiUsage.count({
        where: { userId },
      }),
      prisma.aiUsage.count({
        where: {
          userId,
          createdAt: { gte: startOfMonth },
        },
      }),
      prisma.aiUsage.aggregate({
        where: { userId },
        _sum: {
          inputTokens: true,
          outputTokens: true,
          estimatedCostUsd: true,
        },
      }),
      prisma.aiUsage.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      prisma.aiCreditBalance.findUnique({
        where: { userId },
      }),
    ]);

    // Breakdown by request type
    const operationStats = await prisma.aiUsage.groupBy({
      by: ['requestType'],
      where: { userId },
      _count: { _all: true },
    });

    const totalInput = tokensAgg._sum?.inputTokens ?? 0;
    const totalOutput = tokensAgg._sum?.outputTokens ?? 0;

    return {
      balance: balance?.balance ?? 0,
      totalUsedCredits: balance?.totalUsed ?? 0,
      totalQueries,
      monthlyQueries,
      totalTokens: totalInput + totalOutput,
      estimatedCostUsd: tokensAgg._sum?.estimatedCostUsd ?? 0,
      operationsBreakdown: operationStats.map((item) => ({
        operation: item.requestType,
        count: item._count?._all ?? 0,
      })),
      recentQueries,
    };
  }
}
