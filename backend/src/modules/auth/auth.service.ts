import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/database';
import { env } from '../../config/env';
import {
  ConflictError,
  UnauthorizedError,
  NotFoundError,
} from '../../utils/errors';
import { JwtPayload } from '../../middleware/auth';
import type {
  RegisterInput,
  LoginInput,
  ChangePasswordInput,
} from './auth.schema';

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
}

interface AuthResponse {
  user: {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
    avatarUrl: string | null;
    isVerified: boolean;
  };
  tokens: AuthTokens;
}

export class AuthService {
  /**
   * Register a new user account
   */
  async register(input: RegisterInput): Promise<AuthResponse> {
    // Check if email already exists
    const existing = await prisma.user.findUnique({
      where: { email: input.email },
    });

    if (existing) {
      throw new ConflictError('An account with this email already exists');
    }

    // Hash password with bcrypt
    const passwordHash = await bcrypt.hash(input.password, env.BCRYPT_SALT_ROUNDS);

    // Create user with default free plan storage tracking
    const user = await prisma.user.create({
      data: {
        email: input.email,
        passwordHash,
        firstName: input.firstName,
        lastName: input.lastName,
        storageUsage: {
          create: {
            totalUsed: BigInt(0),
          },
        },
      },
    });

    // Generate tokens
    const tokens = await this.generateTokens({
      userId: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatarUrl: user.avatarUrl,
        isVerified: user.isVerified,
      },
      tokens,
    };
  }

  /**
   * Authenticate a user with email and password
   */
  async login(input: LoginInput): Promise<AuthResponse> {
    // Find user — use timing-safe approach
    const user = await prisma.user.findUnique({
      where: { email: input.email },
    });

    if (!user || user.deletedAt) {
      // Use bcrypt.hash to prevent timing attacks (same execution time)
      await bcrypt.hash('dummy', env.BCRYPT_SALT_ROUNDS);
      throw new UnauthorizedError('Invalid email or password');
    }

    // Verify password
    const isValid = await bcrypt.compare(input.password, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Update last login
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    // Generate tokens
    const tokens = await this.generateTokens({
      userId: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatarUrl: user.avatarUrl,
        isVerified: user.isVerified,
      },
      tokens,
    };
  }

  /**
   * Refresh access token using a valid refresh token
   * Implements refresh token rotation for security
   */
  async refreshAccessToken(refreshToken: string): Promise<AuthTokens> {
    // Find the refresh token
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!storedToken) {
      throw new UnauthorizedError('Invalid refresh token');
    }

    // Check if revoked
    if (storedToken.revokedAt) {
      // Potential token theft — revoke ALL tokens for this user
      await prisma.refreshToken.updateMany({
        where: { userId: storedToken.userId },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedError('Refresh token has been revoked. Please login again.');
    }

    // Check if expired
    if (storedToken.expiresAt < new Date()) {
      throw new UnauthorizedError('Refresh token has expired. Please login again.');
    }

    // Revoke old token (rotation)
    await prisma.refreshToken.update({
      where: { id: storedToken.id },
      data: { revokedAt: new Date() },
    });

    // Generate new tokens
    const tokens = await this.generateTokens({
      userId: storedToken.user.id,
      email: storedToken.user.email,
      isAdmin: storedToken.user.isAdmin,
    });

    return tokens;
  }

  /**
   * Logout — revoke the refresh token
   */
  async logout(refreshToken: string): Promise<void> {
    await prisma.refreshToken.updateMany({
      where: { token: refreshToken, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Logout from all devices — revoke all refresh tokens
   */
  async logoutAll(userId: string): Promise<void> {
    await prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Change password
   */
  async changePassword(userId: string, input: ChangePasswordInput): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    const isValid = await bcrypt.compare(input.currentPassword, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedError('Current password is incorrect');
    }

    const newHash = await bcrypt.hash(input.newPassword, env.BCRYPT_SALT_ROUNDS);

    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });

    // Revoke all refresh tokens (force re-login on all devices)
    await this.logoutAll(userId);
  }

  /**
   * Get current user profile
   */
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatarUrl: true,
        isVerified: true,
        createdAt: true,
        lastLoginAt: true,
        storageUsage: true,
      },
    });

    if (!user) {
      throw new NotFoundError('User not found');
    }

    return user;
  }

  // ─── Private helpers ────────────────────────────────────────

  private async generateTokens(payload: JwtPayload): Promise<AuthTokens> {
    const accessToken = jwt.sign(
      { ...payload, jti: crypto.randomUUID() },
      env.JWT_ACCESS_SECRET,
      { expiresIn: env.JWT_ACCESS_EXPIRY as any }
    );

    const refreshToken = jwt.sign(
      { userId: payload.userId, jti: crypto.randomUUID() },
      env.JWT_REFRESH_SECRET,
      { expiresIn: env.JWT_REFRESH_EXPIRY as any }
    );

    // Calculate expiry date
    const expiresAt = new Date();
    const days = parseInt(env.JWT_REFRESH_EXPIRY) || 7;
    expiresAt.setDate(expiresAt.getDate() + days);

    // Store refresh token in database
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: payload.userId,
        expiresAt,
      },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: env.JWT_ACCESS_EXPIRY,
    };
  }
}

export const authService = new AuthService();
