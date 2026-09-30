import { createApp } from './app';
import { env } from './config/env';
import { connectDatabase, disconnectDatabase } from './config/database';
import { startJobWorker, stopJobWorker } from './workers/job.worker';

async function bootstrap() {
  // Connect to Database
  await connectDatabase();

  // Start background job worker
  startJobWorker();

  const app = createApp();

  const server = app.listen(env.PORT, () => {
    console.log(`
🚀 ═══════════════════════════════════════════════════════════
   SPACES API SERVER STARTED
   Port:        ${env.PORT}
   Environment: ${env.NODE_ENV}
   API Base:    http://localhost:${env.PORT}/api/${env.API_VERSION}
   Health:      http://localhost:${env.PORT}/health
═══════════════════════════════════════════════════════════════
    `);
  });

  // Graceful shutdown handling
  const shutdown = async (signal: string) => {
    console.log(`\n🛑 Received ${signal}. Starting graceful shutdown...`);
    stopJobWorker();
    server.close(async () => {
      console.log('🔒 HTTP server closed');
      await disconnectDatabase();
      console.log('👋 Goodbye!');
      process.exit(0);
    });

    // Force exit after 10s if stuck
    setTimeout(() => {
      console.error('⚠️ Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrap().catch((error) => {
  console.error('💥 Fatal error starting server:', error);
  process.exit(1);
});

