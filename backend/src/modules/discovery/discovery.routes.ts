import { Router } from 'express';
import { discoveryController } from './discovery.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

router.get('/search', authenticate, discoveryController.search);
router.get('/recent', authenticate, discoveryController.getRecent);
router.get('/favorites', authenticate, discoveryController.getFavorites);
router.get('/trash', authenticate, discoveryController.getTrash);
router.get('/storage', authenticate, discoveryController.getStorage);

export const discoveryRoutes = router;
