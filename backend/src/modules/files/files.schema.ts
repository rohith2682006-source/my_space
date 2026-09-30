import { z } from 'zod';

export const fileQuerySchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(30),
  search: z.string().optional(),
  category: z.enum([
    'DOCUMENT',
    'IMAGE',
    'VIDEO',
    'AUDIO',
    'ARCHIVE',
    'CODE',
    'NOTE',
    'LINK',
    'OTHER',
  ]).optional(),
  sortBy: z.enum(['name', 'size', 'createdAt', 'updatedAt', 'openedAt']).default('createdAt'),
  order: z.enum(['asc', 'desc']).default('desc'),
});

export const renameFileSchema = z.object({
  name: z.string().min(1, 'Name is required').max(255).trim(),
});

export const moveFileSchema = z.object({
  targetSpaceId: z.string().uuid('Invalid Space ID'),
});

export const createNoteOrLinkSchema = z.object({
  name: z.string().min(1).max(255).trim(),
  type: z.enum(['NOTE', 'LINK']),
  content: z.string().min(1),
  spaceId: z.string().uuid(),
});

export const aiSearchAccessSchema = z.object({
  enabled: z.boolean(),
});

export type FileQueryInput = z.infer<typeof fileQuerySchema>;
export type RenameFileInput = z.infer<typeof renameFileSchema>;
export type MoveFileInput = z.infer<typeof moveFileSchema>;
export type CreateNoteOrLinkInput = z.infer<typeof createNoteOrLinkSchema>;
