import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors';
import { env } from '../config/env';

interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}

/**
 * Global error handler — catches all errors and sends consistent JSON responses.
 * Never exposes stack traces or internal details in production.
 */
export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Log error for debugging
  if (env.isDevelopment) {
    console.error('🔥 Error:', err);
  } else {
    console.error(`[ERROR] ${err.message}`);
  }

  // Handle known operational errors
  if (err instanceof AppError) {
    const response: ErrorResponse = {
      success: false,
      error: {
        code: err.code,
        message: err.message,
      },
    };

    res.status(err.statusCode).json(response);
    return;
  }

  // Handle Multer errors
  if (err.message === 'File too large') {
    res.status(413).json({
      success: false,
      error: {
        code: 'FILE_TOO_LARGE',
        message: `File size exceeds the maximum limit of ${env.MAX_FILE_SIZE_MB}MB`,
      },
    });
    return;
  }

  // Handle Prisma errors
  if (err.constructor.name === 'PrismaClientKnownRequestError') {
    const prismaError = err as any;
    if (prismaError.code === 'P2002') {
      res.status(409).json({
        success: false,
        error: {
          code: 'DUPLICATE_ENTRY',
          message: 'A record with this value already exists',
        },
      });
      return;
    }
    if (prismaError.code === 'P2025') {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'The requested resource was not found',
        },
      });
      return;
    }
  }

  // Handle JSON parse errors
  if (err instanceof SyntaxError && 'body' in err) {
    res.status(400).json({
      success: false,
      error: {
        code: 'INVALID_JSON',
        message: 'Invalid JSON in request body',
      },
    });
    return;
  }

  // Default 500 — never expose internal details in production
  res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: env.isProduction
        ? 'Something went wrong. Please try again later.'
        : err.message,
    },
  });
}

/**
 * 404 handler for undefined routes
 */
export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    success: false,
    error: {
      code: 'ROUTE_NOT_FOUND',
      message: `Cannot ${req.method} ${req.path}`,
    },
  });
}
