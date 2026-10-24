import { randomUUID } from 'crypto';
import { prisma } from '../config/database';
import { aiService } from '../modules/ai/ai.service';

async function testStep2IngestionProgress() {
  console.log('🧪 [Step 2 Test] Verifying Ingestion Progress & Lifecycle State Callbacks...');

  const user = await prisma.user.findFirst();
  const space = await prisma.space.findFirst({
    where: { ownerId: user?.id, deletedAt: null },
  });

  if (!user || !space) {
    throw new Error('Test requires an existing user and space.');
  }

  const testFileId = randomUUID();
  console.log(`📄 Creating temporary test file ${testFileId} in space ${space.name} (${space.id})...`);

  await prisma.file.create({
    data: {
      id: testFileId,
      name: 'step2_test_document.pdf',
      originalName: 'step2_test_document.pdf',
      mimeType: 'application/pdf',
      extension: 'pdf',
      size: BigInt(2048),
      storageKey: `test/${testFileId}.pdf`,
      spaceId: space.id,
      uploadedBy: user.id,
      category: 'DOCUMENT',
      indexStatus: 'UPLOADED',
      aiSearchEnabled: true,
    },
  });

  try {
    // 1. Test intermediate stage EXTRACTING
    console.log('🔄 1. Invoking completeIndexing with status EXTRACTING...');
    await aiService.completeIndexing({
      fileId: testFileId,
      status: 'EXTRACTING',
      chunks: [],
    });

    const fileAfterExtract = await prisma.file.findUnique({ where: { id: testFileId } });
    const statusAfterExtract = await prisma.fileIndexStatus.findUnique({ where: { fileId: testFileId } });
    if (fileAfterExtract?.indexStatus !== 'EXTRACTING' || statusAfterExtract?.status !== 'extracting') {
      throw new Error(`Expected EXTRACTING/extracting, got ${fileAfterExtract?.indexStatus} / ${statusAfterExtract?.status}`);
    }
    console.log('✅ Intermediate stage EXTRACTING verified.');

    // 2. Test intermediate stage CHUNKING
    console.log('🔄 2. Invoking completeIndexing with status CHUNKING...');
    await aiService.completeIndexing({
      fileId: testFileId,
      status: 'CHUNKING',
      chunks: [],
    });

    const fileAfterChunk = await prisma.file.findUnique({ where: { id: testFileId } });
    if (fileAfterChunk?.indexStatus !== 'CHUNKING') {
      throw new Error(`Expected CHUNKING, got ${fileAfterChunk?.indexStatus}`);
    }
    console.log('✅ Intermediate stage CHUNKING verified.');

    // 3. Test intermediate stage EMBEDDING
    console.log('🔄 3. Invoking completeIndexing with status EMBEDDING...');
    await aiService.completeIndexing({
      fileId: testFileId,
      status: 'EMBEDDING',
      chunks: [],
    });

    const fileAfterEmbed = await prisma.file.findUnique({ where: { id: testFileId } });
    if (fileAfterEmbed?.indexStatus !== 'EMBEDDING') {
      throw new Error(`Expected EMBEDDING, got ${fileAfterEmbed?.indexStatus}`);
    }
    console.log('✅ Intermediate stage EMBEDDING verified.');

    // 4. Test READY with metadata and mock chunks
    console.log('🔄 4. Invoking completeIndexing with status READY and metadata...');
    const mockChunkId = randomUUID();
    await aiService.completeIndexing({
      fileId: testFileId,
      status: 'READY',
      summary: 'Quarterly financial report summarizing revenue and expense breakdowns.',
      keywords: ['finance', 'revenue', 'expenses', 'quarterly'],
      pageCount: 12,
      extractedText: 'Full extracted text for test document covering Q1 performance.',
      chunks: [
        {
          id: mockChunkId,
          fileId: testFileId,
          spaceId: space.id,
          ownerId: user.id,
          content: 'Q1 total revenue grew by 15% year over year.',
          embedding: [0.01, -0.02, 0.03],
          location: 'page 1',
          pageNumber: 1,
          chunkIndex: 0,
          metadata: { fileName: 'step2_test_document.pdf' },
        },
      ],
    });

    const fileAfterReady = await prisma.file.findUnique({ where: { id: testFileId } });
    const statusAfterReady = await prisma.fileIndexStatus.findUnique({ where: { fileId: testFileId } });
    const chunkAfterReady = await prisma.chunk.findUnique({ where: { id: mockChunkId } });

    if (fileAfterReady?.indexStatus !== 'READY' || statusAfterReady?.status !== 'ready') {
      throw new Error(`Expected READY/ready, got ${fileAfterReady?.indexStatus} / ${statusAfterReady?.status}`);
    }
    if (fileAfterReady?.summary !== 'Quarterly financial report summarizing revenue and expense breakdowns.') {
      throw new Error(`Summary mismatch: ${fileAfterReady?.summary}`);
    }
    if (fileAfterReady?.pageCount !== 12) {
      throw new Error(`PageCount mismatch: ${fileAfterReady?.pageCount}`);
    }
    if (fileAfterReady?.extractedText !== 'Full extracted text for test document covering Q1 performance.') {
      throw new Error(`ExtractedText mismatch: ${fileAfterReady?.extractedText}`);
    }
    const parsedKeywords = JSON.parse(fileAfterReady?.keywords || '[]');
    if (!Array.isArray(parsedKeywords) || parsedKeywords.length !== 4) {
      throw new Error(`Keywords mismatch: ${fileAfterReady?.keywords}`);
    }
    if (!chunkAfterReady || chunkAfterReady.fileId !== testFileId) {
      throw new Error(`Chunk was not stored properly.`);
    }

    console.log('✅ Status READY with chunks, summary, keywords, pageCount, and extractedText verified.');
    console.log('🎉 [Step 2 Test] All lifecycle state and metadata assertions PASSED!');
  } finally {
    // Cleanup
    console.log('🧹 Cleaning up test artifacts...');
    await prisma.chunk.deleteMany({ where: { fileId: testFileId } });
    await prisma.fileChunk.deleteMany({ where: { fileId: testFileId } });
    await prisma.fileIndexStatus.deleteMany({ where: { fileId: testFileId } });
    await prisma.file.deleteMany({ where: { id: testFileId } });
    console.log('🧹 Cleanup complete.');
  }
}

testStep2IngestionProgress()
  .catch((err) => {
    console.error('❌ Step 2 Test failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
