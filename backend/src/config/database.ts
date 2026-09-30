import { PrismaClient } from '@prisma/client';
import { env } from './env';

// Use a singleton pattern for PrismaClient to prevent connection pool exhaustion
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: env.isDevelopment ? ['query', 'warn', 'error'] : ['error'],
  });

if (!env.isProduction) {
  globalForPrisma.prisma = prisma;
}

export async function connectDatabase(): Promise<void> {
  try {
    await prisma.$connect();
    console.log('✅ Database connected successfully');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    process.exit(1);
  }
}

export async function disconnectDatabase(): Promise<void> {
  await prisma.$disconnect();
  console.log('🔌 Database disconnected');
}
