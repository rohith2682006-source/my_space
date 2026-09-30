import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { prisma } from '../../config/database';
import { env } from '../../config/env';
import { storage } from '../../services/storage';
import {
  NotFoundError,
  ForbiddenError,
  UnauthorizedError,
} from '../../utils/errors';
import type {
  CreateShareLinkInput,
  AccessShareLinkInput,
} from './sharing.schema';

export class SharingService {
  /**
   * Create a secure share link for a file or space
   */
  async createShareLink(userId: string, input: CreateShareLinkInput) {
    // 1. Verify ownership/access of target resource
    if (input.fileId) {
      const file = await prisma.file.findFirst({
        where: { id: input.fileId, deletedAt: null },
      });
      if (!file) throw new NotFoundError('File not found');
    }

    if (input.spaceId) {
      const space = await prisma.space.findFirst({
        where: { id: input.spaceId, deletedAt: null },
      });
      if (!space) throw new NotFoundError('Space not found');
    }

    // 2. Generate secure token
    const token = crypto.randomBytes(24).toString('base64url');

    // 3. Hash password if provided
    let passwordHash: string | null = null;
    if (input.password) {
      passwordHash = await bcrypt.hash(input.password, env.BCRYPT_SALT_ROUNDS);
    }

    // 4. Calculate expiration
    let expiresAt: Date | null = null;
    if (input.expiresInDays) {
      expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + input.expiresInDays);
    }

    const shareLink = await prisma.shareLink.create({
      data: {
        token,
        fileId: input.fileId || null,
        spaceId: input.spaceId || null,
        createdBy: userId,
        permission: input.permission,
        password: passwordHash,
        expiresAt,
        maxDownloads: input.maxDownloads || null,
      },
    });

    // Log activity
    await prisma.activity.create({
      data: {
        userId,
        spaceId: input.spaceId || null,
        action: 'SHARE_LINK_CREATED',
        targetType: input.fileId ? 'file' : 'space',
        targetId: shareLink.id,
        metadata: JSON.stringify({ token: shareLink.token, permission: shareLink.permission }),
      },
    });

    const fullShareUrl = `${env.APP_URL}/share/${shareLink.token}`;
    const directDownloadUrl = shareLink.fileId
      ? `${env.APP_URL}/api/${env.API_VERSION}/share/${shareLink.token}/download`
      : null;

    return {
      id: shareLink.id,
      token: shareLink.token,
      permission: shareLink.permission,
      hasPassword: !!passwordHash,
      expiresAt: shareLink.expiresAt,
      maxDownloads: shareLink.maxDownloads,
      shareUrl: fullShareUrl,
      downloadUrl: directDownloadUrl,
      createdAt: shareLink.createdAt,
    };
  }

  /**
   * Access or resolve a share link by token
   */
  async resolveShareLink(token: string, input: AccessShareLinkInput) {
    const link = await prisma.shareLink.findUnique({
      where: { token },
      include: {
        file: {
          select: {
            id: true,
            name: true,
            size: true,
            mimeType: true,
            extension: true,
            category: true,
            createdAt: true,
          },
        },
        space: {
          select: {
            id: true,
            name: true,
            description: true,
            icon: true,
            color: true,
            fileCount: true,
          },
        },
        creator: {
          select: {
            firstName: true,
            lastName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!link || !link.isActive) {
      throw new NotFoundError('Share link is invalid or has been revoked');
    }

    // Check expiration
    if (link.expiresAt && link.expiresAt < new Date()) {
      throw new ForbiddenError('This share link has expired');
    }

    // Check download limit
    if (link.maxDownloads && link.downloadCount >= link.maxDownloads) {
      throw new ForbiddenError('Maximum download limit reached for this share link');
    }

    // Check password protection
    if (link.password) {
      if (!input.password) {
        return {
          requiresPassword: true,
          permission: link.permission,
          isProtected: true,
        };
      }

      const isValidPassword = await bcrypt.compare(input.password, link.password);
      if (!isValidPassword) {
        throw new UnauthorizedError('Incorrect password for this share link');
      }
    }

    const fullShareUrl = `${env.APP_URL}/share/${link.token}`;
    const directDownloadUrl = link.fileId
      ? `${env.APP_URL}/api/${env.API_VERSION}/share/${link.token}/download`
      : null;

    return {
      requiresPassword: false,
      permission: link.permission,
      file: link.file ? { ...link.file, size: link.file.size.toString() } : null,
      space: link.space,
      sharedBy: `${link.creator.firstName} ${link.creator.lastName}`,
      shareUrl: fullShareUrl,
      downloadUrl: directDownloadUrl,
      downloadCount: link.downloadCount,
      maxDownloads: link.maxDownloads,
      expiresAt: link.expiresAt,
    };
  }

  /**
   * Public download stream for a shared file
   */
  async getShareFileStream(token: string, password?: string) {
    const link = await prisma.shareLink.findUnique({
      where: { token },
      include: {
        file: true,
      },
    });

    if (!link || !link.isActive || !link.file) {
      throw new NotFoundError('Shared file link is invalid, expired, or does not exist');
    }

    if (link.expiresAt && link.expiresAt < new Date()) {
      throw new ForbiddenError('This share link has expired');
    }

    if (link.maxDownloads && link.downloadCount >= link.maxDownloads) {
      throw new ForbiddenError('Maximum download limit reached for this share link');
    }

    if (link.password) {
      if (!password) {
        throw new UnauthorizedError('Password required to download this shared file');
      }
      const isValidPassword = await bcrypt.compare(password, link.password);
      if (!isValidPassword) {
        throw new UnauthorizedError('Incorrect password for this share link');
      }
    }

    // Increment download count
    await prisma.shareLink.update({
      where: { id: link.id },
      data: { downloadCount: { increment: 1 } },
    });

    const stream = await storage.getStream(link.file.storageKey);
    return { stream, file: link.file };
  }

  /**
   * Get a share link with relations by token
   */
  async getShareLinkByToken(token: string) {
    return prisma.shareLink.findUnique({
      where: { token },
      include: {
        file: true,
        space: true,
      },
    });
  }

  /**
   * Get stats for a share link
   */
  async getShareLinkStats(linkId: string, userId: string) {
    const link = await prisma.shareLink.findUnique({
      where: { id: linkId },
      include: {
        file: {
          select: { id: true, name: true, size: true, mimeType: true },
        },
        space: {
          select: { id: true, name: true, icon: true },
        },
      },
    });

    if (!link) {
      throw new NotFoundError('Share link not found');
    }

    if (link.createdBy !== userId) {
      throw new ForbiddenError('Only the link creator can view its statistics');
    }

    return {
      id: link.id,
      token: link.token,
      shareUrl: `${env.APP_URL}/share/${link.token}`,
      downloadUrl: link.fileId ? `${env.APP_URL}/api/${env.API_VERSION}/share/${link.token}/download` : null,
      permission: link.permission,
      hasPassword: !!link.password,
      expiresAt: link.expiresAt,
      maxDownloads: link.maxDownloads,
      downloadCount: link.downloadCount,
      isActive: link.isActive,
      createdAt: link.createdAt,
      target: link.file ? { type: 'file', ...link.file, size: link.file.size.toString() } : { type: 'space', ...link.space },
    };
  }

  /**
   * Revoke a share link
   */
  async revokeShareLink(linkId: string, userId: string) {
    const link = await prisma.shareLink.findUnique({
      where: { id: linkId },
    });

    if (!link) {
      throw new NotFoundError('Share link not found');
    }

    if (link.createdBy !== userId) {
      throw new ForbiddenError('Only the creator can revoke this link');
    }

    await prisma.shareLink.update({
      where: { id: linkId },
      data: { isActive: false },
    });

    return { message: 'Share link revoked successfully' };
  }

  /**
   * List share links created by the user
   */
  async listUserShareLinks(userId: string) {
    const links = await prisma.shareLink.findMany({
      where: { createdBy: userId, isActive: true },
      orderBy: { createdAt: 'desc' },
      include: {
        file: { select: { id: true, name: true } },
        space: { select: { id: true, name: true, icon: true } },
      },
    });

    return links.map((l) => ({
      id: l.id,
      token: l.token,
      permission: l.permission,
      hasPassword: !!l.password,
      expiresAt: l.expiresAt,
      maxDownloads: l.maxDownloads,
      downloadCount: l.downloadCount,
      shareUrl: `${env.APP_URL}/share/${l.token}`,
      downloadUrl: l.file ? `${env.APP_URL}/api/${env.API_VERSION}/share/${l.token}/download` : null,
      target: l.file ? { type: 'file', ...l.file } : { type: 'space', ...l.space },
      createdAt: l.createdAt,
    }));
  }
}

export const sharingService = new SharingService();
