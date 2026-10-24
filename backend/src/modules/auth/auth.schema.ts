import { z } from 'zod';

export const registerSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .max(255)
    .transform((v) => v.toLowerCase().trim()),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128)
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    ),
  firstName: z
    .string()
    .min(1, 'First name is required')
    .max(100)
    .trim(),
  lastName: z
    .string()
    .min(1, 'Last name is required')
    .max(100)
    .trim(),
});

export const loginSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .transform((v) => v.toLowerCase().trim()),
  password: z
    .string()
    .min(1, 'Password is required')
    .max(128),
});

export const googleLoginSchema = z.object({
  idToken: z.string().min(1, 'ID Token is required'),
  isSignUp: z.boolean().optional().default(false),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128)
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    ),
});

export const forgotPasswordSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .transform((v) => v.toLowerCase().trim()),
});

export const verifyOtpSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .transform((v) => v.toLowerCase().trim()),
  otp: z.string().length(4, 'OTP must be 4 digits'),
});

export const resetPasswordSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .transform((v) => v.toLowerCase().trim()),
  otp: z.string().length(4, 'OTP must be 4 digits'),
  newPassword: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(128)
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
      'Password must contain at least one uppercase letter, one lowercase letter, and one number'
    ),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenSchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
