import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { UnauthorizedError } from '../utils/errors';
import { prisma } from '../config/database';

export interface JwtPayload {
  userId: string;
  email: string;
  isAdmin: boolean;
}

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

/**
 * Verify JWT access token and attach user to request
 */
export function authenticate(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): void {
  try {
    let token: string | undefined;
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
    } else if (req.query && typeof req.query.token === 'string') {
      token = req.query.token;
    }

    if (!token) {
      throw new UnauthorizedError('Access token is required');
    }

    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
    req.user = decoded;
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      next(new UnauthorizedError('Access token has expired'));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(new UnauthorizedError('Invalid access token'));
    } else {
      next(error);
    }
  }
}

/**
 * Optional authentication — attach user if token exists, but don't block
 */
export function optionalAuth(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): void {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      if (token) {
        const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
        req.user = decoded;
      }
    }
    next();
  } catch {
    // Silently continue without user
    next();
  }
}

/**
 * Require admin role
 */
export function requireAdmin(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): void {
  if (!req.user?.isAdmin) {
    return next(new UnauthorizedError('Admin access required'));
  }
  next();
}

/**
 * Verify user still exists and is not deleted
 */
export async function verifyUserExists(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    if (!req.user) {
      throw new UnauthorizedError();
    }

    const user = await prisma.user.findFirst({
      where: {
        id: req.user.userId,
        deletedAt: null,
      },
    });

    if (!user) {
      throw new UnauthorizedError('User account not found or deactivated');
    }

    next();
  } catch (error) {
    next(error);
  }
}
