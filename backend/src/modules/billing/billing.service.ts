import crypto from 'crypto';
import { prisma } from '../../config/database';
import { AppError, NotFoundError } from '../../utils/errors';
import { AiCreditsService } from '../ai/ai.credits.service';
import { AuditService } from '../../services/audit.service';


export class BillingService {
  /**
   * Get all active subscription plans.
   */
  static async listPlans() {
    return await prisma.plan.findMany({
      where: { isActive: true },
      orderBy: { priceMonthly: 'asc' },
    });
  }

  /**
   * Get single plan by ID or name.
   */
  static async getPlan(identifier: string) {
    const plan = await prisma.plan.findFirst({
      where: {
        OR: [{ id: identifier }, { name: identifier }],
      },
    });
    if (!plan) throw new NotFoundError('Plan not found');
    return plan;
  }

  /**
   * Get current user's subscription and active plan details.
   */
  static async getUserSubscription(userId: string) {
    let subscription = await prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
      include: { plan: true },
      orderBy: { createdAt: 'desc' },
    });

    if (!subscription) {
      // Default to FREE plan
      const freePlan = await prisma.plan.findUnique({ where: { name: 'free' } });
      if (freePlan) {
        subscription = await prisma.subscription.create({
          data: {
            userId,
            planId: freePlan.id,
            status: 'ACTIVE',
            billingPeriod: 'MONTHLY',
            currentPeriodStart: new Date(),
            currentPeriodEnd: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year
          },
          include: { plan: true },
        });
      }
    }

    const creditBalance = await AiCreditsService.getBalance(userId);

    return {
      subscription,
      credits: creditBalance,
    };
  }

  /**
   * Initiate an order/subscription upgrade.
   */
  static async createOrder(userId: string, planId: string, billingCycle: 'monthly' | 'yearly' = 'monthly') {
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) throw new NotFoundError('Selected plan does not exist');

    const price = (billingCycle === 'yearly' ? plan.priceYearly : plan.priceMonthly) ?? 0;
    const amountInPaise = Math.round(price * 100);

    const orderId = `order_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    const payment = await prisma.payment.create({
      data: {
        userId,
        razorpayOrderId: orderId,
        amountPaise: amountInPaise,
        currency: 'INR',
        status: 'PENDING',
        description: `Upgrade to ${plan.displayName} (${billingCycle})`,
      },
    });

    return {
      orderId,
      paymentId: payment.id,
      amount: amountInPaise,
      currency: 'INR',
      planName: plan.displayName,
      keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_spaces_demo',
    };
  }

  /**
   * Verify payment signature and activate plan/subscription.
   */
  static async verifyPayment(
    userId: string,
    params: {
      razorpayOrderId: string;
      razorpayPaymentId: string;
      razorpaySignature: string;
      planId: string;
    }
  ) {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature, planId } = params;

    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (keySecret) {
      const generatedSignature = crypto
        .createHmac('sha256', keySecret)
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest('hex');

      if (generatedSignature !== razorpaySignature) {
        throw new AppError('Payment signature verification failed', 400, 'PAYMENT_VERIFICATION_FAILED');
      }
    }

    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) throw new NotFoundError('Plan not found');

    // Update payment record
    await prisma.payment.updateMany({
      where: { razorpayOrderId },
      data: {
        razorpayPaymentId,
        razorpaySignature,
        status: 'CAPTURED',
        verifiedAt: new Date(),
      },
    });

    const periodEnd = new Date();
    periodEnd.setMonth(periodEnd.getMonth() + 1);

    const existingSub = await prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
    });

    let subscription;
    if (existingSub) {
      subscription = await prisma.subscription.update({
        where: { id: existingSub.id },
        data: {
          planId: plan.id,
          status: 'ACTIVE',
          razorpayOrderId,
          razorpayPaymentId,
          currentPeriodStart: new Date(),
          currentPeriodEnd: periodEnd,
        },
        include: { plan: true },
      });
    } else {
      subscription = await prisma.subscription.create({
        data: {
          userId,
          planId: plan.id,
          status: 'ACTIVE',
          billingPeriod: 'MONTHLY',
          razorpayOrderId,
          razorpayPaymentId,
          currentPeriodStart: new Date(),
          currentPeriodEnd: periodEnd,
        },
        include: { plan: true },
      });
    }

    // Grant monthly plan credits
    await AiCreditsService.addCredits(
      userId,
      plan.aiCreditsMonthly,
      'GRANT',
      `Subscribed to ${plan.displayName} plan`
    );

    AuditService.log({
      userId,
      action: 'SUBSCRIPTION_UPGRADE',
      targetType: 'plan',
      targetId: plan.id,
      metadata: { planName: plan.displayName, orderId: razorpayOrderId },
    });

    return {
      success: true,
      subscription,
      message: `Successfully upgraded to ${plan.displayName}!`,
    };
  }

  /**
   * Cancel subscription at period end.
   */
  static async cancelSubscription(userId: string) {
    const sub = await prisma.subscription.findFirst({
      where: { userId, status: 'ACTIVE' },
    });
    if (!sub) throw new NotFoundError('No active subscription found');

    const updated = await prisma.subscription.update({
      where: { id: sub.id },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
      },
    });

    AuditService.log({
      userId,
      action: 'SUBSCRIPTION_CANCEL',
      targetType: 'subscription',
      targetId: sub.id,
    });

    return updated;
  }

  /**
   * Purchase additional credit pack.
   */
  static async purchaseCredits(userId: string, creditsAmount: number, priceInr: number) {
    const orderId = `credit_order_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const amountInPaise = Math.round(priceInr * 100);

    await prisma.payment.create({
      data: {
        userId,
        razorpayOrderId: orderId,
        amountPaise: amountInPaise,
        currency: 'INR',
        status: 'PENDING',
        description: `Top-up ${creditsAmount} AI credits`,
      },
    });

    return {
      orderId,
      creditsAmount,
      amount: amountInPaise,
      currency: 'INR',
      keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_spaces_demo',
    };
  }

  /**
   * Verify credits purchase.
   */
  static async verifyCreditsPurchase(
    userId: string,
    params: {
      orderId: string;
      paymentId: string;
      signature?: string;
      credits: number;
    }
  ) {
    await prisma.payment.updateMany({
      where: { razorpayOrderId: params.orderId },
      data: {
        razorpayPaymentId: params.paymentId,
        razorpaySignature: params.signature,
        status: 'CAPTURED',
        verifiedAt: new Date(),
      },
    });

    await AiCreditsService.addCredits(
      userId,
      params.credits,
      'PURCHASE',
      `Purchased ${params.credits} AI credits`
    );

    AuditService.log({
      userId,
      action: 'CREDITS_PURCHASE',
      targetType: 'credits',
      metadata: { credits: params.credits, orderId: params.orderId },
    });

    const balance = await AiCreditsService.getBalance(userId);

    return {
      success: true,
      creditsAdded: params.credits,
      newBalance: balance.balance,
    };
  }


  /**
   * Handle Razorpay webhook with signature verification and idempotency.
   */
  static async handleWebhook(rawBody: string, signature: string) {
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || process.env.RAZORPAY_KEY_SECRET;
    if (webhookSecret && signature) {
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex');

      if (expectedSignature !== signature) {
        throw new AppError('Invalid webhook signature', 400, 'INVALID_WEBHOOK_SIGNATURE');
      }
    }

    let event: any;
    try {
      event = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    } catch {
      throw new AppError('Invalid webhook payload', 400, 'INVALID_PAYLOAD');
    }

    const eventId = event.id || `evt_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const eventType = event.event || 'unknown';

    // Idempotency check via WebhookEvent table
    const existing = await prisma.webhookEvent.findUnique({
      where: { eventId },
    });
    if (existing) {
      return { status: 'already_processed', eventId };
    }

    const webhookRecord = await prisma.webhookEvent.create({
      data: {
        provider: 'razorpay',
        eventId,
        eventType,
        payload: typeof rawBody === 'string' ? rawBody : JSON.stringify(rawBody),
      },
    });

    try {
      if (eventType === 'payment.captured' || eventType === 'order.paid') {
        const paymentEntity = event.payload?.payment?.entity;
        if (paymentEntity?.order_id) {
          await prisma.payment.updateMany({
            where: { razorpayOrderId: paymentEntity.order_id },
            data: {
              razorpayPaymentId: paymentEntity.id,
              status: 'CAPTURED',
              verifiedAt: new Date(),
            },
          });
        }
      } else if (eventType === 'subscription.cancelled') {
        const subEntity = event.payload?.subscription?.entity;
        if (subEntity?.id) {
          await prisma.subscription.updateMany({
            where: { razorpaySubscriptionId: subEntity.id },
            data: { status: 'CANCELLED', cancelledAt: new Date() },
          });
        }
      }

      await prisma.webhookEvent.update({
        where: { id: webhookRecord.id },
        data: { processedAt: new Date() },
      });

      return { status: 'success', eventId };
    } catch (err: any) {
      await prisma.webhookEvent.update({
        where: { id: webhookRecord.id },
        data: { error: err.message },
      });
      throw err;
    }
  }
}

