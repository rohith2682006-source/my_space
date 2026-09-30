import { Router } from 'express';
import { RealtimeService } from '../../services/realtime.service';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth';

const router = Router();

/**
 * GET /api/v1/realtime/events
 * Streams real-time file, AI status, and credit changes via Server-Sent Events (SSE).
 */
router.get('/events', authenticate, (req: AuthenticatedRequest, res) => {
  RealtimeService.subscribe(req.user!.userId, res);
});

export const realtimeRoutes = router;
