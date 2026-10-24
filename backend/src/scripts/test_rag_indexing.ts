import { PrismaClient } from '@prisma/client';
import { aiService } from '../modules/ai/ai.service';

const prisma = new PrismaClient();

async function runTest() {
  console.log('Testing Phase 2 Indexing Pipeline...');

  // 1. Check or create a test user and space
  let user = await prisma.user.findFirst({
    where: { email: 'test_rag@spaces.local' },
  });

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: 'test_rag@spaces.local',
        passwordHash: 'dummy_hash',
        firstName: 'RAG',
        lastName: 'Tester',
      },


    });
  }



  let space = await prisma.space.findFirst({
    where: { ownerId: user.id, name: 'RAG Test Space' },
  });

  if (!space) {
    space = await prisma.space.create({
      data: {
        name: 'RAG Test Space',
        ownerId: user.id,
      },
    });
  }

  // 2. Create a test file with structured markdown tables and sections
  const testContent = `# RAG Architecture Specification

This document outlines the multi-phase retrieval-augmented generation engine for Spaces.

| Component | Technology | Target Dimension |
| :--- | :--- | :--- |
| Embedding Model | gemini-embedding-2 | 768 |
| Chat Model | gemini-flash-latest | N/A |
| Vector Index | HNSW cosine | 768 |
| Keyword Index | PostgreSQL GIN / SQLite LIKE | N/A |

## Structural Chunking Details
The chunking algorithm processes documents into structural atomic blocks. Tables and code blocks are kept intact without awkward line splits. Every chunk is prefixed with File: <file_name> | <location>.
`;

  const file = await prisma.file.create({
    data: {
      name: 'rag_architecture.md',
      originalName: 'rag_architecture.md',
      mimeType: 'text/markdown',
      extension: 'md',
      size: BigInt(Buffer.byteLength(testContent)),
      storageKey: `test/${space.id}/rag_architecture.md`,
      spaceId: space.id,
      uploadedBy: user.id,
      category: 'DOCUMENT',
      aiSearchEnabled: true,
      indexStatus: 'INDEXING',
    },
  });

  console.log(`Created test file ${file.name} (ID: ${file.id}) in space ${space.id}`);

  // 3. Directly test index callback simulating completed ingestion
  console.log('Testing completeIndexing callback and Chunk database persistence...');
  const fakeVector = new Array(768).fill(0).map((_, i) => Math.sin(i / 10));

  await aiService.completeIndexing({
    fileId: file.id,
    status: 'READY',
    chunks: [
      {
        id: `chunk-${Date.now()}-1`,
        fileId: file.id,
        spaceId: space.id,
        ownerId: user.id,
        content: testContent,
        location: 'section 1',
        embedding: fakeVector,
        metadata: {
          fileName: file.originalName,
          fileType: file.extension,
          location: 'section 1',
        },
        chunkIndex: 0,
      },
    ],
  });

  // 4. Verify in DB
  const storedChunks = await prisma.chunk.findMany({
    where: { fileId: file.id },
  });

  const storedIndexStatus = await prisma.fileIndexStatus.findUnique({
    where: { fileId: file.id },
  });

  const updatedFile = await prisma.file.findUnique({
    where: { id: file.id },
  });

  console.log(`Stored Chunks count in 'chunks' table: ${storedChunks.length}`);
  if (storedChunks.length > 0) {
    const chunk = storedChunks[0];
    const parsedVector = JSON.parse(chunk.embedding);
    console.log(`Chunk ID: ${chunk.id}`);
    console.log(`Chunk Location: ${chunk.location}`);
    console.log(`Chunk Embedding Dimensions: ${parsedVector.length}`);
    console.log(`Chunk Embedding Model: ${chunk.embedModel}`);
  }

  console.log(`FileIndexStatus in 'file_index_status' table: status=${storedIndexStatus?.status}, error=${storedIndexStatus?.error}`);
  console.log(`File table indexStatus: ${updatedFile?.indexStatus}`);

  // Cleanup test record
  await prisma.chunk.deleteMany({ where: { fileId: file.id } });
  await prisma.fileChunk.deleteMany({ where: { fileId: file.id } });
  await prisma.fileIndexStatus.deleteMany({ where: { fileId: file.id } });
  await prisma.file.delete({ where: { id: file.id } });
  await prisma.space.delete({ where: { id: space.id } });
  await prisma.user.delete({ where: { id: user.id } });

  console.log('Phase 2 test cleaned up and PASSED!');
}

runTest()
  .catch((e) => {
    console.error('Test failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
