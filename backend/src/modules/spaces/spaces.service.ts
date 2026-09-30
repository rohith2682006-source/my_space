import { prisma } from '../../config/database';
import {
  NotFoundError,
  ForbiddenError,
  ConflictError,
} from '../../utils/errors';
import { buildPaginatedResponse } from '../../utils/helpers';
import type {
  CreateSpaceInput,
  UpdateSpaceInput,
  SpaceQueryInput,
  AddSpaceMemberInput,
} from './spaces.schema';

export class SpacesService {
  /**
   * Create a new Space
   */
  async createSpace(userId: string, input: CreateSpaceInput) {
    const space = await prisma.space.create({
      data: {
        name: input.name,
        description: input.description,
        icon: input.icon || '📁',
        color: input.color || '#6366F1',
        coverUrl: input.coverUrl || null,
        isPrivate: input.isPrivate ?? true,
        ownerId: userId,
        members: {
          create: {
            userId: userId,
            role: 'OWNER',
            status: 'ACCEPTED',
            joinedAt: new Date(),
          },
        },
      },
      include: {
        owner: {
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

    // Record activity
    await prisma.activity.create({
      data: {
        userId,
        spaceId: space.id,
        action: 'SPACE_CREATED',
        targetType: 'space',
        targetId: space.id,
        metadata: JSON.stringify({ name: space.name }),
      },
    });

    return {
      ...space,
      totalSize: space.totalSize.toString(),
    };
  }

  /**
   * List spaces the user owns or is a member of
   */
  async listSpaces(userId: string, query: SpaceQueryInput) {
    const where: any = {
      deletedAt: null,
      OR: [
        { ownerId: userId },
        { members: { some: { userId, status: 'ACCEPTED' } } },
      ],
    };

    if (query.search) {
      where.AND = [
        {
          OR: [
            { name: { contains: query.search } },
            { description: { contains: query.search } },
          ],
        },
      ];
    }

    const page = Number(query?.page) > 0 ? Number(query.page) : 1;
    const limit = Number(query?.limit) > 0 ? Math.min(Number(query.limit), 100) : 20;
    const sortBy = query?.sortBy || 'lastActivityAt';
    const order = query?.order === 'asc' ? 'asc' : 'desc';

    const [total, spaces] = await Promise.all([
      prisma.space.count({ where }),
      prisma.space.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: {
          [sortBy]: order,
        },
        include: {
          owner: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              avatarUrl: true,
            },
          },
          members: {
            where: { status: 'ACCEPTED' },
            select: {
              id: true,
              role: true,
              user: {
                select: {
                  id: true,
                  firstName: true,
                  lastName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          _count: {
            select: {
              files: {
                where: { deletedAt: null, trashedAt: null },
              },
            },
          },
        },
      }),
    ]);

    const formattedSpaces = spaces.map((s) => ({
      ...s,
      totalSize: s.totalSize.toString(),
      fileCount: s._count.files,
    }));

    return buildPaginatedResponse(formattedSpaces, total, { page, limit });
  }

  /**
   * Get single space by ID with authorization check
   */
  async getSpaceById(spaceId: string, userId: string) {
    const space = await prisma.space.findFirst({
      where: {
        id: spaceId,
        deletedAt: null,
      },
      include: {
        owner: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            email: true,
            avatarUrl: true,
          },
        },
        members: {
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                avatarUrl: true,
              },
            },
          },
        },
        _count: {
          select: {
            files: {
              where: { deletedAt: null, trashedAt: null },
            },
          },
        },
      },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    // Check authorization: must be owner, member, or space is public
    const isOwner = space.ownerId === userId;
    const membership = space.members.find((m) => m.userId === userId && m.status === 'ACCEPTED');

    if (space.isPrivate && !isOwner && !membership) {
      throw new ForbiddenError('You do not have access to this Space');
    }

    const userRole = isOwner ? 'OWNER' : membership ? membership.role : 'VIEWER';

    return {
      ...space,
      totalSize: space.totalSize.toString(),
      fileCount: space._count.files,
      currentUserRole: userRole,
    };
  }

  /**
   * Update space
   */
  async updateSpace(spaceId: string, userId: string, input: UpdateSpaceInput) {
    const space = await prisma.space.findFirst({
      where: { id: spaceId, deletedAt: null },
      include: { members: true },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    const isOwner = space.ownerId === userId;
    const isAdmin = space.members.some(
      (m) => m.userId === userId && (m.role === 'ADMIN' || m.role === 'OWNER') && m.status === 'ACCEPTED'
    );

    if (!isOwner && !isAdmin) {
      throw new ForbiddenError('Only Space owners and admins can edit this Space');
    }

    const updated = await prisma.space.update({
      where: { id: spaceId },
      data: {
        ...input,
        lastActivityAt: new Date(),
      },
    });

    if (input.name && input.name !== space.name) {
      await prisma.activity.create({
        data: {
          userId,
          spaceId,
          action: 'SPACE_RENAMED',
          targetType: 'space',
          targetId: spaceId,
          metadata: JSON.stringify({ oldName: space.name, newName: input.name }),
        },
      });
    }

    return {
      ...updated,
      totalSize: updated.totalSize.toString(),
    };
  }

  /**
   * Soft delete space
   */
  async deleteSpace(spaceId: string, userId: string) {
    const space = await prisma.space.findFirst({
      where: { id: spaceId, deletedAt: null },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    if (space.ownerId !== userId) {
      throw new ForbiddenError('Only the owner can delete this Space');
    }

    await prisma.space.update({
      where: { id: spaceId },
      data: { deletedAt: new Date() },
    });

    await prisma.activity.create({
      data: {
        userId,
        spaceId,
        action: 'SPACE_DELETED',
        targetType: 'space',
        targetId: spaceId,
        metadata: JSON.stringify({ name: space.name }),
      },
    });

    return { message: 'Space deleted successfully' };
  }

  /**
   * Add a member to a Space
   */
  async addMember(spaceId: string, requestingUserId: string, input: AddSpaceMemberInput) {
    const space = await prisma.space.findFirst({
      where: { id: spaceId, deletedAt: null },
      include: { members: true },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    const isOwner = space.ownerId === requestingUserId;
    const isAdmin = space.members.some(
      (m) => m.userId === requestingUserId && (m.role === 'ADMIN' || m.role === 'OWNER')
    );

    if (!isOwner && !isAdmin) {
      throw new ForbiddenError('Only Space owners and admins can invite members');
    }

    const userToAdd = await prisma.user.findUnique({
      where: { email: input.email.toLowerCase() },
    });

    if (!userToAdd) {
      throw new NotFoundError(`No user found with email ${input.email}`);
    }

    const existingMember = await prisma.spaceMember.findUnique({
      where: {
        spaceId_userId: {
          spaceId,
          userId: userToAdd.id,
        },
      },
    });

    if (existingMember) {
      throw new ConflictError('User is already a member of this Space');
    }

    const member = await prisma.spaceMember.create({
      data: {
        spaceId,
        userId: userToAdd.id,
        role: input.role,
        status: 'ACCEPTED', // Or PENDING for invitation flow
        joinedAt: new Date(),
      },
      include: {
        user: {
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

    // Notify user
    await prisma.notification.create({
      data: {
        userId: userToAdd.id,
        type: 'SPACE_INVITATION',
        title: 'New Space Invitation',
        message: `You were added to "${space.name}" as a ${input.role.toLowerCase()}`,
        data: JSON.stringify({ spaceId, spaceName: space.name }),
      },
    });

    return member;
  }

  /**
   * Remove member from Space
   */
  async removeMember(spaceId: string, requestingUserId: string, memberUserId: string) {
    const space = await prisma.space.findFirst({
      where: { id: spaceId, deletedAt: null },
    });

    if (!space) {
      throw new NotFoundError('Space not found');
    }

    if (space.ownerId === memberUserId) {
      throw new ForbiddenError('Cannot remove the Space owner');
    }

    const isOwner = space.ownerId === requestingUserId;
    const isSelf = requestingUserId === memberUserId;

    if (!isOwner && !isSelf) {
      throw new ForbiddenError('Permission denied');
    }

    await prisma.spaceMember.delete({
      where: {
        spaceId_userId: {
          spaceId,
          userId: memberUserId,
        },
      },
    });

    return { message: 'Member removed successfully' };
  }
}

export const spacesService = new SpacesService();
