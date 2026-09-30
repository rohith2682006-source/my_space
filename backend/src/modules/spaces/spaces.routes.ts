import { Router } from 'express';
import { spacesController } from './spaces.controller';
import { authenticate } from '../../middleware/auth';
import { validate } from '../../middleware/validation';
import {
  createSpaceSchema,
  updateSpaceSchema,
  spaceQuerySchema,
  addSpaceMemberSchema,
} from './spaces.schema';

const router = Router();

// All Space routes require authentication
router.use(authenticate);

router.post('/', validate(createSpaceSchema), spacesController.createSpace);
router.get('/', validate(spaceQuerySchema, 'query'), spacesController.listSpaces);
router.get('/:id', spacesController.getSpaceById);
router.patch('/:id', validate(updateSpaceSchema), spacesController.updateSpace);
router.delete('/:id', spacesController.deleteSpace);

// Space members
router.post('/:id/members', validate(addSpaceMemberSchema), spacesController.addMember);
router.delete('/:id/members/:userId', spacesController.removeMember);

export const spacesRoutes = router;
