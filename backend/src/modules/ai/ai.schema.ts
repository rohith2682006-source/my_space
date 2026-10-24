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
  imageBase64: z.string().optional(),
  imageMimeType: z.string().optional(),
  spaceIds: z.array(z.string().uuid()).max(50).default([]).optional(),
  fileId: z.string().uuid().optional(),
  fileIds: z.array(z.string().uuid()).max(100).default([]).optional(),
});

export type ChatInput = z.infer<typeof chatSchema>;

export const visionSchema = z.object({
  prompt: z.string().trim().max(4000).default('Analyze this image in detail and describe what you see, including key objects, scene details, and any visible text.').optional(),
  imageBase64: z.string().min(1),
  imageMimeType: z.string().default('image/jpeg').optional(),
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

export type VisionInput = z.infer<typeof visionSchema>;

export const deepSearchSchema = chatSchema.extend({
  spaceIds: z.array(z.string().uuid()).max(50).default([]),
  fileId: z.string().uuid().optional(),
  fileIds: z.array(z.string().uuid()).max(100).default([]),
});
export type DeepSearchInput = z.infer<typeof deepSearchSchema>;

export const quickSearchSchema = z.object({
  query: z.string().trim().min(1).max(500),
  spaceIds: z.array(z.string().uuid()).max(50).default([]),
  fileId: z.string().uuid().optional(),
});
export type QuickSearchInput = z.infer<typeof quickSearchSchema>;

export const indexCallbackSchema = z.object({
  fileId: z.string().uuid(),
  status: z.enum([
    'UPLOADED',
    'EXTRACTING',
    'CHUNKING',
    'EMBEDDING',
    'SUMMARIZING',
    'READY',
    'FAILED',
    'OCR_REQUIRED',
    'INDEXING',
  ]),
  error: z.string().max(1000).nullable().optional(),
  summary: z.string().max(2000).nullable().optional(),
  keywords: z.array(z.string()).max(10).optional().default([]),
  pageCount: z.number().int().nonnegative().nullable().optional(),
  extractedText: z.string().nullable().optional(),
  chunks: z.array(z.object({
    id: z.string().uuid(),
    fileId: z.string().uuid(),
    spaceId: z.string().uuid(),
    ownerId: z.string().uuid(),
    content: z.string().min(1).max(12000),
    prefixedContent: z.string().nullable().optional(),
    location: z.string().nullable().optional(),
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
export type IndexCallbackInput = z.input<typeof indexCallbackSchema>;
export type IndexCallbackPayload = z.output<typeof indexCallbackSchema>;

export const feedbackSchema = z.object({
  spaceId: z.string().uuid(),
  question: z.string().trim().min(1).max(4000),
  answer: z.string().trim().min(1).max(10000),
  rating: z.enum(['THUMBS_UP', 'THUMBS_DOWN']),
  chunkIds: z.array(z.string()).default([]),
});
export type FeedbackInput = z.infer<typeof feedbackSchema>;