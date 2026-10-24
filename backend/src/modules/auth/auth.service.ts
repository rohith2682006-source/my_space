import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { prisma } from '../../config/database';
import { env } from '../../config/env';
import {
  ConflictError,
  UnauthorizedError,
  NotFoundError,
  AppError,
} from '../../utils/errors';
import { JwtPayload } from '../../middleware/auth';
import { EmailService } from '../../services/email.service';
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
    // Find user — use timing-safe approach with normalized email
    const normalizedEmail = input.email.toLowerCase().trim();
    const user = await prisma.user.findFirst({
      where: {
        email: { equals: normalizedEmail },
        deletedAt: null,
      },
    });

    if (!user) {
      // Use bcrypt.hash to prevent timing attacks (same execution time)
      await bcrypt.hash('dummy', env.BCRYPT_SALT_ROUNDS);
      throw new UnauthorizedError('Invalid email or password');
    }

    // Verify password
    const isValid = await bcrypt.compare(input.password, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Update last login and prune old revoked/expired tokens
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.deleteMany({
      where: {
        userId: user.id,
        OR: [
          { revokedAt: { lt: sevenDaysAgo } },
          { expiresAt: { lt: new Date() } },
        ],
      },
    }).catch(() => {});

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
   * Authenticate a user with Google ID Token
   */
  async googleLogin(idToken: string, isSignUp: boolean = false): Promise<AuthResponse> {
    const client = new OAuth2Client();
    try {
      const ticket = await client.verifyIdToken({
        idToken,
        // audience: env.GOOGLE_CLIENT_ID, // Specify the CLIENT_ID of the app that accesses the backend
      });
      const payload = ticket.getPayload();
      if (!payload || !payload.email) {
        throw new UnauthorizedError('Invalid Google token payload');
      }

      const email = payload.email.toLowerCase();
      
      let user = await prisma.user.findUnique({
        where: { email },
      });

      if (!user) {
        if (!isSignUp) {
          throw new UnauthorizedError('Account does not exist. Please sign up first.');
        }
        // Register the user
        user = await prisma.user.create({
          data: {
            email: email,
            passwordHash: '', // No password for google accounts
            firstName: payload.given_name || 'User',
            lastName: payload.family_name || '',
            avatarUrl: payload.picture || null,
            isVerified: true,
            storageUsage: {
              create: {
                totalUsed: BigInt(0),
              },
            },
          },
        });
      } else if (isSignUp) {
         throw new UnauthorizedError('Account already exists. Please sign in instead.');
      } else if (user.deletedAt) {
        throw new UnauthorizedError('Account has been deleted');
      }

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
    } catch (error) {
      console.error('Google login error:', error);
      if (error instanceof AppError) {
        throw error;
      }
      throw new UnauthorizedError('Invalid Google token');
    }
  }

  /**
   * Refresh access token using a valid refresh token
   * Implements safe refresh token rotation
   */
  async refreshAccessToken(refreshToken: string): Promise<AuthTokens> {
    // Find the refresh token
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: true },
    });

    if (!storedToken) {
      throw new UnauthorizedError('Session expired. Please sign in again.');
    }

    if (storedToken.user.deletedAt) {
      throw new UnauthorizedError('Account has been deleted.');
    }

    // Check if expired
    if (storedToken.expiresAt < new Date()) {
      await prisma.refreshToken.delete({ where: { id: storedToken.id } }).catch(() => {});
      throw new UnauthorizedError('Session expired. Please sign in again.');
    }

    // Generate new 90-day tokens
    const tokens = await this.generateTokens({
      userId: storedToken.user.id,
      email: storedToken.user.email,
      isAdmin: storedToken.user.isAdmin,
    });

    // Remove consumed refresh token
    await prisma.refreshToken.delete({
      where: { id: storedToken.id },
    }).catch(() => {});

    return tokens;
  }

  /**
   * Logout — delete the refresh token
   */
  async logout(refreshToken: string): Promise<void> {
    await prisma.refreshToken.deleteMany({
      where: { token: refreshToken },
    }).catch(() => {});
  }

  /**
   * Logout from all devices — delete all refresh tokens
   */
  async logoutAll(userId: string): Promise<void> {
    await prisma.refreshToken.deleteMany({
      where: { userId },
    }).catch(() => {});
  }

  /**
   * Change password
   */
  async changePassword(userId: string, input: ChangePasswordInput): Promise<AuthTokens> {
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

    // Revoke all existing refresh tokens
    await this.logoutAll(userId);

    // Issue fresh tokens for the current device
    const tokens = await this.generateTokens({
      userId: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    });

    return tokens;
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

  /**
   * Request password reset OTP
   */
  async forgotPassword(input: { email: string }): Promise<{ otp?: string }> {
    const normalizedEmail = input.email.toLowerCase().trim();
    const user = await prisma.user.findFirst({
      where: {
        email: { equals: normalizedEmail },
        deletedAt: null,
      },
    });

    if (!user) {
      throw new NotFoundError('This account is not registered in this app.');
    }

    // Generate 4 digit OTP
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await prisma.user.update({
      where: { id: user.id },
      data: {
        otpCode: otp,
        otpExpiresAt: expiresAt,
      },
    });

    await EmailService.sendPasswordResetOtp({
      to: user.email,
      otp,
      recipientName: user.firstName,
    });

    return {};
  }

  /**
   * Verify OTP
   */
  async verifyOtp(input: { email: string; otp: string }): Promise<void> {
    const normalizedEmail = input.email.toLowerCase().trim();
    const user = await prisma.user.findFirst({
      where: {
        email: { equals: normalizedEmail },
        deletedAt: null,
      },
    });

    if (!user) {
      throw new UnauthorizedError('Invalid or expired OTP');
    }

    if (user.otpCode !== input.otp.trim() || !user.otpExpiresAt || user.otpExpiresAt < new Date()) {
      throw new UnauthorizedError('Invalid or expired OTP');
    }
  }

  /**
   * Reset Password
   */
  async resetPassword(input: { email: string; otp: string; newPassword: string }): Promise<AuthResponse> {
    const normalizedEmail = input.email.toLowerCase().trim();
    const user = await prisma.user.findFirst({
      where: {
        email: { equals: normalizedEmail },
        deletedAt: null,
      },
    });

    if (!user) {
      throw new UnauthorizedError('Invalid or expired OTP');
    }

    if (user.otpCode !== input.otp.trim() || !user.otpExpiresAt || user.otpExpiresAt < new Date()) {
      throw new UnauthorizedError('Invalid or expired OTP');
    }

    const newHash = await bcrypt.hash(input.newPassword, env.BCRYPT_SALT_ROUNDS);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: newHash,
        otpCode: null,
        otpExpiresAt: null,
      },
    });

    // Revoke all existing sessions
    await this.logoutAll(user.id);

    // Generate fresh tokens for the new session
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
    const days = parseInt(env.JWT_REFRESH_EXPIRY) || 90;
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
