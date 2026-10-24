import { randomUUID } from 'crypto';
import { prisma } from '../config/database';
import { aiService } from '../modules/ai/ai.service';

async function testStep3SummaryGeneration() {
  console.log('🧪 [Step 3 Test] Verifying Per-File Summary & Keyword Persistence...');

  const user = await prisma.user.findFirst();
  const space = await prisma.space.findFirst({
    where: { ownerId: user?.id, deletedAt: null },
  });

  if (!user || !space) {
    throw new Error('Test requires an existing user and space.');
  }

  const testFileId = randomUUID();
  console.log(`📄 Creating temporary test file ${testFileId} in space ${space.name}...`);

  await prisma.file.create({
    data: {
      id: testFileId,
      name: 'quarterly_earnings_report.pdf',
      originalName: 'quarterly_earnings_report.pdf',
      mimeType: 'application/pdf',
      extension: 'pdf',
      size: BigInt(4096),
      storageKey: `test/${testFileId}.pdf`,
      spaceId: space.id,
      uploadedBy: user.id,
      category: 'DOCUMENT',
      indexStatus: 'INDEXING',
      aiSearchEnabled: true,
    },
  });

  try {
    const mockSummary =
      'This document provides an executive summary of Q3 financial performance, highlighting a 22% increase in recurring revenue, key operational cost reductions, and upcoming expansion plans.';
    const mockKeywords = ['revenue', 'earnings', 'q3', 'finance', 'growth', 'operations'];
    const mockChunkId = randomUUID();

    console.log('🔄 Invoking completeIndexing with executive summary and keywords...');
    await aiService.completeIndexing({
      fileId: testFileId,
      status: 'READY',
      summary: mockSummary,
      keywords: mockKeywords,
      pageCount: 5,
      extractedText: 'Extracted financial text for testing full document content.',
      chunks: [
        {
          id: mockChunkId,
          fileId: testFileId,
          spaceId: space.id,
          ownerId: user.id,
          content: 'Recurring revenue increased by 22% in Q3.',
          embedding: [0.05, -0.01, 0.08],
          location: 'page 1',
          pageNumber: 1,
          chunkIndex: 0,
          metadata: { fileName: 'quarterly_earnings_report.pdf' },
        },
      ],
    });

    const file = await prisma.file.findUnique({
      where: { id: testFileId },
      select: {
        id: true,
        name: true,
        summary: true,
        keywords: true,
        pageCount: true,
        extractedText: true,
        indexStatus: true,
      },
    });

    if (!file) throw new Error('File not found after completeIndexing');
    if (file.indexStatus !== 'READY') throw new Error(`Expected READY, got ${file.indexStatus}`);
    if (file.summary !== mockSummary) throw new Error(`Summary mismatch: ${file.summary}`);

    const wordCount = (file.summary || '').split(/\s+/).filter(Boolean).length;
    if (wordCount > 150) throw new Error(`Summary exceeds 150 words: got ${wordCount}`);

    const parsedKeywords = JSON.parse(file.keywords || '[]');
    if (!Array.isArray(parsedKeywords) || parsedKeywords.length !== 6) {
      throw new Error(`Keywords mismatch: ${file.keywords}`);
    }
    if (!parsedKeywords.includes('revenue') || !parsedKeywords.includes('earnings')) {
      throw new Error(`Expected keywords missing from: ${parsedKeywords}`);
    }

    console.log('✅ Summary verified:');
    console.log(`   Text: "${file.summary}"`);
    console.log(`   Word count: ${wordCount} words (<= 150 words limit)`);
    console.log('✅ Keywords verified:');
    console.log(`   Keywords array:`, parsedKeywords);
    console.log('🎉 [Step 3 Test] All per-file summary & keyword persistence assertions PASSED!');
  } finally {
    console.log('🧹 Cleaning up test file...');
    await prisma.chunk.deleteMany({ where: { fileId: testFileId } });
    await prisma.fileChunk.deleteMany({ where: { fileId: testFileId } });
    await prisma.fileIndexStatus.deleteMany({ where: { fileId: testFileId } });
    await prisma.file.deleteMany({ where: { id: testFileId } });
    console.log('🧹 Cleanup complete.');
  }
}

testStep3SummaryGeneration()
  .catch((err) => {
    console.error('❌ Step 3 Test failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
