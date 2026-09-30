import { z } from 'zod';

export const createShareLinkSchema = z.object({
  fileId: z.string().uuid().optional(),
  spaceId: z.string().uuid().optional(),
  permission: z.enum(['VIEW', 'EDIT', 'DOWNLOAD']).default('VIEW'),
  password: z.string().min(4).max(64).optional(),
  expiresInDays: z.number().int().min(1).max(365).optional(),
  maxDownloads: z.number().int().min(1).optional(),
}).refine((data) => data.fileId || data.spaceId, {
  message: 'Either fileId or spaceId must be provided',
});

export const accessShareLinkSchema = z.object({
  password: z.string().optional(),
});

export type CreateShareLinkInput = z.infer<typeof createShareLinkSchema>;
export type AccessShareLinkInput = z.infer<typeof accessShareLinkSchema>;
