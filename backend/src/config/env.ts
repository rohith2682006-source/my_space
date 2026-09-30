import { z } from 'zod';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  API_VERSION: z.string().default('v1'),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters'),
  JWT_ACCESS_EXPIRY: z.string().default('15m'),
  JWT_REFRESH_EXPIRY: z.string().default('7d'),

  CORS_ORIGINS: z.string().default('http://localhost:3000'),
  APP_URL: z.string().default('http://localhost:3000'),

  AI_SERVICE_URL: z.string().url().default('http://127.0.0.1:8000'),
  AI_SERVICE_TOKEN: z.string().default(''),

  MAX_FILE_SIZE_MB: z.coerce.number().default(500),
  UPLOAD_DIR: z.string().default('./uploads'),

  STORAGE_PROVIDER: z.enum(['local', 's3', 'gcs']).default('local'),

  RATE_LIMIT_WINDOW_MS: z.coerce.number().default(900000),
  RATE_LIMIT_MAX_REQUESTS: z.coerce.number().default(100),

  BCRYPT_SALT_ROUNDS: z.coerce.number().default(12),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.format());
  process.exit(1);
}

export const env = {
  ...parsed.data,
  isProduction: parsed.data.NODE_ENV === 'production',
  isDevelopment: parsed.data.NODE_ENV === 'development',
  corsOrigins: parsed.data.CORS_ORIGINS.split(',').map((s) => s.trim()),
  maxFileSizeBytes: parsed.data.MAX_FILE_SIZE_MB * 1024 * 1024,
  uploadDir: path.resolve(parsed.data.UPLOAD_DIR),
};

export type Env = typeof env;
