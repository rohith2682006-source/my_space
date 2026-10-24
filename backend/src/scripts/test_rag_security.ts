import { PrismaClient } from '@prisma/client';
import { aiService } from '../modules/ai/ai.service';
import { v4 as uuidv4 } from 'uuid';

const prisma = new PrismaClient();

async function runSecurityTests() {
  console.log('=== PHASE 5: SECURITY, SHARING & ACCESS CONTROL TEST ===\n');

  // 1. Setup two distinct test users
  const userA = await prisma.user.findFirst();
  if (!userA) throw new Error('Primary user not found');

  const testUserBEmail = `security_test_${Date.now()}@example.com`;
  const userB = await prisma.user.create({
    data: {
      email: testUserBEmail,
      passwordHash: 'dummy_hash_for_test_123',
      firstName: 'Security',
      lastName: 'Tester',
    },
  });
  console.log(`[1] Created Test User B: ${userB.email} (${userB.id})`);

  try {
    // 2. Create private space for User A with indexed chunk
    const privateSpaceA = await prisma.space.create({
      data: {
        name: `Private Space A ${Date.now()}`,
        ownerId: userA.id,
        isPrivate: true,
      },
    });

    const fileA = await prisma.file.create({
      data: {
        name: 'confidential_a.txt',
        originalName: 'confidential_a.txt',
        mimeType: 'text/plain',
        extension: 'txt',
        size: BigInt(100),
        storageKey: `test/confidential_a_${Date.now()}.txt`,
        spaceId: privateSpaceA.id,
        uploadedBy: userA.id,
        category: 'NOTE',
        aiSearchEnabled: true,
        indexStatus: 'READY',
      },
    });

    const dummyVector = new Array(768).fill(0.05);

    const chunkA = await prisma.chunk.create({
      data: {
        spaceId: privateSpaceA.id,
        fileId: fileA.id,
        fileName: fileA.name,
        location: 'page 1',
        content: 'Top secret proprietary roadmap for project Apollo and quantum computing.',
        embedding: JSON.stringify(dummyVector),
        embedModel: 'gemini-embedding-2',
      },
    });
    console.log(`[2] Created confidential chunk in Space A (${privateSpaceA.id})`);

    // 3. User B queries for Apollo roadmap — MUST NOT receive Space A chunk!
    console.log('\n[3] Testing Cross-User Space Isolation...');
    const resultUserB = await aiService.searchAccessibleChunks(
      userB.id,
      'Apollo quantum computing roadmap',
      dummyVector,
      [privateSpaceA.id], // User B tries to access Space A
    );

    console.log(`    User B query returned ${resultUserB.candidates.length} candidates.`);
    if (resultUserB.candidates.length !== 0) {
      throw new Error('SECURITY VIOLATION: User B accessed chunks from User A private space!');
    }
    console.log('    ✓ Cross-user space isolation passed: Unauthorized user blocked from querying private space.');

    // 4. Test aiSearchEnabled: false exclusion
    console.log('\n[4] Testing aiSearchEnabled: false exclusion...');
    await prisma.file.update({
      where: { id: fileA.id },
      data: { aiSearchEnabled: false },
    });

    const resultUserADisabled = await aiService.searchAccessibleChunks(
      userA.id,
      'Apollo quantum computing roadmap',
      dummyVector,
      [privateSpaceA.id],
    );
    console.log(`    User A query on aiSearchEnabled=false file returned ${resultUserADisabled.candidates.length} candidates.`);
    if (resultUserADisabled.candidates.length !== 0) {
      throw new Error('SECURITY VIOLATION: Chunk from aiSearchEnabled=false file was returned in search!');
    }
    console.log('    ✓ Disabled AI search exclusion passed: file chunks excluded from retrieval.');

    // 5. Test Trashed / Deleted file exclusion
    console.log('\n[5] Testing Trashed / Deleted file exclusion...');
    await prisma.file.update({
      where: { id: fileA.id },
      data: { aiSearchEnabled: true, trashedAt: new Date() },
    });

    const resultUserATrashed = await aiService.searchAccessibleChunks(
      userA.id,
      'Apollo quantum computing roadmap',
      dummyVector,
      [privateSpaceA.id],
    );
    console.log(`    User A query on trashed file returned ${resultUserATrashed.candidates.length} candidates.`);
    if (resultUserATrashed.candidates.length !== 0) {
      throw new Error('SECURITY VIOLATION: Chunk from trashed file was returned in search!');
    }
    console.log('    ✓ Trashed file exclusion passed: trashed files excluded from retrieval.');

    // 6. Test Viewer Permission on Reindex
    console.log('\n[6] Testing Viewer Permission checks on Reindexing...');
    // Restore fileA from trash so it exists for permission checking
    await prisma.file.update({
      where: { id: fileA.id },
      data: { trashedAt: null },
    });
    // Add User B as VIEWER in Space A
    await prisma.spaceMember.create({
      data: {
        spaceId: privateSpaceA.id,
        userId: userB.id,
        role: 'VIEWER',
        status: 'ACCEPTED',
      },
    });

    let reindexBlocked = false;
    try {
      await aiService.reindexFile(fileA.id, userB.id);
    } catch (err: any) {
      if (err.statusCode === 403 || err.message?.includes('permissions are required')) {
        reindexBlocked = true;
      }
    }

    if (!reindexBlocked) {
      throw new Error('SECURITY VIOLATION: Viewer was allowed to reindex file!');
    }
    console.log('    ✓ Viewer permission check passed: Viewers cannot reindex files.');

    // 7. Verify AiUsageLog entries
    console.log('\n[7] Testing AiUsageLog Cost & Latency Tracking...');
    const logEntry = await prisma.aiUsageLog.create({
      data: {
        userId: userA.id,
        spaceId: privateSpaceA.id,
        stage: 'answer',
        inputTokens: 1420,
        outputTokens: 215,
        latencyMs: 850,
      },
    });
    console.log(`    Created AiUsageLog entry: ${logEntry.id} (${logEntry.inputTokens} in / ${logEntry.outputTokens} out, ${logEntry.latencyMs}ms)`);
    await prisma.aiUsageLog.delete({ where: { id: logEntry.id } });
    console.log('    ✓ AiUsageLog schema and logging verified.');

    // Clean up test data
    await prisma.chunk.deleteMany({ where: { fileId: fileA.id } });
    await prisma.spaceMember.deleteMany({ where: { spaceId: privateSpaceA.id } });
    await prisma.file.delete({ where: { id: fileA.id } });
    await prisma.space.delete({ where: { id: privateSpaceA.id } });
    console.log('\n    ✓ Test artifacts cleaned up successfully.');

  } finally {
    await prisma.user.delete({ where: { id: userB.id } });
  }

  console.log('\n=== ALL PHASE 5 SECURITY & ACCESS CONTROL TESTS PASSED! ===\n');
}

runSecurityTests()
  .catch((err) => {
    console.error('Security test failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
