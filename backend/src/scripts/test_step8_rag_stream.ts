import { randomUUID } from 'crypto';
import { prisma } from '../config/database';
import { aiController } from '../modules/ai/ai.controller';
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

async function testStep8RagStream() {
  console.log('🧪 [Step 8 Test] Verifying Backend RAG Stream Controller Integration...');

  // Setup Mock fetch for external Python AI Microservice calls
  const originalFetch = global.fetch;
  let lastStreamRequestBody: any = null;

  global.fetch = async (url: any, options: any = {}) => {
    const urlStr = String(url);

    if (urlStr.includes('/rag/rewrite-query')) {
      const parsed = JSON.parse(options.body || '{}');
      return new Response(JSON.stringify({ query: parsed.message || 'rewritten query' }), {
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

      // Simulate streaming SSE events from Python AI service
      const ssePayload = [
        `data: ${JSON.stringify({ event: 'status', message: `Scanning ${lastStreamRequestBody.folder_manifest?.total_files || 0} files in ${lastStreamRequestBody.folder_manifest?.space_name || 'folder'} folder...` })}\n\n`,
        `data: ${JSON.stringify({ text: 'In the **Q3 Financial Review** folder, ' })}\n\n`,
        `data: ${JSON.stringify({ text: 'we have financial documents detailing revenue and expenses.' })}\n\n`,
        `data: ${JSON.stringify({
          citations: [
            {
              id: 'file-1',
              file_id: 'test-file-1',
              file_name: 'q3_revenue.pdf',
              space_id: lastStreamRequestBody.folder_manifest?.space_id,
              space_name: 'Q3 Financial Review',
              page_number: 8,
              location: '8 pages',
              excerpt: 'Q3 revenue rose by 18% to $4.2M led by software subscriptions.',
            },
          ],
        })}\n\n`,
        `data: ${JSON.stringify({
          done: true,
          search_metadata: {
            mode: 'OVERVIEW',
            total_files: lastStreamRequestBody.folder_manifest?.total_files || 0,
            ready_files: lastStreamRequestBody.folder_manifest?.ready_files || 0,
            chunks_used: 0,
            llm_latency_ms: 125.4,
          },
        })}\n\n`,
      ].join('');

      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(ssePayload));
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

  try {
    // 1. Get or create test users
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
          email: `stranger-${Date.now()}@example.com`,
          passwordHash: 'dummyhash',
          firstName: 'Stranger',
          lastName: 'User',
        },
      });
    }

    // Ensure owner has credits
    await AiCreditsService.addCredits(owner.id, 50, 'GRANT', 'Test setup credits');

    // 2. Create private space
    const spaceId = randomUUID();
    console.log(`📁 Creating test space: ${spaceId} for owner: ${owner.email}`);
    await prisma.space.create({
      data: {
        id: spaceId,
        name: 'Q3 Financial Review',
        description: 'Folder containing corporate Q3 finance reports',
        isPrivate: true,
        ownerId: owner.id,
      },
    });

    const file1Id = randomUUID();
    const file2Id = randomUUID();

    try {
      // 3. Create test files: 1 READY with summary & keywords, 1 INDEXING
      await prisma.file.create({
        data: {
          id: file1Id,
          name: 'q3_revenue.pdf',
          originalName: 'q3_revenue.pdf',
          mimeType: 'application/pdf',
          extension: 'pdf',
          size: BigInt(2048576),
          storageKey: `test/${file1Id}.pdf`,
          spaceId: spaceId,
          uploadedBy: owner.id,
          category: 'DOCUMENT',
          indexStatus: 'READY',
          aiSearchEnabled: true,
          summary: 'Q3 revenue rose by 18% to $4.2M led by software subscriptions.',
          keywords: JSON.stringify(['revenue', 'q3', 'finance', 'growth']),
          pageCount: 8,
        },
      });

      await prisma.file.create({
        data: {
          id: file2Id,
          name: 'expense_breakdown.xlsx',
          originalName: 'expense_breakdown.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          extension: 'xlsx',
          size: BigInt(512000),
          storageKey: `test/${file2Id}.xlsx`,
          spaceId: spaceId,
          uploadedBy: owner.id,
          category: 'DOCUMENT',
          indexStatus: 'INDEXING',
          aiSearchEnabled: true,
        },
      });

      console.log('✅ Created 2 test files (1 READY, 1 INDEXING)');

      // 4. Test Authorized deepSearchStream (Overview Query)
      console.log('\n--- Test 4A: Authorized Folder Overview Streaming ---');
      const mockRes = new MockResponse();
      const mockReq: any = {
        user: { userId: owner.id },
        body: {
          message: 'tell me about the files in this folder',
          history: [],
          spaceIds: [spaceId],
        },
      };

      const nextFn: any = (err: any) => {
        if (err) console.error('Next called with error:', err);
      };

      await aiController.deepSearchStream(mockReq, mockRes as any, nextFn);

      const fullOutput = mockRes.chunks.join('');
      console.log(`Stream ended: ${mockRes.ended}`);
      console.log(`Received SSE chunks count: ${mockRes.chunks.length}`);

      // Verify request to AI service had folder_manifest properly populated
      if (!lastStreamRequestBody?.folder_manifest) {
        throw new Error('folder_manifest was not sent to /rag/answer/stream');
      }
      console.log('✅ folder_manifest correctly constructed:', {
        space_name: lastStreamRequestBody.folder_manifest.space_name,
        total_files: lastStreamRequestBody.folder_manifest.total_files,
        ready_files: lastStreamRequestBody.folder_manifest.ready_files,
        indexing_files: lastStreamRequestBody.folder_manifest.indexing_files,
      });

      if (lastStreamRequestBody.folder_manifest.total_files !== 2) {
        throw new Error(`Expected 2 files in manifest, got: ${lastStreamRequestBody.folder_manifest.total_files}`);
      }

      // Parse data events
      const lines = fullOutput.split('\n').filter((l) => l.startsWith('data: '));
      const events = lines.map((l) => JSON.parse(l.replace('data: ', '')));

      console.log(`Total SSE Data Events parsed: ${events.length}`);

      // Check Event 1: Status notification
      const statusEvent = events.find((e) => e.event === 'status');
      if (!statusEvent) {
        throw new Error('Expected status event was not received');
      }
      console.log(`✅ Status Event received: "${statusEvent.message}"`);
      if (!statusEvent.message.includes('Q3 Financial Review')) {
        throw new Error(`Status message did not include space name: ${statusEvent.message}`);
      }

      // Check Event 2: Tokens streamed
      const textEvents = events.filter((e) => 'text' in e);
      if (textEvents.length === 0) {
        throw new Error('Expected text tokens were not streamed');
      }
      const fullText = textEvents.map((e) => e.text).join('');
      console.log(`✅ Text stream received (${textEvents.length} tokens): "${fullText}"`);

      // Check Event 3: Citations
      const citationsEvent = events.find((e) => 'citations' in e);
      if (!citationsEvent) {
        throw new Error('Expected citations event was not received');
      }
      console.log(`✅ Citations event received: ${citationsEvent.citations.length} files cited`);
      if (citationsEvent.citations.length === 0 || citationsEvent.citations[0].file_name !== 'q3_revenue.pdf') {
        throw new Error(`Expected q3_revenue.pdf in citations, got: ${JSON.stringify(citationsEvent.citations)}`);
      }

      // Check Event 4: Done Event with Search Metadata
      const doneEvent = events.find((e) => e.done === true && e.search_metadata);
      if (!doneEvent) {
        throw new Error('Expected done event with search_metadata was not received');
      }
      console.log(`✅ Done event received with search_metadata:`, doneEvent.search_metadata);
      if (doneEvent.search_metadata.mode !== 'OVERVIEW') {
        throw new Error(`Expected mode OVERVIEW, got: ${doneEvent.search_metadata.mode}`);
      }

      // 5. Test Unauthorized Access (Security Boundary)
      console.log('\n--- Test 4B: Unauthorized Access Protection ---');
      const unauthorizedRes = new MockResponse();
      const unauthorizedReq: any = {
        user: { userId: stranger.id },
        body: {
          message: 'what is in this folder?',
          history: [],
          spaceIds: [spaceId],
        },
      };

      await aiController.deepSearchStream(unauthorizedReq, unauthorizedRes as any, nextFn);
      const unauthorizedOutput = unauthorizedRes.chunks.join('');
      console.log(`Unauthorized response output: ${unauthorizedOutput.trim()}`);
      if (!unauthorizedOutput.includes('permission') && !unauthorizedOutput.includes('Forbidden')) {
        throw new Error(`Expected permission denied for stranger, got: ${unauthorizedOutput}`);
      }
      console.log('✅ Security check passed: Unauthorized user blocked from streaming space content');

      // 6. Test chatStream delegation with space attachment
      console.log('\n--- Test 4C: chatStream Delegation with Attached Folder ---');
      const chatStreamRes = new MockResponse();
      const chatStreamReq: any = {
        user: { userId: owner.id },
        body: {
          message: 'list files in this space',
          history: [],
          spaceIds: [spaceId],
        },
      };

      await aiController.chatStream(chatStreamReq, chatStreamRes as any, nextFn);
      const chatStreamOutput = chatStreamRes.chunks.join('');
      if (!chatStreamOutput.includes('status') && !chatStreamOutput.includes('Q3 Financial Review')) {
        throw new Error('chatStream with attached space did not delegate to folder RAG stream');
      }
      console.log('✅ chatStream delegation passed: folder attachment automatically routed to RAG stream');

      console.log('\n🎉 [Step 8 Test Passed] All streaming endpoints, manifest builders, and security boundaries verified!');
    } finally {
      // Cleanup
      await prisma.file.deleteMany({ where: { spaceId } });
      await prisma.space.delete({ where: { id: spaceId } });
      console.log('🧹 Cleaned up test space and files.');
    }
  } finally {
    global.fetch = originalFetch;
  }
}

testStep8RagStream()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
  });
