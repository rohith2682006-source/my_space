import { PrismaClient } from '@prisma/client';
import { enqueueJob } from '../workers/job.worker';

const prisma = new PrismaClient();

const SUPPORTED_EXTENSIONS = [
  'pdf',
  'pptx',
  'ppt',
  'docx',
  'doc',
  'txt',
  'md',
  'markdown',
  'csv',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'mp4',
  'webm',
  'mov',
  'mp3',
  'wav',
  'm4a',
];

async function main() {
  const args = process.argv.slice(2);
  let targetSpaceId: string | undefined;
  let forceAll = false;

  for (const arg of args) {
    if (arg.startsWith('--space=')) {
      targetSpaceId = arg.split('=')[1];
    } else if (arg === '--force' || arg === '--all') {
      forceAll = true;
    }
  }

  console.log('--- Spaces RAG Re-Indexing CLI ---');
  if (targetSpaceId) {
    console.log(`Target Space ID: ${targetSpaceId}`);
  }
  console.log(`Force all files: ${forceAll}`);

  const whereClause: any = {
    deletedAt: null,
    trashedAt: null,
    extension: { in: SUPPORTED_EXTENSIONS },
  };

  if (targetSpaceId) {
    whereClause.spaceId = targetSpaceId;
  }

  if (!forceAll) {
    whereClause.OR = [
      { aiSearchEnabled: true },
      { indexStatus: { in: ['READY', 'QUEUED', 'FAILED', 'OCR_REQUIRED'] } },
    ];
  }

  const files = await prisma.file.findMany({
    where: whereClause,
    select: {
      id: true,
      name: true,
      originalName: true,
      extension: true,
      storageKey: true,
      spaceId: true,
      category: true,
      content: true,
      space: { select: { ownerId: true, name: true } },
    },
  });

  console.log(`Found ${files.length} candidate file(s) for RAG indexing.`);

  let enqueuedCount = 0;
  for (const file of files) {
    const displayName = file.originalName || file.name;
    try {
      // 1. Mark as INDEXING in both File and FileIndexStatus
      await prisma.file.update({
        where: { id: file.id },
        data: { aiSearchEnabled: true, indexStatus: 'INDEXING', indexError: null },
      });

      await prisma.fileIndexStatus.upsert({
        where: { fileId: file.id },
        create: {
          fileId: file.id,
          spaceId: file.spaceId,
          status: 'indexing',
        },
        update: {
          status: 'indexing',
          error: null,
        },
      });

      // 2. Enqueue the job for worker processing
      await enqueueJob('DOCUMENT_INDEX', {
        fileId: file.id,
        fileName: displayName,
        fileExtension: file.extension.startsWith('.') ? file.extension : `.${file.extension}`,
        storageKey: file.storageKey,
        spaceId: file.spaceId,
        ownerId: file.space.ownerId,
        isNote: file.category === 'NOTE' && file.content !== null,
        noteContent: file.category === 'NOTE' ? (file.content ?? undefined) : undefined,
      });

      enqueuedCount++;
      console.log(`[${enqueuedCount}/${files.length}] Enqueued: ${displayName} (${file.id}) in space ${file.space.name}`);
    } catch (err) {
      console.error(`Failed to enqueue file ${displayName} (${file.id}):`, err);
    }
  }

  console.log(`Successfully enqueued ${enqueuedCount} file(s) for indexing.`);
}

main()
  .catch((e) => {
    console.error('Error during RAG reindex script:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
