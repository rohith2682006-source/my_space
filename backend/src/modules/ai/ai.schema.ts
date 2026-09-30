import { z } from 'zod';

export const chatSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  history: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant']),
        content: z.string().trim().min(1).max(4000),
      })
    )
    .max(12)
    .default([]),
});

export type ChatInput = z.infer<typeof chatSchema>;

export const deepSearchSchema = chatSchema.extend({
  spaceIds: z.array(z.string().uuid()).max(50).default([]),
});
export type DeepSearchInput = z.infer<typeof deepSearchSchema>;

export const quickSearchSchema = z.object({
  query: z.string().trim().min(1).max(500),
  spaceIds: z.array(z.string().uuid()).max(50).default([]),
});
export type QuickSearchInput = z.infer<typeof quickSearchSchema>;

export const indexCallbackSchema = z.object({
  fileId: z.string().uuid(),
  status: z.enum(['INDEXING', 'READY', 'FAILED', 'OCR_REQUIRED']),
  error: z.string().max(500).nullable().optional(),
  chunks: z.array(z.object({
    id: z.string().uuid(),
    fileId: z.string().uuid(),
    spaceId: z.string().uuid(),
    ownerId: z.string().uuid(),
    content: z.string().min(1).max(3200),
    embedding: z.array(z.number().finite()).min(1).max(8192),
    metadata: z.record(z.string(), z.string()),
    pageNumber: z.number().int().positive().nullable().optional(),
    chunkIndex: z.number().int().nonnegative(),
  })).max(500).default([]),
});

export const documentIdSchema = z.object({
  id: z.string().uuid(),
});

export const reindexExistingSchema = z.object({
  excludeFileIds: z.array(z.string().uuid()).max(500).default([]),
});
export type IndexCallbackInput = z.infer<typeof indexCallbackSchema>;