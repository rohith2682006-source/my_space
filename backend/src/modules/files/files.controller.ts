import { Response, NextFunction } from 'express';
import { filesService } from './files.service';
import { AuthenticatedRequest } from '../../middleware/auth';
import { BadRequestError } from '../../utils/errors';

export class FilesController {
  async uploadFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.file) {
        throw new BadRequestError('No file uploaded');
      }

      const spaceId = req.params.spaceId as string;
      const forceDuplicate = req.query.force === 'true';

      const result = await filesService.uploadFile(
        req.user!.userId,
        spaceId,
        req.file,
        forceDuplicate
      );

      if (result.isDuplicate) {
        res.status(200).json({
          success: false,
          isDuplicate: true,
          duplicateOf: result.duplicateOf,
          message: result.message,
        });
        return;
      }

      res.status(201).json({
        success: true,
        message: 'File uploaded successfully',
        data: result.file,
      });
    } catch (error) {
      next(error);
    }
  }

  async createNoteOrLink(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.createNoteOrLink(req.user!.userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Created successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async listFilesInSpace(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const spaceId = req.params.spaceId as string;
      const result = await filesService.listFilesInSpace(
        spaceId,
        req.user!.userId,
        req.query as any
      );
      res.status(200).json({
        success: true,
        ...result,
      });
    } catch (error) {
      next(error);
    }
  }

  async getFileById(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const file = await filesService.getFileById(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        data: file,
      });
    } catch (error) {
      next(error);
    }
  }

  async downloadFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { stream, file } = await filesService.getFileStream(req.params.id as string, req.user!.userId);

      res.setHeader('Content-Type', file.mimeType);
      res.setHeader('Content-Length', file.size.toString());
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${encodeURIComponent(file.name)}"`
      );

      stream.pipe(res);
    } catch (error) {
      next(error);
    }
  }

  async previewFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { stream, file } = await filesService.getFileStream(req.params.id as string, req.user!.userId);

      res.setHeader('Content-Type', file.mimeType);
      res.setHeader('Content-Length', file.size.toString());
      res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(file.name)}"`);

      stream.pipe(res);
    } catch (error) {
      next(error);
    }
  }

  async renameFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const updated = await filesService.renameFile(req.params.id as string, req.user!.userId, req.body);
      res.status(200).json({
        success: true,
        message: 'File renamed successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  async moveFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.moveFile(req.params.id as string, req.user!.userId, req.body);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }

  async toggleFavorite(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.toggleFavorite(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async setAiSearchAccess(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.setAiSearchAccess(
        req.params.id as string,
        req.user!.userId,
        req.body.enabled,
      );
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async trashFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.trashFile(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }

  async restoreFile(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.restoreFile(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }

  async deletePermanently(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await filesService.deletePermanently(req.params.id as string, req.user!.userId);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const filesController = new FilesController();
