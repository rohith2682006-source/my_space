import { Router } from 'express';
import { authController } from './auth.controller';
import { authenticate } from '../../middleware/auth';
import { validate } from '../../middleware/validation';
import {
  registerSchema,
  loginSchema,
  refreshTokenSchema,
  changePasswordSchema,
  googleLoginSchema,
  forgotPasswordSchema,
  verifyOtpSchema,
  resetPasswordSchema,
} from './auth.schema';

const router = Router();

// Public routes
router.post('/register', validate(registerSchema), authController.register);
router.post('/login', validate(loginSchema), authController.login);
router.post('/google', validate(googleLoginSchema), authController.googleLogin);
router.post('/refresh', validate(refreshTokenSchema), authController.refreshToken);
router.post('/logout', authController.logout);
router.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);
router.post('/verify-otp', validate(verifyOtpSchema), authController.verifyOtp);
router.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

// Protected routes
router.get('/me', authenticate, authController.getProfile);
router.post('/logout-all', authenticate, authController.logoutAll);
router.post(
  '/change-password',
  authenticate,
  validate(changePasswordSchema),
  authController.changePassword
);

export const authRoutes = router;
