import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import { adminController } from './admin.controller';

const router = Router();

router.get('/overview', authenticate, adminController.getOverview.bind(adminController));
router.get('/users', authenticate, adminController.listUsers.bind(adminController));
router.get('/financials', authenticate, adminController.getFinancials.bind(adminController));
router.get('/operating-costs', authenticate, adminController.getOperatingCosts.bind(adminController));
router.post('/operating-costs', authenticate, adminController.createOperatingCost.bind(adminController));
router.delete('/operating-costs/:id', authenticate, adminController.deleteOperatingCost.bind(adminController));

export const adminRoutes = router;

