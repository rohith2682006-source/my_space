import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { prisma } from '../../config/database';
import { storage } from '../../services/storage';
import { aiService } from '../ai/ai.service';
import { enqueueJob } from '../../workers/job.worker';
import { AuditService } from '../../services/audit.service';
import { RealtimeService } from '../../services/realtime.service';
import {
  NotFoundError,
  ForbiddenError,
  BadRequestError,
} from '../../utils/errors';
import {
  categorizeFile,
  generateChecksum,
  sanitizeFilename,
  getFileExtension,
  buildPaginatedResponse,
} from '../../utils/helpers';
import type {
  FileQueryInput,
  RenameFileInput,
  MoveFileInput,
  CreateNoteOrLinkInput,
} from './files.schema';

export class FilesService {
  /**
   * Upload a file into a Space
   */
  async uploadFile(
    userId: string,
    spaceId: string,
    file: Express.Multer.File,
    forceDuplicate: boolean = false
  ) {
    // 1. Verify space exists and user has edit permissions
    await this.verifySpaceAccess(spaceId, userId, 'EDITOR');

    const sanitizedName = sanitizeFilename(file.originalname);
    const extension = getFileExtension(sanitizedName);
    const category = categorizeFile(file.mimetype, file.originalname);
    const checksum = generateChecksum(file.buffer);

    // 2. Duplicate Detection: Check if file with same checksum already exists in this space
    if (!forceDuplicate) {
      const existingDuplicate = await prisma.file.findFirst({
        where: {
          spaceId,
          checksum,
          deletedAt: null,
          trashedAt: null,
        },
      });

      if (existingDuplicate) {
        return {
          isDuplicate: true,
          duplicateOf: {
            id: existingDuplicate.id,
            name: existingDuplicate.name,
            size: existingDuplicate.size.toString(),
            createdAt: existingDuplicate.createdAt,
          },
          message: 'A file with identical content already exists in this Space.',
        };
      }
    }

    // 3. Generate unique storage key
    const uniqueKey = `${spaceId}/${uuidv4()}_${sanitizedName}`;

    // 4. Upload to storage provider
    await storage.upload({
      key: uniqueKey,
      buffer: file.buffer,
      mimeType: file.mimetype,
    });

    const fileSize = BigInt(file.size);

    // 5. Create database record & update space and storage counters
    const [fileRecord] = await prisma.$transaction([
      prisma.file.create({
        data: {
          name: sanitizedName,
          originalName: file.originalname,
          mimeType: file.mimetype,
          extension,
          size: fileSize,
          storageKey: uniqueKey,
          checksum,
          spaceId,
          uploadedBy: userId,
          category,
          indexStatus: 'NOT_INDEXED',
        },
      }),
      // Update space file count and total size
      prisma.space.update({
        where: { id: spaceId },
        data: {
          fileCount: { increment: 1 },
          totalSize: { increment: fileSize },
          lastActivityAt: new Date(),
        },
      }),
      // Update user storage usage
      prisma.storageUsage.upsert({
        where: { userId },
        create: {
          userId,
          totalUsed: fileSize,
        },
        update: {
          totalUsed: { increment: fileSize },
        },
      }),
      // Log activity
      prisma.activity.create({
        data: {
          userId,
          spaceId,
          action: 'FILE_UPLOADED',
          targetType: 'file',
          metadata: JSON.stringify({ name: sanitizedName, size: file.size }),
        },
      }),
    ]);

    this.notifySpaceMembers(spaceId, userId, 'FILE_UPLOADED', {
      fileId: fileRecord.id,
      spaceId,
      name: fileRecord.name,
      originalName: fileRecord.originalName,
      mimeType: fileRecord.mimeType,
      size: fileRecord.size.toString(),
      category: fileRecord.category,
      aiSearchEnabled: fileRecord.aiSearchEnabled,
      indexStatus: fileRecord.indexStatus,
      createdAt: fileRecord.createdAt.toISOString(),
    });

    return {
      isDuplicate: false,
      file: {
        ...fileRecord,
        size: fileRecord.size.toString(),
      },
    };
  }

  /**
   * Create a Note or Link inside a Space
   */
  async createNoteOrLink(userId: string, input: CreateNoteOrLinkInput) {
    await this.verifySpaceAccess(input.spaceId, userId, 'EDITOR');

    const sanitizedName = sanitizeFilename(input.name);
    const category = input.type === 'NOTE' ? 'NOTE' : 'LINK';
    const mimeType = input.type === 'NOTE' ? 'text/markdown' : 'text/uri-list';
    const extension = input.type === 'NOTE' ? 'md' : 'url';
    const contentBuffer = Buffer.from(input.content, 'utf-8');
    const fileSize = BigInt(contentBuffer.length);
    const storageKey = `${input.spaceId}/${uuidv4()}_${sanitizedName}.${extension}`;

    // Upload content buffer to storage
    await storage.upload({
      key: storageKey,
      buffer: contentBuffer,
      mimeType,
    });

    const fileRecord = await prisma.file.create({
      data: {
        name: sanitizedName,
        originalName: input.name,
        mimeType,
        extension,
        size: fileSize,
        storageKey,
        spaceId: input.spaceId,
        uploadedBy: userId,
        category,
        content: input.content,
        indexStatus: 'NOT_INDEXED',
      },
    });

    await prisma.space.update({
      where: { id: input.spaceId },
      data: {
        fileCount: { increment: 1 },
        totalSize: { increment: fileSize },
        lastActivityAt: new Date(),
      },
    });

    this.notifySpaceMembers(input.spaceId, userId, 'FILE_UPLOADED', {
      fileId: fileRecord.id,
      spaceId: input.spaceId,
      name: fileRecord.name,
      originalName: fileRecord.originalName,
      mimeType: fileRecord.mimeType,
      size: fileRecord.size.toString(),
      category: fileRecord.category,
      aiSearchEnabled: fileRecord.aiSearchEnabled,
      indexStatus: fileRecord.indexStatus,
      createdAt: fileRecord.createdAt.toISOString(),
    });

    return {
      ...fileRecord,
      size: fileRecord.size.toString(),
    };
  }

  /**
   * List files in a space with search, filter, and pagination
   */
  async listFilesInSpace(spaceId: string, userId: string, query: FileQueryInput) {
    await this.verifySpaceAccess(spaceId, userId, 'VIEWER');

    const where: any = {
      spaceId,
      deletedAt: null,
      trashedAt: null,
    };

    if (query.category) {
      where.category = query.category;
    }

    if (query.search) {
      where.OR = [
        { name: { contains: query.search } },
        { content: { contains: query.search } },
      ];
    }

    const page = Number(query?.page) > 0 ? Number(query.page) : 1;
    const limit = Number(query?.limit) > 0 ? Math.min(Number(query.limit), 100) : 30;
    const sortBy = query?.sortBy || 'createdAt';
    const order = query?.order === 'asc' ? 'asc' : 'desc';

    const [total, files] = await Promise.all([
      prisma.file.count({ where }),
      prisma.file.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: {
          [sortBy]: order,
        },
        include: {
          uploader: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
            },
          },
        },
      }),
    ]);

    const formattedFiles = files.map((f) => ({
      ...f,
      size: f.size.toString(),
    }));

    return buildPaginatedResponse(formattedFiles, total, { page, limit });
  }

  /**
   * Get single file details and update openedAt
   */
  async getFileById(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
      include: {
        space: {
          select: {
            id: true,
            name: true,
            icon: true,
            color: true,
            ownerId: true,
          },
        },
        uploader: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'VIEWER');

    // Update last opened time
    await prisma.file.update({
      where: { id: fileId },
      data: { openedAt: new Date() },
    });

    return {
      ...file,
      size: file.size.toString(),
    };
  }

  /**
   * Stream or download file content
   */
  async getFileStream(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'VIEWER');

    const stream = await storage.getStream(file.storageKey);

    return {
      stream,
      file: {
        ...file,
        size: Number(file.size),
      },
    };
  }

  /**
   * Rename a file
   */
  async renameFile(fileId: string, userId: string, input: RenameFileInput) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');

    const updated = await prisma.file.update({
      where: { id: fileId },
      data: { name: sanitizeFilename(input.name) },
    });

    await prisma.activity.create({
      data: {
        userId,
        spaceId: file.spaceId,
        action: 'FILE_RENAMED',
        targetType: 'file',
        targetId: fileId,
        metadata: JSON.stringify({ oldName: file.name, newName: input.name }),
      },
    });

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_RENAMED', {
      fileId,
      spaceId: file.spaceId,
      oldName: file.name,
      newName: updated.name,
      updatedAt: updated.updatedAt.toISOString(),
    });

    return {
      ...updated,
      size: updated.size.toString(),
    };
  }

  /**
   * Move a file to another Space
   */
  async moveFile(fileId: string, userId: string, input: MoveFileInput) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    // Verify access to source and target spaces
    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');
    await this.verifySpaceAccess(input.targetSpaceId, userId, 'EDITOR');

    if (file.spaceId === input.targetSpaceId) {
      return { ...file, size: file.size.toString() };
    }

    const fileSize = file.size;

    await prisma.$transaction([
      prisma.file.update({
        where: { id: fileId },
        data: { spaceId: input.targetSpaceId },
      }),
      prisma.fileChunk.updateMany({
        where: { fileId },
        data: { spaceId: input.targetSpaceId },
      }),
      // Decrement source space
      prisma.space.update({
        where: { id: file.spaceId },
        data: {
          fileCount: { decrement: 1 },
          totalSize: { decrement: fileSize },
        },
      }),
      // Increment target space
      prisma.space.update({
        where: { id: input.targetSpaceId },
        data: {
          fileCount: { increment: 1 },
          totalSize: { increment: fileSize },
          lastActivityAt: new Date(),
        },
      }),
      prisma.activity.create({
        data: {
          userId,
          spaceId: input.targetSpaceId,
          action: 'FILE_MOVED',
          targetType: 'file',
          targetId: fileId,
          metadata: JSON.stringify({ fileName: file.name, fromSpace: file.spaceId }),
        },
      }),
    ]);

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_MOVED', {
      fileId,
      sourceSpaceId: file.spaceId,
      targetSpaceId: input.targetSpaceId,
      fileName: file.name,
    });
    this.notifySpaceMembers(input.targetSpaceId, userId, 'FILE_MOVED', {
      fileId,
      sourceSpaceId: file.spaceId,
      targetSpaceId: input.targetSpaceId,
      fileName: file.name,
    });

    return { message: 'File moved successfully' };
  }

  /**
   * Toggle favorite / star status
   */
  async toggleFavorite(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'VIEWER');

    const existingFav = await prisma.favorite.findUnique({
      where: {
        userId_fileId: { userId, fileId },
      },
    });

    if (existingFav) {
      await prisma.favorite.delete({
        where: { id: existingFav.id },
      });
      await prisma.file.update({
        where: { id: fileId },
        data: { isStarred: false },
      });
      return { isFavorite: false };
    } else {
      await prisma.favorite.create({
        data: { userId, fileId },
      });
      await prisma.file.update({
        where: { id: fileId },
        data: { isStarred: true },
      });
      return { isFavorite: true };
    }
  }

  async setAiSearchAccess(fileId: string, userId: string, enabled: boolean) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null, trashedAt: null },
      include: { space: { select: { ownerId: true } } },
    });
    if (!file) throw new NotFoundError('File not found');

    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');

    if (!enabled) {
      // 1. Immediately flip the flag so searches stop using this file
      await prisma.file.update({
        where: { id: fileId },
        data: { aiSearchEnabled: false, indexError: null },
      });
      // 2. Enqueue async chunk cleanup so the response is instant
      await enqueueJob('AI_CLEANUP', { fileId });
      AuditService.log({
        userId,
        action: 'AI_DISABLED',
        targetType: 'file',
        targetId: fileId,
        metadata: { fileName: file.originalName || file.name },
      });
      this.notifySpaceMembers(file.spaceId, userId, 'FILE_AI_ACCESS_CHANGED', {
        fileId,
        spaceId: file.spaceId,
        aiSearchEnabled: false,
        indexStatus: file.indexStatus,
      });
      return { aiSearchEnabled: false, indexStatus: file.indexStatus };
    }

    // Already enabled — return current status
    if (file.aiSearchEnabled) {
      return { aiSearchEnabled: true, indexStatus: file.indexStatus };
    }

    if (!aiService.isSupportedDocument(file.originalName || file.name)) {
      throw new BadRequestError('This file type cannot be indexed for AI Search');
    }

    // Flip flag and mark as QUEUED
    await prisma.file.update({
      where: { id: fileId },
      data: { aiSearchEnabled: true, indexStatus: 'QUEUED', indexError: null },
    });

    // Enqueue background indexing job
    await enqueueJob('DOCUMENT_INDEX', {
      fileId: file.id,
      fileName: file.originalName || file.name,
      fileExtension: `.${file.extension.toLowerCase()}`,
      storageKey: file.storageKey,
      spaceId: file.spaceId,
      ownerId: file.space.ownerId,
      isNote: file.category === 'NOTE' && file.content !== null,
      noteContent: file.category === 'NOTE' ? (file.content ?? undefined) : undefined,
    });

    AuditService.log({
      userId,
      action: 'AI_ENABLED',
      targetType: 'file',
      targetId: fileId,
      metadata: { fileName: file.originalName || file.name },
    });

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_AI_ACCESS_CHANGED', {
      fileId,
      spaceId: file.spaceId,
      aiSearchEnabled: true,
      indexStatus: 'QUEUED',
    });

    return { aiSearchEnabled: true, indexStatus: 'QUEUED' };
  }

  /**
   * Soft delete file (move to Trash)
   */
  async trashFile(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');

    await prisma.file.update({
      where: { id: fileId },
      data: { trashedAt: new Date() },
    });

    await prisma.activity.create({
      data: {
        userId,
        spaceId: file.spaceId,
        action: 'FILE_DELETED',
        targetType: 'file',
        targetId: fileId,
        metadata: JSON.stringify({ name: file.name }),
      },
    });

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_DELETED', {
      fileId,
      spaceId: file.spaceId,
      fileName: file.name,
      isPermanent: false,
    });

    return { message: 'File moved to Trash' };
  }

  /**
   * Restore file from Trash
   */
  async restoreFile(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId, deletedAt: null, trashedAt: { not: null } },
    });

    if (!file) {
      throw new NotFoundError('Trashed file not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');

    await prisma.file.update({
      where: { id: fileId },
      data: { trashedAt: null },
    });

    await prisma.activity.create({
      data: {
        userId,
        spaceId: file.spaceId,
        action: 'FILE_RESTORED',
        targetType: 'file',
        targetId: fileId,
        metadata: JSON.stringify({ name: file.name }),
      },
    });

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_RESTORED', {
      fileId,
      spaceId: file.spaceId,
      fileName: file.name,
    });

    return { message: 'File restored successfully' };
  }

  /**
   * Permanently delete file from storage and database
   */
  async deletePermanently(fileId: string, userId: string) {
    const file = await prisma.file.findFirst({
      where: { id: fileId },
    });

    if (!file) {
      throw new NotFoundError('File not found');
    }

    await this.verifySpaceAccess(file.spaceId, userId, 'EDITOR');

    // 1. Delete from physical storage
    try {
      await storage.delete(file.storageKey);
    } catch (e) {
      console.warn(`Storage delete failed for key ${file.storageKey}`, e);
    }

    const fileSize = file.size;

    // 2. Delete database record & adjust counters
    await prisma.$transaction([
      prisma.file.delete({
        where: { id: fileId },
      }),
      prisma.space.update({
        where: { id: file.spaceId },
        data: {
          fileCount: { decrement: 1 },
          totalSize: { decrement: fileSize },
        },
      }),
      prisma.storageUsage.updateMany({
        where: { userId },
        data: {
          totalUsed: { decrement: fileSize },
        },
      }),
    ]);

    this.notifySpaceMembers(file.spaceId, userId, 'FILE_DELETED', {
      fileId,
      spaceId: file.spaceId,
      fileName: file.name,
      isPermanent: true,
    });

    return { message: 'File permanently deleted' };
  }

  // ─── Permission Helper ───────────────────────────────────────

  private async verifySpaceAccess(
    spaceId: string,
    userId: string,
    requiredRole: 'VIEWER' | 'EDITOR' | 'ADMIN' | 'OWNER'
  ) {
    const space = await prisma.space.findFirst({
      where: { id: spaceId, deletedAt: null },
      include: {
        members: { where: { userId, status: 'ACCEPTED' } },
      },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    if (space.ownerId === userId) {
      return; // Owners have full access
    }

    const member = space.members[0];
    if (!member) {
      if (space.isPrivate) {
        throw new ForbiddenError('You do not have access to this Space');
      }
      if (requiredRole !== 'VIEWER') {
        throw new ForbiddenError('Edit permissions required');
      }
      return;
    }

    const rolesOrder = ['VIEWER', 'EDITOR', 'ADMIN', 'OWNER'];
    const memberRoleIndex = rolesOrder.indexOf(member.role);
    const requiredRoleIndex = rolesOrder.indexOf(requiredRole);

    if (memberRoleIndex < requiredRoleIndex) {
      throw new ForbiddenError('Insufficient permissions in this Space');
    }
  }

  private async notifySpaceMembers(spaceId: string, actorUserId: string, event: string, data: Record<string, unknown>) {
    try {
      const space = await prisma.space.findUnique({
        where: { id: spaceId },
        select: { ownerId: true, members: { where: { status: 'ACCEPTED' }, select: { userId: true } } },
      });
      const userIds = new Set<string>([actorUserId]);
      if (space) {
        userIds.add(space.ownerId);
        space.members.forEach((m) => userIds.add(m.userId));
      }
      RealtimeService.emitToUsers(Array.from(userIds), event, data);
    } catch (e) {
      console.warn(`[Realtime] Failed to emit ${event}:`, e);
    }
  }
}

export const filesService = new FilesService();
