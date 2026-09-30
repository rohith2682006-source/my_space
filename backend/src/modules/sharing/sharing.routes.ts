import { Router } from 'express';
import { sharingController } from './sharing.controller';
import { authenticate } from '../../middleware/auth';
import { validate } from '../../middleware/validation';
import {
  createShareLinkSchema,
  accessShareLinkSchema,
} from './sharing.schema';

const router = Router();

// Public: Resolve a share link by token (both POST and GET supported)
router.post(
  '/resolve/:token',
  validate(accessShareLinkSchema),
  sharingController.resolveLink
);
router.get(
  '/resolve/:token',
  sharingController.resolveLink
);

// Public: Direct file inline view or download via share link token
router.get('/:token/view', sharingController.viewFile);
router.get('/:token/file', sharingController.viewFile);
router.get('/:token/download', sharingController.downloadFile);

// Protected routes
router.use(authenticate);
router.post('/', validate(createShareLinkSchema), sharingController.createLink);
router.get('/my-links', sharingController.listUserLinks);
router.get('/:id/stats', sharingController.getStats);
router.delete('/:id', sharingController.revokeLink);

export const sharingRoutes = router;
