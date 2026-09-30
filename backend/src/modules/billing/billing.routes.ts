import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import { billingController } from './billing.controller';

const router = Router();

// Public / Authenticated plans
router.get('/plans', billingController.getPlans);
router.get('/subscription', authenticate, billingController.getSubscription);
router.post('/orders', authenticate, billingController.createOrder);
router.post('/verify', authenticate, billingController.verifyPayment);
router.post('/cancel', authenticate, billingController.cancelSubscription);
router.post('/credits/buy', authenticate, billingController.buyCredits);
router.post('/credits/verify', authenticate, billingController.verifyBuyCredits);
router.post('/webhook', billingController.handleWebhook);

export const billingRoutes = router;

