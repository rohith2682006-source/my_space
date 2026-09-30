import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { BillingService } from './billing.service';

export class BillingController {
  async getPlans(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const plans = await BillingService.listPlans();
      res.status(200).json({ success: true, data: plans });
    } catch (error) {
      next(error);
    }
  }

  async getSubscription(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const data = await BillingService.getUserSubscription(req.user!.userId);
      res.status(200).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  }

  async createOrder(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { planId, billingCycle } = req.body;
      const order = await BillingService.createOrder(req.user!.userId, planId, billingCycle);
      res.status(200).json({ success: true, data: order });
    } catch (error) {
      next(error);
    }
  }

  async verifyPayment(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await BillingService.verifyPayment(req.user!.userId, req.body);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async cancelSubscription(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await BillingService.cancelSubscription(req.user!.userId);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async buyCredits(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { credits, priceInr } = req.body;
      const order = await BillingService.purchaseCredits(req.user!.userId, credits, priceInr);
      res.status(200).json({ success: true, data: order });
    } catch (error) {
      next(error);
    }
  }

  async verifyBuyCredits(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await BillingService.verifyCreditsPurchase(req.user!.userId, req.body);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async handleWebhook(req: any, res: Response, next: NextFunction): Promise<void> {
    try {
      const signature = req.headers['x-razorpay-signature'] as string;
      const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
      const result = await BillingService.handleWebhook(rawBody, signature);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }
}

export const billingController = new BillingController();

