import express, { Express } from 'express';
import fs from 'fs';
import path from 'path';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cookieParser from 'cookie-parser';
import { env } from './config/env';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';

// Route imports
import { authRoutes } from './modules/auth/auth.routes';
import { spacesRoutes } from './modules/spaces/spaces.routes';
import { filesRoutes } from './modules/files/files.routes';
import { discoveryRoutes } from './modules/discovery/discovery.routes';
import { sharingRoutes } from './modules/sharing/sharing.routes';
import { sharingController } from './modules/sharing/sharing.controller';
import { activityRoutes } from './modules/activity/activity.routes';
import { aiRoutes } from './modules/ai/ai.routes';
import { billingRoutes } from './modules/billing/billing.routes';
import { adminRoutes } from './modules/admin/admin.routes';
import { realtimeRoutes } from './modules/realtime/realtime.routes';

// Enable JSON serialization of BigInt fields
(BigInt.prototype as any).toJSON = function () {
  const int = Number(this);
  return int <= Number.MAX_SAFE_INTEGER ? int : this.toString();
};

export function createApp(): Express {
  const app = express();

  // 1. Security Headers (Helmet)
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      contentSecurityPolicy: env.isProduction ? undefined : false,
    })
  );

  // 2. CORS
  app.use(
    cors({
      origin: (origin, callback) => {
        // Allow mobile app requests (where origin is undefined) or explicitly configured CORS origins
        if (!origin || env.corsOrigins.includes(origin) || env.corsOrigins.includes('*')) {
          callback(null, true);
        } else if (!env.isProduction) {
          callback(null, true); // Permissive during local development
        } else {
          callback(new Error('Origin blocked by CORS policy'));
        }
      },
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    })
  );

  // Request logger & response timer
  app.use((req, res, next) => {
    const start = performance.now();
    res.on('finish', () => {
      const elapsed = (performance.now() - start).toFixed(1);
      if (req.path.startsWith('/api') || req.path === '/health') {
        console.log(`📡 [${req.method}] ${req.originalUrl} ${res.statusCode} (${elapsed}ms) - Auth: ${req.headers.authorization ? 'Bearer' : 'NONE'}`);
      }
    });
    next();
  });

  // 3. Rate Limiting
  const limiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX_REQUESTS,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: {
        code: 'RATE_LIMITED',
        message: 'Too many requests from this IP, please try again later.',
      },
    },
  });
  app.use(limiter);

  // 4. Body Parsers (Production sized)
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ extended: true, limit: '50mb' }));
  app.use(cookieParser());

  // 5. Health Check
  app.get('/health', (_req, res) => {
    res.status(200).json({
      status: 'healthy',
      app: 'Spaces API',
      version: env.API_VERSION,
      timestamp: new Date().toISOString(),
    });
  });

  // 6. API Routes
  const apiPrefix = `/api/${env.API_VERSION}`;
  app.use(`${apiPrefix}/auth`, authRoutes);
  app.use(`${apiPrefix}/spaces`, spacesRoutes);
  app.use(`${apiPrefix}/files`, filesRoutes);
  app.use(`${apiPrefix}/share`, sharingRoutes);
  app.use(`${apiPrefix}/activities`, activityRoutes);
  app.use(`${apiPrefix}/ai`, aiRoutes);
  app.use(`${apiPrefix}/billing`, billingRoutes);
  app.use(`${apiPrefix}/admin`, adminRoutes);
  app.use(`${apiPrefix}/realtime`, realtimeRoutes);
  app.use(`${apiPrefix}`, discoveryRoutes);

  // 6.5 Direct Public File Share Links (Streams only the shared file in real-time)
  app.get('/share/:token', (req, res, next) => {
    sharingController.viewFile(req, res, next);
  });

  // 7. Flutter Web Application Static Serving
  const webBuildPath = path.resolve(__dirname, '../../spaces_app/build/web');
  if (fs.existsSync(webBuildPath)) {
    app.use(express.static(webBuildPath));
    app.use((req, res, next) => {
      if (req.path.startsWith('/api') || req.method !== 'GET') {
        return next();
      }
      res.sendFile(path.join(webBuildPath, 'index.html'));
    });
  }

  // 8. 404 & Error Handling
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
