import { randomUUID } from 'crypto';
import { prisma } from '../config/database';
import { aiService } from '../modules/ai/ai.service';
import { ForbiddenError, NotFoundError } from '../utils/errors';

async function testStep4FolderManifest() {
  console.log('🧪 [Step 4 Test] Verifying buildFolderManifest & Ownership Checks...');

  // 1. Get or create primary test user and a second unauthorized user
  const users = await prisma.user.findMany({ take: 2 });
  if (users.length === 0) {
    throw new Error('Test requires at least 1 user.');
  }

  const owner = users[0];
  let stranger = users.length > 1 ? users[1] : null;

  if (!stranger) {
    stranger = await prisma.user.create({
      data: {
        id: randomUUID(),
        email: `stranger-${Date.now()}@example.com`,
        passwordHash: 'dummyhash',
        firstName: 'Stranger',
        lastName: 'User',
      },
    });
  }

  // 2. Create a test private space owned by primary user
  const spaceId = randomUUID();
  console.log(`📁 Creating private test space ${spaceId} owned by ${owner.email}...`);

  await prisma.space.create({
    data: {
      id: spaceId,
      name: 'Manifest Test Space',
      description: 'Test space for folder manifest verification',
      isPrivate: true,
      ownerId: owner.id,
    },
  });

  const file1Id = randomUUID();
  const file2Id = randomUUID();

  try {
    // 3. Create test files: 1 READY with summary/keywords, 1 INDEXING
    await prisma.file.create({
      data: {
        id: file1Id,
        name: 'annual_report.pdf',
        originalName: 'annual_report.pdf',
        mimeType: 'application/pdf',
        extension: 'pdf',
        size: BigInt(1048576),
        storageKey: `test/${file1Id}.pdf`,
        spaceId: spaceId,
        uploadedBy: owner.id,
        category: 'DOCUMENT',
        indexStatus: 'READY',
        summary: 'Annual report summarizing revenue growth and operational metrics.',
        keywords: JSON.stringify(['annual', 'report', 'growth', 'metrics']),
        pageCount: 15,
      },
    });

    await prisma.file.create({
      data: {
        id: file2Id,
        name: 'raw_notes.txt',
        originalName: 'raw_notes.txt',
        mimeType: 'text/plain',
        extension: 'txt',
        size: BigInt(2048),
        storageKey: `test/${file2Id}.txt`,
        spaceId: spaceId,
        uploadedBy: owner.id,
        category: 'DOCUMENT',
        indexStatus: 'INDEXING',
        summary: null,
        keywords: '[]',
        pageCount: 1,
      },
    });

    // 4. Test Authorized Access (Owner)
    console.log('🔍 1. Testing authorized owner building full folder manifest...');
    const manifest = await aiService.buildFolderManifest(owner.id, spaceId);

    if (manifest.space_id !== spaceId || manifest.space_name !== 'Manifest Test Space') {
      throw new Error(`Manifest space details mismatch: ${manifest.space_id} / ${manifest.space_name}`);
    }
    if (manifest.total_files !== 2) throw new Error(`Expected 2 total_files, got ${manifest.total_files}`);
    if (manifest.ready_files !== 1) throw new Error(`Expected 1 ready_files, got ${manifest.ready_files}`);
    if (manifest.indexing_files !== 1) throw new Error(`Expected 1 indexing_files, got ${manifest.indexing_files}`);

    const file1Manifest = manifest.files.find((f) => f.id === file1Id);
    if (!file1Manifest) throw new Error('File 1 missing from manifest');
    if (file1Manifest.status !== 'READY') throw new Error(`File 1 status mismatch: ${file1Manifest.status}`);
    if (file1Manifest.summary !== 'Annual report summarizing revenue growth and operational metrics.') {
      throw new Error(`File 1 summary mismatch: ${file1Manifest.summary}`);
    }
    if (file1Manifest.page_count !== 15) throw new Error(`File 1 page_count mismatch: ${file1Manifest.page_count}`);
    if (!file1Manifest.keywords.includes('growth')) throw new Error(`File 1 keywords mismatch: ${file1Manifest.keywords}`);
    console.log('✅ Full folder manifest structure and file details verified.');

    // 5. Test Scoped File Target (e.g. only file1Id)
    console.log('🎯 2. Testing scoped targetFileIds filter...');
    const scopedManifest = await aiService.buildFolderManifest(owner.id, spaceId, [file1Id]);
    if (scopedManifest.total_files !== 1 || scopedManifest.files[0].id !== file1Id) {
      throw new Error(`Expected scoped manifest to contain only file1, got ${scopedManifest.total_files} files`);
    }
    console.log('✅ Scoped file manifest filter verified.');

    // 6. Security Check: Stranger accessing private space
    console.log('🔒 3. Testing security: unauthorized user accessing private space...');
    let unauthorizedCaught = false;
    try {
      await aiService.buildFolderManifest(stranger.id, spaceId);
    } catch (err) {
      if (err instanceof ForbiddenError || (err as any).statusCode === 403) {
        unauthorizedCaught = true;
      } else {
        throw new Error(`Expected ForbiddenError, got ${(err as Error).message}`);
      }
    }
    if (!unauthorizedCaught) {
      throw new Error('Security check FAILED: Unauthorized user was able to access private space manifest!');
    }
    console.log('✅ Security check passed: Unauthorized user access rejected with ForbiddenError (403).');

    // 7. Non-existent space check
    console.log('🔍 4. Testing non-existent space...');
    let notFoundCaught = false;
    try {
      await aiService.buildFolderManifest(owner.id, randomUUID());
    } catch (err) {
      if (err instanceof NotFoundError || (err as any).statusCode === 404) {
        notFoundCaught = true;
      }
    }
    if (!notFoundCaught) {
      throw new Error('Non-existent space check FAILED: NotFoundError was not thrown.');
    }
    console.log('✅ Non-existent space check passed: Rejected with NotFoundError (404).');

    console.log('🎉 [Step 4 Test] All folder manifest & ownership checks PASSED!');
  } finally {
    console.log('🧹 Cleaning up test space and files...');
    await prisma.file.deleteMany({ where: { spaceId } });
    await prisma.space.deleteMany({ where: { id: spaceId } });
    console.log('🧹 Cleanup complete.');
  }
}

testStep4FolderManifest()
  .catch((err) => {
    console.error('❌ Step 4 Test failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
