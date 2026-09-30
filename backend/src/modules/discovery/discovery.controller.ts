import { Response, NextFunction } from 'express';
import { discoveryService } from './discovery.service';
import { AuthenticatedRequest } from '../../middleware/auth';

export class DiscoveryController {
  async search(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const query = (req.query.q as string) || '';
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;

      const results = await discoveryService.universalSearch(
        req.user!.userId,
        query,
        page,
        limit
      );

      res.status(200).json({
        success: true,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  async getRecent(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const limit = parseInt(req.query.limit as string) || 20;
      const files = await discoveryService.getRecentFiles(req.user!.userId, limit);

      res.status(200).json({
        success: true,
        data: files,
      });
    } catch (error) {
      next(error);
    }
  }

  async getFavorites(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const files = await discoveryService.getFavorites(req.user!.userId);
      res.status(200).json({
        success: true,
        data: files,
      });
    } catch (error) {
      next(error);
    }
  }

  async getTrash(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const files = await discoveryService.getTrash(req.user!.userId);
      res.status(200).json({
        success: true,
        data: files,
      });
    } catch (error) {
      next(error);
    }
  }

  async getStorage(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const stats = await discoveryService.getStorageStats(req.user!.userId);
      res.status(200).json({
        success: true,
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const discoveryController = new DiscoveryController();
