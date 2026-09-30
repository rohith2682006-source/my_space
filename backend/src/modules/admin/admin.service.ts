import { prisma } from '../../config/database';

export class AdminService {
  /**
   * Aggregate high-level platform and AI business metrics.
   */
  static async getOverview() {
    const [
      totalUsers,
      totalSpaces,
      totalFiles,
      totalAiQueries,
      activeSubscriptions,
      creditAggregates,
      tokenAggregates,
      recentAiUsage,
      storageStats,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.space.count(),
      prisma.file.count(),
      prisma.aiUsage.count(),
      prisma.subscription.count({ where: { status: 'ACTIVE' } }),
      prisma.aiCreditTransaction.aggregate({
        where: { creditsChange: { lt: 0 } },
        _sum: { creditsChange: true },
      }),
      prisma.aiUsage.aggregate({
        _sum: {
          inputTokens: true,
          outputTokens: true,
          estimatedCostUsd: true,
        },
      }),
      prisma.aiUsage.findMany({
        take: 15,
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: {
              email: true,
              firstName: true,
              lastName: true,
            },
          },
        },
      }),
      prisma.storageUsage.aggregate({
        _sum: { totalUsed: true },
      }),
    ]);

    // Breakdown by request type
    const operationBreakdown = await prisma.aiUsage.groupBy({
      by: ['requestType'],
      _count: { _all: true },
    });

    // Plan distribution
    const plansDistribution = await prisma.subscription.groupBy({
      by: ['planId'],
      _count: { _all: true },
    });

    const allPlans = await prisma.plan.findMany();
    const planCounts = allPlans.map((p) => {
      const match = plansDistribution.find((d) => d.planId === p.id);
      return {
        name: p.displayName,
        count: match?._count._all ?? 0,
      };
    });

    const totalInput = tokenAggregates._sum?.inputTokens ?? 0;
    const totalOutput = tokenAggregates._sum?.outputTokens ?? 0;

    return {
      totalUsers,
      totalSpaces,
      totalFiles,
      totalAiQueries,
      activeSubscriptions,
      totalCreditsConsumed: Math.abs(creditAggregates._sum?.creditsChange ?? 0),
      totalTokens: totalInput + totalOutput,
      estimatedAiCostUsd: tokenAggregates._sum?.estimatedCostUsd ?? 0,
      totalStorageBytes: Number(storageStats._sum?.totalUsed ?? 0),
      operationBreakdown: operationBreakdown.map((item) => ({
        operation: item.requestType,
        count: item._count._all,
      })),
      planDistribution: planCounts,
      recentAiUsage,
    };
  }

  /**
   * List users with their subscription and credits.
   */
  static async listUsers(page = 1, limit = 20, search?: string) {
    const skip = (page - 1) * limit;
    const where = search
      ? {
          OR: [
            { email: { contains: search } },
            { firstName: { contains: search } },
            { lastName: { contains: search } },
          ],
        }
      : {};

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          email: true,
          firstName: true,
          lastName: true,
          isAdmin: true,
          createdAt: true,
          subscriptions: {
            where: { status: 'ACTIVE' },
            include: { plan: true },
            take: 1,
            orderBy: { createdAt: 'desc' },
          },
          aiCreditBalance: true,
          _count: {
            select: {
              files: true,
              spaces: true,
              aiUsage: true,
            },
          },
        },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users: users.map((u) => ({
        ...u,
        subscription: u.subscriptions[0] || null,
      })),
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get financial analytics: MRR, ARR, ARPU, revenue, operational costs, net profit & unit economics.
   */
  static async getFinancialMetrics() {
    const USD_TO_INR = 85.0;

    const [
      activeSubs,
      payments,
      aiUsageAgg,
      operatingCosts,
      plans,
    ] = await Promise.all([
      prisma.subscription.findMany({
        where: { status: 'ACTIVE' },
        include: { plan: true },
      }),
      prisma.payment.aggregate({
        where: { status: 'CAPTURED' },
        _sum: { amountPaise: true },
        _count: { _all: true },
      }),
      prisma.aiUsage.aggregate({
        _sum: {
          inputTokens: true,
          outputTokens: true,
          estimatedCostUsd: true,
        },
      }),
      prisma.operatingCost.findMany({
        where: { isActive: true },
        orderBy: { category: 'asc' },
      }),
      prisma.plan.findMany(),
    ]);

    // Calculate MRR in INR and USD
    let mrrInr = 0;
    for (const sub of activeSubs) {
      if (sub.billingPeriod === 'YEARLY' && sub.plan.priceYearly) {
        mrrInr += sub.plan.priceYearly / 12;
      } else if (sub.plan.priceMonthly) {
        mrrInr += sub.plan.priceMonthly;
      }
    }
    const mrrUsd = mrrInr / USD_TO_INR;
    const arrUsd = mrrUsd * 12;
    const arpuUsd = activeSubs.length > 0 ? mrrUsd / activeSubs.length : 0;

    // Gross Revenue from captured payments
    const grossRevenueInr = (payments._sum.amountPaise ?? 0) / 100;
    const grossRevenueUsd = grossRevenueInr / USD_TO_INR;

    // AI upstream cost
    const totalAiCostUsd = aiUsageAgg._sum.estimatedCostUsd ?? 0;

    // Monthly Operating Costs (hosting, db, storage, etc.)
    const totalOperatingCostMonthlyUsd = operatingCosts.reduce((acc, c) => acc + c.amountUsd, 0);

    // Net Profit estimated
    const estimatedMonthlyNetProfitUsd = mrrUsd - totalAiCostUsd - totalOperatingCostMonthlyUsd;
    const grossMarginPercent = mrrUsd > 0 ? Math.round(((mrrUsd - totalAiCostUsd) / mrrUsd) * 100) : 0;

    // Unit Economics per plan tier
    const unitEconomics = plans.map((p) => {
      const subsOnPlan = activeSubs.filter((s) => s.planId === p.id);
      const subCount = subsOnPlan.length;
      const monthlyRevenueUsd = (subCount * (p.priceMonthly ?? 0)) / USD_TO_INR;
      return {
        planId: p.id,
        planName: p.displayName,
        subscribers: subCount,
        monthlyRevenueUsd,
        aiCreditsAllowance: p.aiCreditsMonthly,
      };
    });

    return {
      mrrUsd,
      arrUsd,
      arpuUsd,
      grossRevenueInr,
      grossRevenueUsd,
      totalPaymentsCount: payments._count._all,
      totalAiCostUsd,
      totalOperatingCostMonthlyUsd,
      estimatedMonthlyNetProfitUsd,
      grossMarginPercent,
      operatingCosts,
      unitEconomics,
    };
  }

  static async getOperatingCosts() {
    return prisma.operatingCost.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  static async createOperatingCost(data: {
    category: string;
    label: string;
    amountUsd: number;
    notes?: string;
  }) {
    return prisma.operatingCost.create({
      data: {
        category: data.category,
        label: data.label,
        amountUsd: data.amountUsd,
        notes: data.notes,
        effectiveFrom: new Date(),
        isActive: true,
      },
    });
  }

  static async deleteOperatingCost(id: string) {
    return prisma.operatingCost.delete({
      where: { id },
    });
  }
}

