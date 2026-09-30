import { z } from 'zod';

export const createSpaceSchema = z.object({
  name: z.string().min(1, 'Space name is required').max(100).trim(),
  description: z.string().max(500).optional(),
  icon: z.string().default('📁'),
  color: z.string().regex(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, 'Invalid hex color').default('#6366F1'),
  coverUrl: z.string().url().optional().or(z.literal('')),
  isPrivate: z.boolean().default(true),
});

export const updateSpaceSchema = z.object({
  name: z.string().min(1).max(100).trim().optional(),
  description: z.string().max(500).optional(),
  icon: z.string().optional(),
  color: z.string().regex(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, 'Invalid hex color').optional(),
  coverUrl: z.string().url().optional().or(z.literal('')),
  isPrivate: z.boolean().optional(),
});

export const spaceQuerySchema = z.object({
  page: z.coerce.number().min(1).default(1),
  limit: z.coerce.number().min(1).max(100).default(20),
  search: z.string().optional(),
  sortBy: z.enum(['name', 'createdAt', 'updatedAt', 'lastActivityAt', 'fileCount', 'totalSize']).default('lastActivityAt'),
  order: z.enum(['asc', 'desc']).default('desc'),
});

export const addSpaceMemberSchema = z.object({
  email: z.string().email(),
  role: z.enum(['VIEWER', 'EDITOR', 'ADMIN']).default('VIEWER'),
});

export type CreateSpaceInput = z.infer<typeof createSpaceSchema>;
export type UpdateSpaceInput = z.infer<typeof updateSpaceSchema>;
export type SpaceQueryInput = z.infer<typeof spaceQuerySchema>;
export type AddSpaceMemberInput = z.infer<typeof addSpaceMemberSchema>;
