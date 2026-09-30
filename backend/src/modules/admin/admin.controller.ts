import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { ForbiddenError } from '../../utils/errors';
import { AdminService } from './admin.service';
import { prisma } from '../../config/database';

export class AdminController {
  private async ensureAdmin(req: AuthenticatedRequest) {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: { isAdmin: true },
    });
    if (!user?.isAdmin) {
      throw new ForbiddenError('Admin access required');
    }
  }

  async getOverview(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const data = await AdminService.getOverview();
      res.status(200).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async listUsers(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const search = req.query.search as string | undefined;

      const data = await AdminService.listUsers(page, limit, search);
      res.status(200).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async getFinancials(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const data = await AdminService.getFinancialMetrics();
      res.status(200).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async getOperatingCosts(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const data = await AdminService.getOperatingCosts();
      res.status(200).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async createOperatingCost(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const { category, label, amountUsd, notes } = req.body;
      const data = await AdminService.createOperatingCost({ category, label, amountUsd: Number(amountUsd), notes });
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async deleteOperatingCost(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await this.ensureAdmin(req);
      const id = req.params.id as string;
      await AdminService.deleteOperatingCost(id);

      res.status(200).json({ success: true, message: 'Operating cost deleted' });
    } catch (error) {
      next(error);
    }
  }
}

export const adminController = new AdminController();

