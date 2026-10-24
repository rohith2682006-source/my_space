import { prisma } from '../config/database';

async function testStep1Migration() {
  console.log('🧪 [Step 1 Test] Verifying database schema migration...');

  // 1. Verify existing records
  const existingFiles = await prisma.file.findMany({
    take: 3,
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

  console.log(`✅ Loaded ${existingFiles.length} existing file record(s). Sample:`, existingFiles[0] || 'None');
  if (existingFiles.length > 0) {
    if (typeof existingFiles[0].keywords !== 'string') {
      throw new Error(`Expected keywords to be a string default '[]', got ${typeof existingFiles[0].keywords}`);
    }
  }

  // 2. Find a user and space to insert a temporary test record
  const user = await prisma.user.findFirst();
  const space = await prisma.space.findFirst();

  if (!user || !space) {
    console.warn('⚠️ No user or space found to run insert verification. Existing file verification passed.');
    return;
  }

  const testFileId = `test-mig-${Date.now()}`;
  console.log(`🧪 Inserting test file record ${testFileId}...`);

  const created = await prisma.file.create({
    data: {
      id: testFileId,
      name: 'migration_test.pdf',
      originalName: 'migration_test.pdf',
      mimeType: 'application/pdf',
      extension: 'pdf',
      size: BigInt(1024),
      storageKey: `test/${testFileId}.pdf`,
      spaceId: space.id,
      uploadedBy: user.id,
      category: 'DOCUMENT',
      indexStatus: 'READY',
      summary: 'This is a test summary of at most 150 words.',
      keywords: JSON.stringify(['test', 'migration', 'step1']),
      pageCount: 3,
      extractedText: 'Sample extracted document text for full analysis cache.',
    },
  });

  console.log('✅ Created test record:', {
    id: created.id,
    summary: created.summary,
    keywords: created.keywords,
    pageCount: created.pageCount,
    extractedLength: created.extractedText?.length,
  });

  // Verify fields
  if (created.summary !== 'This is a test summary of at most 150 words.') {
    throw new Error('Summary field mismatch');
  }
  if (created.pageCount !== 3) {
    throw new Error('pageCount field mismatch');
  }
  const parsedKeywords = JSON.parse(created.keywords);
  if (!Array.isArray(parsedKeywords) || parsedKeywords.length !== 3) {
    throw new Error('keywords array parsing mismatch');
  }

  // 3. Clean up
  await prisma.file.delete({ where: { id: testFileId } });
  console.log('✅ Cleaned up test record.');
  console.log('🎉 [Step 1 Test] Migration verified successfully!');
}

testStep1Migration()
  .catch((err) => {
    console.error('❌ Migration verification failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
