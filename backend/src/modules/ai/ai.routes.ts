import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import { validate } from '../../middleware/validation';
import { UnauthorizedError } from '../../utils/errors';
import {
	chatSchema,
	deepSearchSchema,
	quickSearchSchema,
	documentIdSchema,
	indexCallbackSchema,
	reindexExistingSchema,
} from './ai.schema';
import { aiController } from './ai.controller';

const router = Router();

router.post('/chat', authenticate, validate(chatSchema), aiController.chat);
router.post('/deep-search', authenticate, validate(deepSearchSchema), aiController.deepSearch);
router.post('/quick-search', authenticate, validate(quickSearchSchema), aiController.quickSearch);
router.get('/credits/balance', authenticate, aiController.getCreditsBalance);
router.get('/credits/history', authenticate, aiController.getCreditsHistory);
router.get('/usage/stats', authenticate, aiController.getUsageStats);
router.get('/documents/:id/index-status', authenticate, validate(documentIdSchema, 'params'), aiController.getIndexStatus);
router.post('/documents/:id/reindex', authenticate, validate(documentIdSchema, 'params'), aiController.reindexDocument);
router.post(
	'/documents/reindex-existing',
	authenticate,
	validate(reindexExistingSchema),
	aiController.reindexExistingDocuments,
);
router.post(
	'/internal/index-complete',
	(req, _res, next) => {
		if (aiController.hasValidServiceToken(req.headers.authorization)) return next();
		next(new UnauthorizedError('Invalid AI service token'));
	},
	validate(indexCallbackSchema),
	aiController.indexComplete,
);

export const aiRoutes = router;