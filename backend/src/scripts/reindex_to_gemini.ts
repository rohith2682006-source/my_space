import { PrismaClient } from '@prisma/client';
import { enqueueJob } from '../workers/job.worker';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting migration to Gemini embeddings...');

  // Find all files that are currently indexed (READY)
  const files = await prisma.file.findMany({
    where: {
      deletedAt: null,
      trashedAt: null,
      aiSearchEnabled: true,
      indexStatus: 'READY', // We only want to migrate files that are already indexed
      extension: { in: ['pdf', 'txt', 'md', 'markdown'] },
    },
    select: {
      id: true,
      name: true,
      extension: true,
      storageKey: true,
      spaceId: true,
      category: true,
      content: true,
      space: { select: { ownerId: true } },
    }
  });

  console.log(`Found ${files.length} files to re-index.`);

  for (const file of files) {
    // 1. Mark as INDEXING to avoid duplicates or confusion
    await prisma.file.update({
      where: { id: file.id },
      data: { indexStatus: 'INDEXING' }
    });

    // 2. Enqueue the job for the worker to process
    await enqueueJob('DOCUMENT_INDEX', {
      fileId: file.id,
      fileName: file.name,
      fileExtension: file.extension,
      storageKey: file.storageKey,
      spaceId: file.spaceId,
      ownerId: file.space.ownerId,
      isNote: file.category === 'NOTE',
      noteContent: file.content
    });
    
    console.log(`Enqueued job for file: ${file.name} (${file.id})`);
  }

  console.log('Finished enqueuing all migration jobs. The worker will handle the rest safely over time.');
}

main()
  .catch((e) => {
    console.error('Error during migration script:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
