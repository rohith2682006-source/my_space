import { prisma } from '../../config/database';

export interface LogActivityParams {
  userId: string;
  action: string;
  spaceId?: string | null;
  targetType?: 'file' | 'space' | 'link' | 'member' | string;
  targetId?: string | null;
  metadata?: Record<string, any>;
}

export class ActivityService {
  /**
   * Record a user action asynchronously
   */
  async log(params: LogActivityParams) {
    try {
      await prisma.activity.create({
        data: {
          userId: params.userId,
          action: params.action,
          spaceId: params.spaceId || null,
          targetType: params.targetType || null,
          targetId: params.targetId || null,
          metadata: params.metadata ? JSON.stringify(params.metadata) : null,
        },
      });
    } catch (err) {
      console.error('Failed to log activity:', err);
    }
  }

  /**
   * Get recent activities for a user across all spaces
   */
  async getUserActivities(userId: string, limit: number = 30) {
    const activities = await prisma.activity.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        space: {
          select: {
            id: true,
            name: true,
            icon: true,
            color: true,
          },
        },
      },
    });

    return activities.map((a) => {
      let meta = {};
      try {
        if (a.metadata) meta = JSON.parse(a.metadata);
      } catch {}
      return {
        id: a.id,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        metadata: meta,
        space: a.space,
        createdAt: a.createdAt,
      };
    });
  }

  /**
   * Get activities for a specific space
   */
  async getSpaceActivities(spaceId: string, limit: number = 30) {
    const activities = await prisma.activity.findMany({
      where: { spaceId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        user: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
          },
        },
      },
    });

    return activities.map((a) => {
      let meta = {};
      try {
        if (a.metadata) meta = JSON.parse(a.metadata);
      } catch {}
      return {
        id: a.id,
        action: a.action,
        targetType: a.targetType,
        targetId: a.targetId,
        metadata: meta,
        user: a.user,
        createdAt: a.createdAt,
      };
    });
  }
}

export const activityService = new ActivityService();
