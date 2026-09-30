import { Response, NextFunction } from 'express';
import { spacesService } from './spaces.service';
import { AuthenticatedRequest } from '../../middleware/auth';

export class SpacesController {
  async createSpace(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const space = await spacesService.createSpace(req.user!.userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Space created successfully',
        data: space,
      });
    } catch (error) {
      next(error);
    }
  }

  async listSpaces(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await spacesService.listSpaces(req.user!.userId, req.query as any);
      res.status(200).json({
        success: true,
        ...result,
      });
    } catch (error) {
      next(error);
    }
  }

  async getSpaceById(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const space = await spacesService.getSpaceById(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        data: space,
      });
    } catch (error) {
      next(error);
    }
  }

  async updateSpace(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const space = await spacesService.updateSpace(req.params.id as string, req.user!.userId, req.body);
      res.status(200).json({
        success: true,
        message: 'Space updated successfully',
        data: space,
      });
    } catch (error) {
      next(error);
    }
  }

  async deleteSpace(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await spacesService.deleteSpace(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }

  async addMember(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const member = await spacesService.addMember(req.params.id as string, req.user!.userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Member added successfully',
        data: member,
      });
    } catch (error) {
      next(error);
    }
  }

  async removeMember(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await spacesService.removeMember(
        req.params.id as string,
        req.user!.userId,
        req.params.userId as string
      );
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const spacesController = new SpacesController();
