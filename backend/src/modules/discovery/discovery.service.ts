import { prisma } from '../../config/database';
import { buildPaginatedResponse } from '../../utils/helpers';

export class DiscoveryService {
  /**
   * Universal Search: Searches across files and spaces belonging to the user
   */
  async universalSearch(userId: string, query: string, page: number = 1, limit: number = 20) {
    if (!query || query.trim().length === 0) {
      return { spaces: [], files: [] };
    }

    const trimmed = query.trim();

    // 1. Search accessible Spaces
    const spaces = await prisma.space.findMany({
      where: {
        deletedAt: null,
        OR: [
          { ownerId: userId },
          { members: { some: { userId, status: 'ACCEPTED' } } },
        ],
        AND: [
          {
            OR: [
              { name: { contains: trimmed } },
              { description: { contains: trimmed } },
            ],
          },
        ],
      },
      take: 5,
      select: {
        id: true,
        name: true,
        icon: true,
        color: true,
        fileCount: true,
      },
    });

    // 2. Search files in accessible Spaces
    const accessibleSpaceIds = (
      await prisma.space.findMany({
        where: {
          deletedAt: null,
          OR: [
            { ownerId: userId },
            { members: { some: { userId, status: 'ACCEPTED' } } },
          ],
        },
        select: { id: true },
      })
    ).map((s) => s.id);

    const [totalFiles, files] = await Promise.all([
      prisma.file.count({
        where: {
          spaceId: { in: accessibleSpaceIds },
          deletedAt: null,
          trashedAt: null,
          OR: [
            { name: { contains: trimmed } },
            { originalName: { contains: trimmed } },
            { content: { contains: trimmed } },
          ],
        },
      }),
      prisma.file.findMany({
        where: {
          spaceId: { in: accessibleSpaceIds },
          deletedAt: null,
          trashedAt: null,
          OR: [
            { name: { contains: trimmed } },
            { originalName: { contains: trimmed } },
            { content: { contains: trimmed } },
          ],
        },
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { updatedAt: 'desc' },
        include: {
          space: {
            select: {
              id: true,
              name: true,
              icon: true,
              color: true,
            },
          },
        },
      }),
    ]);

    const formattedFiles = files.map((f) => ({
      ...f,
      size: f.size.toString(),
    }));

    return {
      spaces,
      files: buildPaginatedResponse(formattedFiles, totalFiles, { page, limit }),
    };
  }

  /**
   * Recent Files: recently opened or uploaded across all accessible spaces
   */
  async getRecentFiles(userId: string, limit: number = 20) {
    const accessibleSpaceIds = (
      await prisma.space.findMany({
        where: {
          deletedAt: null,
          OR: [
            { ownerId: userId },
            { members: { some: { userId, status: 'ACCEPTED' } } },
          ],
        },
        select: { id: true },
      })
    ).map((s) => s.id);

    const files = await prisma.file.findMany({
      where: {
        spaceId: { in: accessibleSpaceIds },
        deletedAt: null,
        trashedAt: null,
      },
      take: limit,
      orderBy: [
        { openedAt: 'desc' },
        { createdAt: 'desc' },
      ],
      include: {
        space: {
          select: {
            id: true,
            name: true,
            icon: true,
            color: true,
          },
        },
      },
    });

    return files.map((f) => ({
      ...f,
      size: f.size.toString(),
    }));
  }

  /**
   * Favorites: starred files for the user
   */
  async getFavorites(userId: string) {
    const favorites = await prisma.favorite.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        file: {
          include: {
            space: {
              select: {
                id: true,
                name: true,
                icon: true,
                color: true,
              },
            },
          },
        },
      },
    });

    return favorites
      .filter((fav) => fav.file && !fav.file.deletedAt && !fav.file.trashedAt)
      .map((fav) => ({
        ...fav.file,
        size: fav.file.size.toString(),
        favoritedAt: fav.createdAt,
      }));
  }

  /**
   * Trash: items in trash with retention days left (30 days default)
   */
  async getTrash(userId: string) {
    // Only show trash for spaces owned by the user
    const userSpaces = await prisma.space.findMany({
      where: { ownerId: userId },
      select: { id: true },
    });

    const spaceIds = userSpaces.map((s) => s.id);

    const trashedFiles = await prisma.file.findMany({
      where: {
        spaceId: { in: spaceIds },
        trashedAt: { not: null },
        deletedAt: null,
      },
      orderBy: { trashedAt: 'desc' },
      include: {
        space: {
          select: {
            id: true,
            name: true,
            icon: true,
            color: true,
          },
        },
      },
    });

    const retentionDays = 30;
    const now = new Date();

    return trashedFiles.map((file) => {
      const trashedDate = file.trashedAt || file.updatedAt;
      const daysPassed = Math.floor(
        (now.getTime() - new Date(trashedDate).getTime()) / (1000 * 60 * 60 * 24)
      );
      const daysRemaining = Math.max(0, retentionDays - daysPassed);

      return {
        ...file,
        size: file.size.toString(),
        daysRemaining,
      };
    });
  }

  /**
   * Storage Dashboard: comprehensive stats breakdown
   */
  async getStorageStats(userId: string) {
    // Calculate storage across user files
    const userSpaces = await prisma.space.findMany({
      where: { ownerId: userId, deletedAt: null },
      select: { id: true },
    });

    const spaceIds = userSpaces.map((s) => s.id);

    const files = await prisma.file.findMany({
      where: {
        spaceId: { in: spaceIds },
        deletedAt: null,
      },
      select: {
        size: true,
        category: true,
      },
    });

    let totalUsed = BigInt(0);
    const categorySizes: Record<string, bigint> = {
      DOCUMENT: BigInt(0),
      IMAGE: BigInt(0),
      VIDEO: BigInt(0),
      AUDIO: BigInt(0),
      ARCHIVE: BigInt(0),
      CODE: BigInt(0),
      NOTE: BigInt(0),
      LINK: BigInt(0),
      OTHER: BigInt(0),
    };

    for (const f of files) {
      totalUsed += f.size;
      const cat = f.category || 'OTHER';
      if (categorySizes[cat] !== undefined) {
        categorySizes[cat] += f.size;
      } else {
        categorySizes.OTHER += f.size;
      }
    }

    // Default 5 GB free quota (5 * 1024 * 1024 * 1024)
    const storageLimitBytes = BigInt(5) * BigInt(1024) * BigInt(1024) * BigInt(1024);

    return {
      totalUsedBytes: totalUsed.toString(),
      storageLimitBytes: storageLimitBytes.toString(),
      usagePercentage: Number(
        (Number(totalUsed) / Number(storageLimitBytes) * 100).toFixed(1)
      ),
      breakdown: {
        documents: categorySizes.DOCUMENT.toString(),
        images: categorySizes.IMAGE.toString(),
        videos: categorySizes.VIDEO.toString(),
        audio: categorySizes.AUDIO.toString(),
        archives: categorySizes.ARCHIVE.toString(),
        code: categorySizes.CODE.toString(),
        notes: categorySizes.NOTE.toString(),
        links: categorySizes.LINK.toString(),
        other: categorySizes.OTHER.toString(),
      },
    };
  }
}

export const discoveryService = new DiscoveryService();
