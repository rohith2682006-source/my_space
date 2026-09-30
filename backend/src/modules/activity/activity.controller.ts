import { Response, NextFunction } from 'express';
import { activityService } from './activity.service';
import { AuthenticatedRequest } from '../../middleware/auth';

export class ActivityController {
  async getRecentActivities(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 30;
      const activities = await activityService.getUserActivities(req.user!.userId, limit);
      res.status(200).json({
        success: true,
        data: activities,
      });
    } catch (error) {
      next(error);
    }
  }

  async getSpaceActivities(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const spaceId = req.params.spaceId as string;
      const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 30;
      const activities = await activityService.getSpaceActivities(spaceId, limit);
      res.status(200).json({
        success: true,
        data: activities,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const activityController = new ActivityController();
