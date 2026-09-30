import { Router } from 'express';
import { activityController } from './activity.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

router.use(authenticate);
router.get('/', activityController.getRecentActivities);
router.get('/space/:spaceId', activityController.getSpaceActivities);

export const activityRoutes = router;
