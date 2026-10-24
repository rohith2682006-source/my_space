import { PrismaClient } from '@prisma/client';
import { aiService } from '../modules/ai/ai.service';
import { env } from '../config/env';

const prisma = new PrismaClient();

async function runTest() {
  console.log('=== PHASE 3: RAG QUESTION PIPELINE & SEARCH TEST ===\n');

  // 1. Verify User and Chunks exist
  const user = await prisma.user.findFirst();
  if (!user) {
    throw new Error('No user found in database');
  }
  const chunkCount = await prisma.chunk.count();
  console.log(`[1] Found user: ${user.email} (${user.id})`);
  console.log(`    Total chunks in database: ${chunkCount}`);

  const space = await prisma.space.findFirst({
    where: { ownerId: user.id, deletedAt: null },
  });
  if (!space) {
    throw new Error('No space found for user');
  }
  console.log(`    Using space: ${space.name} (${space.id})`);

  // 2. Test Query Rewriter
  console.log('\n[2] Testing Query Rewriter...');
  const followUpMessage = 'What about its price?';
  const history = [
    { role: 'user', content: 'Tell me about the iPhone 15 Pro features.' },
    { role: 'assistant', content: 'The iPhone 15 Pro features a titanium design, A17 Pro chip, and 48MP camera.' },
  ];
  const rewritten = await aiService.rewriteQuery(followUpMessage, history);
  console.log(`    Original query: "${followUpMessage}"`);
  console.log(`    Rewritten query: "${rewritten}"`);
  if (!rewritten || rewritten.length === 0) {
    throw new Error('Query rewriting returned empty string');
  }

  // 3. Test Query Embedding (gemini-embedding-2 / 768d)
  console.log('\n[3] Testing Query Embedding...');
  const query = 'artificial intelligence machine learning';
  const queryVector = await aiService.requestEmbedding(query);
  console.log(`    Embedding dimensions: ${queryVector.length}`);
  if (queryVector.length !== 768) {
    throw new Error(`Expected 768 dimensions, got ${queryVector.length}`);
  }

  // 4. Test Hybrid Search & RRF with relevant query
  console.log('\n[4] Testing Hybrid Search & RRF...');
  const searchResult = await aiService.searchAccessibleChunks(
    user.id,
    query,
    queryVector,
    [space.id],
  );
  console.log(`    Search returned ${searchResult.candidates.length} candidates`);
  if (searchResult.candidates.length > 0) {
    const top = searchResult.candidates[0];
    console.log(`    Top candidate: "${top.excerpt.slice(0, 80)}..." | Score: ${top.score.toFixed(4)} | File: ${top.fileName} (${top.location})`);
  }

  // 5. Test Distance Cutoff Fallback (unrelated nonsense query)
  console.log('\n[5] Testing Distance Cutoff Fallback for unrelated query...');
  const nonsenseQuery = 'xyz123987unobtainium_supercalifragilistic';
  const nonsenseVector = await aiService.requestEmbedding(nonsenseQuery);
  const cutoffResult = await aiService.searchAccessibleChunks(
    user.id,
    nonsenseQuery,
    nonsenseVector,
    [space.id],
  );
  console.log(`    Unrelated query candidates returned: ${cutoffResult.candidates.length}`);
  if (cutoffResult.candidates.length === 0) {
    console.log('    ✓ Distance cutoff successfully filtered out unrelated content (0 hallucinations allowed).');
  } else {
    console.log(`    Note: returned ${cutoffResult.candidates.length} candidates above threshold.`);
  }

  // 6. Test Query Cache & Space Invalidation
  console.log('\n[6] Testing SHA-256 Query Cache & Invalidation...');
  const cacheKey = aiService.makeCacheKey(space.id, undefined, 'cache test query');
  aiService.setQueryCache(cacheKey, { answer: 'cached answer', sources: [] });
  const retrieved = aiService.getQueryCache(cacheKey);
  if (!retrieved || retrieved.answer !== 'cached answer') {
    throw new Error('Query cache set/get failed');
  }
  console.log('    ✓ Query cache hit confirmed');
  aiService.invalidateSpaceCache(space.id);
  const afterInvalidate = aiService.getQueryCache(cacheKey);
  if (afterInvalidate !== null) {
    throw new Error('Space cache invalidation failed');
  }
  console.log('    ✓ Invalidate space cache confirmed');

  // 7. Test Streaming Generator from Python Service (/rag/answer/stream)
  console.log('\n[7] Testing Streaming Generator (/rag/answer/stream)...');
  const dummySources = [
    {
      chunkId: 'chunk-1',
      documentId: 'doc-1',
      fileId: 'file-1',
      spaceId: space.id,
      fileName: 'test_doc.txt',
      fileType: 'txt',
      spaceName: space.name,
      updatedAt: new Date().toISOString(),
      excerpt: 'Spaces is a smart workspace application with RAG intelligence and document management.',
      pageNumber: 1,
      location: 'page 1',
      chunkIndex: 0,
      score: 0.95,
    },
  ];


  const streamResponse = await fetch(`${env.AI_SERVICE_URL}/rag/answer/stream`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.AI_SERVICE_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: 'What is Spaces?',
      history: [],
      sources: dummySources,
    }),
  });

  if (!streamResponse.ok || !streamResponse.body) {
    throw new Error(`Streaming failed with status: ${streamResponse.status}`);
  }

  const reader = streamResponse.body.getReader();
  const decoder = new TextDecoder();
  let fullStreamText = '';
  let chunkCountSse = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const text = decoder.decode(value, { stream: true });
    fullStreamText += text;
    chunkCountSse++;
  }

  console.log(`    Received ${chunkCountSse} SSE stream packages.`);
  console.log(`    Stream sample: ${fullStreamText.slice(0, 180)}...`);

  // 8. Test Answer Feedback Persistence
  console.log('\n[8] Testing Answer Feedback Database Record...');
  const feedback = await prisma.answerFeedback.create({
    data: {
      userId: user.id,
      spaceId: space.id,
      question: 'What is Spaces?',
      answer: 'Spaces is a smart workspace application [1].',
      rating: 'THUMBS_UP',
      chunkIds: JSON.stringify(['chunk-1']),
    },
  });
  console.log(`    Created feedback record: ${feedback.id} (Rating: ${feedback.rating})`);
  await prisma.answerFeedback.delete({ where: { id: feedback.id } });
  console.log('    ✓ Feedback creation and cleanup verified');

  console.log('\n=== ALL PHASE 3 PIPELINE TESTS PASSED SUCCESSFULLY! ===\n');
}

runTest()
  .catch((err) => {
    console.error('Test failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
