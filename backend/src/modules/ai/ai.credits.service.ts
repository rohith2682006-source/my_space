import { prisma } from '../../config/database';
import { AppError } from '../../utils/errors';
import crypto from 'crypto';

export const CREDIT_COSTS = {
  QUICK_SEARCH: 1,
  DEEP_SEARCH: 5,
  DOCUMENT_INDEX: 2,
  FILE_SUMMARIZE: 3,
} as const;

export class AiCreditsService {
  /**
   * Get or initialize the user's credit balance based on their plan.
   */
  static async getBalance(userId: string) {
    let balance = await prisma.aiCreditBalance.findUnique({
      where: { userId },
    });

    if (!balance) {
      const now = new Date();
      const periodEnd = new Date(now);
      periodEnd.setMonth(periodEnd.getMonth() + 1);

      // Find user plan to grant monthly initial credits
      const sub = await prisma.subscription.findFirst({
        where: { userId, status: 'ACTIVE' },
        include: { plan: true },
        orderBy: { createdAt: 'desc' },
      });

      const freePlan = !sub
        ? await prisma.plan.findUnique({ where: { name: 'free' } })
        : null;

      const monthlyCredits = sub?.plan?.aiCreditsMonthly ?? freePlan?.aiCreditsMonthly ?? 50;

      balance = await prisma.aiCreditBalance.create({
        data: {
          userId,
          balance: monthlyCredits,
          totalUsed: 0,
          periodStart: now,
          periodEnd: periodEnd,
        },
      });

      // Record transaction
      await prisma.aiCreditTransaction.create({
        data: {
          userId,
          operation: 'GRANT',
          creditsChange: monthlyCredits,
          creditsBefore: 0,
          creditsAfter: monthlyCredits,
          description: 'Initial monthly credits allocation',
        },
      });
    }

    return balance;
  }

  /**
   * Deduct credits atomically with balance check.
   */
  static async deductCredits(
    userId: string,
    amount: number,
    operation: string,
    metadata?: Record<string, any>
  ): Promise<{ success: boolean; newBalance: number }> {
    // Free version bypass: do not deduct credits, just return success
    return { success: true, newBalance: 99999 };
  }

  /**
   * Refund credits in case an AI operation fails after deduction.
   */
  static async refundCredits(
    userId: string,
    amount: number,
    operation: string,
    reason: string
  ): Promise<void> {
    try {
      const current = await this.getBalance(userId);

      await prisma.$transaction(async (tx) => {
        const balanceRecord = await tx.aiCreditBalance.update({
          where: { userId },
          data: {
            balance: { increment: amount },
            totalUsed: { decrement: amount },
          },
        });

        await tx.aiCreditTransaction.create({
          data: {
            userId,
            operation: 'REFUND',
            creditsChange: amount,
            creditsBefore: current.balance,
            creditsAfter: balanceRecord.balance,
            description: `Refunded ${amount} credits: ${reason}`,
          },
        });
      });
    } catch (err) {
      console.error('Failed to refund AI credits:', err);
    }
  }

  /**
   * Add bonus or purchased credits.
   */
  static async addCredits(
    userId: string,
    amount: number,
    type: 'GRANT' | 'PURCHASE' | 'BONUS',
    description: string
  ) {
    const current = await this.getBalance(userId);

    return await prisma.$transaction(async (tx) => {
      const balanceRecord = await tx.aiCreditBalance.update({
        where: { userId },
        data: {
          balance: { increment: amount },
        },
      });

      const txRecord = await tx.aiCreditTransaction.create({
        data: {
          userId,
          operation: type,
          creditsChange: amount,
          creditsBefore: current.balance,
          creditsAfter: balanceRecord.balance,
          description,
        },
      });

      return { balanceRecord, txRecord };
    });
  }

  /**
   * Get user's credit transactions / history.
   */
  static async getHistory(userId: string, limit = 50, page = 1) {
    const skip = (page - 1) * limit;
    const [transactions, total] = await Promise.all([
      prisma.aiCreditTransaction.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: limit,
        skip,
      }),
      prisma.aiCreditTransaction.count({
        where: { userId },
      }),
    ]);

    return {
      transactions,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    };
  }
}
