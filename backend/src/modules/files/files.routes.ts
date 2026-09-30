import { Router } from 'express';
import { filesController } from './files.controller';
import { authenticate } from '../../middleware/auth';
import { validate } from '../../middleware/validation';
import { uploadMiddleware } from './upload.middleware';
import {
  fileQuerySchema,
  renameFileSchema,
  moveFileSchema,
  createNoteOrLinkSchema,
  aiSearchAccessSchema,
} from './files.schema';

const router = Router();

// Authenticated routes
router.use(authenticate);

// Space-specific file operations
router.post(
  '/spaces/:spaceId/upload',
  uploadMiddleware.single('file'),
  filesController.uploadFile
);
router.get(
  '/spaces/:spaceId',
  validate(fileQuerySchema, 'query'),
  filesController.listFilesInSpace
);

// Note and Link creation
router.post(
  '/notes-links',
  validate(createNoteOrLinkSchema),
  filesController.createNoteOrLink
);

// Individual file operations
router.get('/:id', filesController.getFileById);
router.get('/:id/download', filesController.downloadFile);
router.get('/:id/preview', filesController.previewFile);
router.patch('/:id/rename', validate(renameFileSchema), filesController.renameFile);
router.post('/:id/move', validate(moveFileSchema), filesController.moveFile);
router.post('/:id/favorite', filesController.toggleFavorite);
router.patch('/:id/ai-access', validate(aiSearchAccessSchema), filesController.setAiSearchAccess);
router.post('/:id/trash', filesController.trashFile);
router.post('/:id/restore', filesController.restoreFile);
router.delete('/:id/permanent', filesController.deletePermanently);

export const filesRoutes = router;
