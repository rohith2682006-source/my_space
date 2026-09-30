/**
 * job.worker.ts
 * Background job runner — polls the `jobs` table every 10 s and dispatches work.
 *
 * Supported job types:
 *   DOCUMENT_INDEX  — forward file to Python AI service for chunking + embedding
 *   AI_CLEANUP      — delete file_chunks after AI Search is disabled
 */

import { prisma } from '../config/database';
import { storage } from '../services/storage';
import { env } from '../config/env';
import { basename } from 'path';

const POLL_INTERVAL_MS = 10_000;
const MAX_CONCURRENT = 3;
const MAX_ATTEMPTS = 3;
const BACKOFF_BASE_MS = 5_000; // 5 s → 10 s → 20 s

let _running = false;
let _activeCount = 0;

// ─── DB helpers ───────────────────────────────────────────────────────────────

async function claimJob() {
  return prisma.$transaction(async (tx) => {
    const job = await tx.job.findFirst({
      where: {
        status: 'QUEUED',
        attempts: { lt: MAX_ATTEMPTS },
        scheduledAt: { lte: new Date() },
      },
      orderBy: { scheduledAt: 'asc' },
    });
    if (!job) return null;
    return tx.job.update({
      where: { id: job.id },
      data: { status: 'PROCESSING', startedAt: new Date(), attempts: { increment: 1 } },
    });
  });
}

async function markDone(jobId: string, result: object) {
  await prisma.job.update({
    where: { id: jobId },
    data: { status: 'COMPLETED', completedAt: new Date(), result: JSON.stringify(result) },
  });
}

async function markFailed(jobId: string, error: string, attempts: number) {
  const hasRetriesLeft = attempts < MAX_ATTEMPTS;
  const backoffMs = BACKOFF_BASE_MS * Math.pow(2, attempts - 1);
  await prisma.job.update({
    where: { id: jobId },
    data: {
      status: hasRetriesLeft ? 'QUEUED' : 'FAILED',
      error,
      scheduledAt: hasRetriesLeft ? new Date(Date.now() + backoffMs) : undefined,
    },
  });
}

// ─── Handlers ────────────────────────────────────────────────────────────────

interface DocumentIndexPayload {
  fileId: string;
  fileName: string;
  fileExtension: string;
  storageKey: string;
  spaceId: string;
  ownerId: string;
  isNote?: boolean;
  noteContent?: string;
}

async function handleDocumentIndex(p: DocumentIndexPayload): Promise<void> {
  await prisma.file.update({
    where: { id: p.fileId },
    data: { indexStatus: 'INDEXING', indexError: null },
  });

  let content: Buffer;
  if (p.isNote && p.noteContent) {
    content = Buffer.from(p.noteContent, 'utf-8');
  } else {
    content = await storage.download(p.storageKey);
  }

  if (!env.AI_SERVICE_TOKEN) {
    await prisma.file.update({
      where: { id: p.fileId },
      data: { indexStatus: 'FAILED', indexError: 'AI service token not configured.' },
    });
    throw new Error('AI_SERVICE_TOKEN not set');
  }

  const aiUrl = env.AI_SERVICE_URL || 'http://127.0.0.1:8000';
  const form = new FormData();
  form.set('file_id', p.fileId);
  form.set('space_id', p.spaceId);
  form.set('owner_id', p.ownerId);
  form.set('file_name', basename(p.fileName));
  form.set('file_type', p.fileExtension.replace(/^\./, ''));
  form.set(
    'file',
    new Blob([new Uint8Array(content)], { type: 'application/octet-stream' }),
    basename(p.fileName),
  );

  const res = await fetch(`${aiUrl}/documents/index`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.AI_SERVICE_TOKEN}` },
    body: form,
    signal: AbortSignal.timeout(120_000),
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { detail?: string };
    throw new Error(body.detail ?? `AI service HTTP ${res.status}`);
  }
}

interface AiCleanupPayload {
  fileId: string;
}

async function handleAiCleanup(p: AiCleanupPayload): Promise<void> {
  await prisma.fileChunk.deleteMany({ where: { fileId: p.fileId } });
  await prisma.file.updateMany({
    where: { id: p.fileId },
    data: { indexStatus: 'NOT_INDEXED', indexError: null },
  });
}

// ─── Dispatcher ───────────────────────────────────────────────────────────────

async function processJob(job: { id: string; type: string; payload: string; attempts: number }): Promise<void> {
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(job.payload) as Record<string, unknown>;
  } catch {
    await markFailed(job.id, 'Invalid JSON payload', job.attempts);
    return;
  }

  try {
    switch (job.type) {
      case 'DOCUMENT_INDEX':
        await handleDocumentIndex(payload as unknown as DocumentIndexPayload);
        await markDone(job.id, { message: 'Indexing dispatched to AI service' });
        break;
      case 'AI_CLEANUP':
        await handleAiCleanup(payload as unknown as AiCleanupPayload);
        await markDone(job.id, { message: 'AI chunks deleted' });
        break;
      default:
        await markFailed(job.id, `Unknown job type: ${job.type}`, MAX_ATTEMPTS);
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[JobWorker] Job ${job.id} (${job.type}) failed: ${msg}`);
    await markFailed(job.id, msg, job.attempts);
  }
}

// ─── Poll loop ────────────────────────────────────────────────────────────────

async function tick(): Promise<void> {
  while (_running && _activeCount < MAX_CONCURRENT) {
    const job = await claimJob();
    if (!job) break;
    _activeCount++;
    processJob(job).finally(() => { _activeCount--; });
  }
}

export function startJobWorker(): void {
  if (_running) return;
  _running = true;
  console.log('⚙️  [JobWorker] Background job worker started (poll every 10 s)');
  const loop = setInterval(async () => {
    try { await tick(); } catch (err) { console.error('[JobWorker] Tick error:', err); }
  }, POLL_INTERVAL_MS);
  loop.unref();
}

export function stopJobWorker(): void {
  _running = false;
}

// ─── Public: enqueue ─────────────────────────────────────────────────────────

export async function enqueueJob(
  type: 'DOCUMENT_INDEX' | 'AI_CLEANUP',
  payload: object,
  scheduledAt?: Date,
): Promise<string> {
  const job = await prisma.job.create({
    data: {
      type,
      status: 'QUEUED',
      payload: JSON.stringify(payload),
      scheduledAt: scheduledAt ?? new Date(),
      maxAttempts: MAX_ATTEMPTS,
    },
  });
  return job.id;
}

