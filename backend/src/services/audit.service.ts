import { prisma } from '../config/database';

export interface AuditLogOptions {
  userId?: string | null;
  action: string;
  targetType?: string;
  targetId?: string;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Record<string, unknown>;
}

export class AuditService {
  /**
   * Record an immutable audit log event.
   * Fire-and-forget safe so logging failures never interrupt primary operations.
   */
  static async log(options: AuditLogOptions): Promise<void> {
    try {
      await prisma.auditLog.create({
        data: {
          userId: options.userId ?? null,
          action: options.action,
          targetType: options.targetType ?? null,
          targetId: options.targetId ?? null,
          ipAddress: options.ipAddress ?? null,
          userAgent: options.userAgent ?? null,
          metadata: options.metadata ? JSON.stringify(options.metadata) : '{}',
        },
      });
    } catch (err) {
      console.error('[AuditService] Failed to write audit log:', err);
    }
  }

  /**
   * Query recent audit logs with pagination and filters.
   */
  static async listLogs(params: {
    userId?: string;
    action?: string;
    targetType?: string;
    limit?: number;
    offset?: number;
  }) {
    const { userId, action, targetType, limit = 50, offset = 0 } = params;
    const where: any = {};
    if (userId) where.userId = userId;
    if (action) where.action = action;
    if (targetType) where.targetType = targetType;

    const [logs, total] = await Promise.all([
      prisma.auditLog.findMany({
        where,
        take: limit,
        skip: offset,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.auditLog.count({ where }),
    ]);

    return { logs, total, limit, offset };
  }
}
