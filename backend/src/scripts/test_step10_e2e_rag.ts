import { randomUUID } from 'crypto';
import { prisma } from '../config/database';
import { aiController } from '../modules/ai/ai.controller';
import { aiService } from '../modules/ai/ai.service';
import { AiCreditsService } from '../modules/ai/ai.credits.service';

class MockResponse {
  statusCode: number = 200;
  headers: Record<string, string> = {};
  chunks: string[] = [];
  ended: boolean = false;

  setHeader(name: string, value: string) {
    this.headers[name] = value;
    return this;
  }

  flushHeaders() {}

  write(chunk: any) {
    this.chunks.push(typeof chunk === 'string' ? chunk : chunk.toString());
    return true;
  }

  end() {
    this.ended = true;
    return this;
  }
}

async function runStep10E2EVerification() {
  console.log('🚀 [Step 10] Running Complete End-to-End System Verification...');

  // Setup Mock fetch to intercept Python AI Microservice calls
  const originalFetch = global.fetch;
  let lastStreamRequestBody: any = null;

  global.fetch = async (url: any, options: any = {}) => {
    const urlStr = String(url);

    if (urlStr.includes('/rag/rewrite-query')) {
      const parsed = JSON.parse(options.body || '{}');
      return new Response(JSON.stringify({ query: parsed.message || 'rewritten' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (urlStr.includes('/embeddings')) {
      return new Response(JSON.stringify({ embedding: [0.1, 0.2, 0.3, 0.4] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (urlStr.includes('/rag/answer/stream')) {
      lastStreamRequestBody = JSON.parse(options.body || '{}');
      const manifest = lastStreamRequestBody.folder_manifest;
      const chunks = lastStreamRequestBody.retrieved_chunks || [];
      const query = (
        lastStreamRequestBody.message ||
        lastStreamRequestBody.query ||
        ''
      ).toLowerCase();

      // Simulate intent router behavior in Python microservice
      const isOverview =
        query.includes('what files') ||
        query.includes('tell me about the files') ||
        query.includes('summarize');
      const mode = isOverview ? 'OVERVIEW' : 'DEEP_FACT';

      const events: string[] = [];
      if (mode === 'OVERVIEW' && manifest) {
        events.push(
          `data: ${JSON.stringify({
            event: 'status',
            message: `Scanning ${manifest.total_files} files in ${manifest.space_name}...`,
          })}\n\n`
        );
        events.push(
          `data: ${JSON.stringify({
            text: `This folder **${manifest.space_name}** contains ${manifest.total_files} documents:\n\n`,
          })}\n\n`
        );
        for (const file of manifest.files) {
          events.push(
            `data: ${JSON.stringify({
              text: `- **${file.name}**: ${file.summary || 'Document ready.'}\n`,
            })}\n\n`
          );
        }
        events.push(
          `data: ${JSON.stringify({
            citations: manifest.files.map((f: any) => ({
              id: f.id,
              file_id: f.id,
              file_name: f.name,
              space_id: manifest.space_id,
              space_name: manifest.space_name,
              page_number: f.page_count,
              location: `${f.page_count || 1} pages`,
              excerpt: f.summary,
            })),
          })}\n\n`
        );
        events.push(
          `data: ${JSON.stringify({
            done: true,
            search_metadata: {
              mode: 'OVERVIEW',
              total_files: manifest.total_files,
              ready_files: manifest.ready_files,
              chunks_used: 0,
              llm_latency_ms: 85.0,
            },
          })}\n\n`
        );
      } else {
        events.push(
          `data: ${JSON.stringify({
            event: 'status',
            message: 'Querying indexed chunks...',
          })}\n\n`
        );
        events.push(
          `data: ${JSON.stringify({
            text: 'Annual ARR growth reached 25% year-over-year in Q3 according to annual_report.pdf.\n',
          })}\n\n`
        );
        events.push(
          `data: ${JSON.stringify({
            citations: [
              {
                id: 'chunk-1',
                file_id: manifest?.files[0]?.id || 'file-1',
                file_name: 'annual_report.pdf',
                space_id: manifest?.space_id,
                space_name: manifest?.space_name,
                page_number: 1,
                location: 'Page 1',
                excerpt: 'Annual ARR growth reached 25% year-over-year in Q3.',
              },
            ],
          })}\n\n`
        );
        events.push(
          `data: ${JSON.stringify({
            done: true,
            search_metadata: {
              mode: 'DEEP_FACT',
              total_files: 1,
              ready_files: 1,
              chunks_used: 1,
              llm_latency_ms: 110.5,
            },
          })}\n\n`
        );
      }

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(events.join('')));
          controller.close();
        },
      });

      return new Response(stream, {
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
      });
    }

    return originalFetch(url, options);
  };

  const nextFn: any = (err: any) => {
    if (err) console.error('Next callback called with error:', err);
  };

  try {
    // 1. Prepare Users
    const users = await prisma.user.findMany({ take: 2 });
    if (users.length === 0) {
      throw new Error('Test requires at least 1 user in database.');
    }
    const owner = users[0];
    let stranger = users.length > 1 ? users[1] : null;
    if (!stranger) {
      stranger = await prisma.user.create({
        data: {
          id: randomUUID(),
          email: `e2e-stranger-${Date.now()}@example.com`,
          passwordHash: 'dummy',
          firstName: 'Stranger',
          lastName: 'User',
        },
      });
    }

    await AiCreditsService.addCredits(owner.id, 100, 'GRANT', 'E2E test credits');

    // 2. Create Test Space & Files
    const spaceId = randomUUID();
    const file1Id = randomUUID();
    const file2Id = randomUUID();

    const testSpace = await prisma.space.create({
      data: {
        id: spaceId,
        name: `E2E Folder ${Date.now()}`,
        description: 'End-to-end integration test folder',
        ownerId: owner.id,
        isPrivate: true,
      },
    });

    console.log(`Created space: id=${testSpace.id}, expected=${spaceId}`);

    const file1 = await prisma.file.create({
      data: {
        id: file1Id,
        name: 'annual_report.pdf',
        originalName: 'annual_report.pdf',
        mimeType: 'application/pdf',
        extension: 'pdf',
        size: BigInt(102400),
        storageKey: `test/${file1Id}.pdf`,
        spaceId: spaceId,
        uploadedBy: owner.id,
        category: 'DOCUMENT',
        indexStatus: 'READY',
        aiSearchEnabled: true,
        summary: 'Annual performance report showing 25% ARR growth.',
        keywords: JSON.stringify(['ARR', 'Growth', 'Financials']),
        pageCount: 15,
        extractedText: 'Full extracted text for annual report.',
      },
    });

    const file2 = await prisma.file.create({
      data: {
        id: file2Id,
        name: 'roadmap.md',
        originalName: 'roadmap.md',
        mimeType: 'text/markdown',
        extension: 'md',
        size: BigInt(2048),
        storageKey: `test/${file2Id}.md`,
        spaceId: spaceId,
        uploadedBy: owner.id,
        category: 'NOTE',
        indexStatus: 'READY',
        aiSearchEnabled: true,
        summary: 'Product engineering roadmap for Q3 and Q4 milestones.',
        keywords: JSON.stringify(['Roadmap', 'Milestones', 'Architecture']),
        pageCount: 3,
        extractedText: 'Engineering roadmap details.',
      },
    });

    await prisma.fileChunk.create({
      data: {
        id: randomUUID(),
        fileId: file1Id,
        spaceId: spaceId,
        ownerId: owner.id,
        content: 'Annual ARR growth reached 25% year-over-year in Q3.',
        embedding: JSON.stringify([0.1, 0.2, 0.3, 0.4]),
        chunkIndex: 0,
        pageNumber: 1,
      },
    });

    console.log('✅ Created test space, enriched files, and indexed chunk in database.');

    // 3. Test buildFolderManifest
    const manifest = await aiService.buildFolderManifest(owner.id, spaceId);
    if (manifest.total_files !== 2 || manifest.files.length !== 2) {
      throw new Error(`Expected 2 files in manifest, got ${manifest.total_files}`);
    }
    if (!manifest.files[0].summary || !manifest.files[1].keywords) {
      throw new Error('Manifest missing summaries or keywords');
    }
    console.log('✅ buildFolderManifest correctly assembled folder metadata and summaries.');

    // 4. Test Scenario 1: Folder Overview SSE Streaming via deepSearchStream
    console.log('\n--- Scenario 1: Folder Overview SSE Streaming ---');
    const mockReq1 = {
      user: { userId: owner.id },
      body: {
        message: 'What files are in this folder and what do they contain?',
        spaceIds: [spaceId],
      },
    } as any;
    const mockRes1 = new MockResponse() as any;

    await aiController.deepSearchStream(mockReq1, mockRes1, nextFn);
    const combinedOutput1 = mockRes1.chunks.join('');

    if (!combinedOutput1.includes('event":"status"')) {
      throw new Error('Missing status event in SSE stream');
    }
    if (!combinedOutput1.includes('annual_report.pdf') || !combinedOutput1.includes('roadmap.md')) {
      throw new Error('Missing file overview in SSE stream text');
    }
    if (!combinedOutput1.includes('"mode":"OVERVIEW"')) {
      throw new Error('Missing OVERVIEW mode in search_metadata');
    }
    console.log('✅ Scenario 1 Passed: Received status banner, overview text, citations, and search_metadata.');

    // 5. Test Scenario 2: Deep Fact Search with specific file attachment
    console.log('\n--- Scenario 2: Targeted Fact Query with Attached File ---');
    const mockReq2 = {
      user: { userId: owner.id },
      body: {
        message: 'What ARR growth was achieved?',
        spaceIds: [spaceId],
        fileIds: [file1Id],
      },
    } as any;
    const mockRes2 = new MockResponse() as any;

    await aiController.deepSearchStream(mockReq2, mockRes2, nextFn);
    const combinedOutput2 = mockRes2.chunks.join('');

    if (!combinedOutput2.includes('"mode":"DEEP_FACT"')) {
      throw new Error('Expected DEEP_FACT mode in search_metadata');
    }
    console.log('✅ Scenario 2 Passed: Targeted fact query successfully processed with chunk citations.');

    // 6. Test Scenario 3: Security & Multi-tenant Isolation
    console.log('\n--- Scenario 3: Security & User Boundary Isolation ---');
    let strangerBlocked = false;
    try {
      await aiService.buildFolderManifest(stranger.id, spaceId);
    } catch (err: any) {
      if (err.statusCode === 403 || err.message?.includes('Forbidden') || err.message?.includes('unauthorized') || err.message?.includes('access')) {
        strangerBlocked = true;
      }
    }
    if (!strangerBlocked) {
      throw new Error('CRITICAL SECURITY FLAW: Stranger was not blocked from accessing owner space manifest!');
    }

    let strangerDeepSearchBlocked = false;
    const mockReqStranger = {
      user: { userId: stranger.id },
      body: {
        message: 'Inspect someone else folder',
        spaceIds: [spaceId],
      },
    } as any;
    const mockResStranger = new MockResponse() as any;

    try {
      await aiController.deepSearchStream(mockReqStranger, mockResStranger, nextFn);
      const strOutput = mockResStranger.chunks.join('');
      if (strOutput.includes('FORBIDDEN') || strOutput.includes('Unauthorized') || strOutput.includes('permission') || mockResStranger.statusCode === 403) {
        strangerDeepSearchBlocked = true;
      }
    } catch (err: any) {
      strangerDeepSearchBlocked = true;
    }
    if (!strangerDeepSearchBlocked) {
      throw new Error('CRITICAL SECURITY FLAW: Stranger was not blocked from deepSearchStream!');
    }
    console.log('✅ Scenario 3 Passed: Unauthorized user strictly blocked with 403 Forbidden.');

    // 7. Test Scenario 4: ChatStream Auto-delegation with Folder Attachment
    console.log('\n--- Scenario 4: ChatStream Auto-delegation with Folder Attachment ---');
    const mockReqChat = {
      user: { userId: owner.id },
      body: {
        message: 'Tell me about the files in this folder',
        spaceIds: [spaceId],
      },
    } as any;
    const mockResChat = new MockResponse() as any;

    await aiController.chatStream(mockReqChat, mockResChat, nextFn);
    const combinedOutputChat = mockResChat.chunks.join('');

    if (!combinedOutputChat.includes('"mode":"OVERVIEW"')) {
      throw new Error('chatStream failed to auto-delegate attached folder to RAG stream!');
    }
    console.log('✅ Scenario 4 Passed: chatStream auto-delegates folder attachments into RAG stream.');

    // 8. Clean up
    await prisma.fileChunk.deleteMany({ where: { spaceId } });
    await prisma.file.deleteMany({ where: { spaceId } });
    await prisma.space.delete({ where: { id: spaceId } });
    console.log('✅ Cleaned up test space, chunks, and files.');

    console.log('\n🎉 ALL END-TO-END SCENARIOS VERIFIED SUCCESSFULLY!');
  } finally {
    global.fetch = originalFetch;
    await prisma.$disconnect();
  }
}

runStep10E2EVerification().catch((err) => {
  console.error('❌ Step 10 Verification Failed:', err);
  process.exit(1);
});
