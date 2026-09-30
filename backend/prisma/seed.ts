import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // 1. Create Default Plans
  const plans = [
    {
      name: 'free',
      displayName: 'Free',
      description: 'Essential digital storage for personal use',
      storageLimitBytes: BigInt(5) * BigInt(1024) * BigInt(1024) * BigInt(1024), // 5 GB
      maxFileSize: BigInt(100) * BigInt(1024) * BigInt(1024), // 100 MB
      maxSpaces: 10,
      priceMonthly: 0,
      priceYearly: 0,
      aiCreditsMonthly: 50,
      quickSearchLimit: 100,
      deepSearchLimit: 10,
      aiEnabledFileLimit: 5,
    },
    {
      name: 'plus',
      displayName: 'Plus',
      description: 'More storage and version history for active organizers',
      storageLimitBytes: BigInt(50) * BigInt(1024) * BigInt(1024) * BigInt(1024), // 50 GB
      maxFileSize: BigInt(500) * BigInt(1024) * BigInt(1024), // 500 MB
      maxSpaces: 50,
      priceMonthly: 4.99,
      priceYearly: 49.99,
      aiCreditsMonthly: 500,
      quickSearchLimit: 1000,
      deepSearchLimit: 100,
      aiEnabledFileLimit: 50,
    },
    {
      name: 'pro',
      displayName: 'Pro',
      description: 'Power user capabilities with AI search and unlimited spaces',
      storageLimitBytes: BigInt(500) * BigInt(1024) * BigInt(1024) * BigInt(1024), // 500 GB
      maxFileSize: BigInt(2) * BigInt(1024) * BigInt(1024) * BigInt(1024), // 2 GB
      maxSpaces: 9999,
      priceMonthly: 9.99,
      priceYearly: 99.99,
      aiCreditsMonthly: 2000,
      quickSearchLimit: -1,
      deepSearchLimit: -1,
      aiEnabledFileLimit: -1,
    },
  ];

  for (const plan of plans) {
    await prisma.plan.upsert({
      where: { name: plan.name },
      update: plan,
      create: plan,
    });
  }
  console.log('✅ Plans seeded');

  // 2. Create Demo User
  const passwordHash = await bcrypt.hash('Password123!', 12);
  const demoUser = await prisma.user.upsert({
    where: { email: 'demo@spaces.app' },
    update: {},
    create: {
      email: 'demo@spaces.app',
      passwordHash,
      firstName: 'Rohith',
      lastName: 'Kumar',
      isVerified: true,
      storageUsage: {
        create: {
          totalUsed: BigInt(0),
        },
      },
    },
  });
  console.log('✅ Demo user seeded (demo@spaces.app / Password123!)');

  // 3. Create Sample Spaces
  const sampleSpaces = [
    {
      name: 'College 2026',
      description: 'Computer Science coursework, lecture notes, syllabus, and exams',
      icon: '🎓',
      color: '#6366F1', // Indigo
      ownerId: demoUser.id,
      fileCount: 4,
    },
    {
      name: 'Projects & Code',
      description: 'Source code archives, architectural diagrams, and documentation',
      icon: '💻',
      color: '#06B6D4', // Cyan
      ownerId: demoUser.id,
      fileCount: 3,
    },
    {
      name: 'Travel & Trips',
      description: 'Flight confirmations, hotel bookings, passports, and trip itinerary',
      icon: '✈️',
      color: '#10B981', // Emerald
      ownerId: demoUser.id,
      fileCount: 2,
    },
    {
      name: 'Personal & Finance',
      description: 'Tax forms, lease agreement, receipts, and important contracts',
      icon: '🔒',
      color: '#F59E0B', // Amber
      ownerId: demoUser.id,
      fileCount: 2,
    },
  ];

  for (const spaceData of sampleSpaces) {
    const existingSpace = await prisma.space.findFirst({
      where: { name: spaceData.name, ownerId: demoUser.id },
    });

    if (!existingSpace) {
      const space = await prisma.space.create({
        data: {
          ...spaceData,
          members: {
            create: {
              userId: demoUser.id,
              role: 'OWNER',
              status: 'ACCEPTED',
            },
          },
        },
      });

      // Add sample notes/links
      if (space.name === 'College 2026') {
        await prisma.file.createMany({
          data: [
            {
              name: 'DBMS Lecture Notes - Normalization.md',
              originalName: 'DBMS Lecture Notes - Normalization.md',
              mimeType: 'text/markdown',
              extension: 'md',
              size: BigInt(4096),
              storageKey: `demo/${space.id}_dbms.md`,
              spaceId: space.id,
              uploadedBy: demoUser.id,
              category: 'NOTE',
              isStarred: true,
              content: '# Database Normalization\n\n- 1NF: Atomic values\n- 2NF: No partial dependencies\n- 3NF: No transitive dependencies\n- BCNF: Stricter 3NF',
            },
            {
              name: 'Distributed Systems Course Portal',
              originalName: 'Course Portal',
              mimeType: 'text/uri-list',
              extension: 'url',
              size: BigInt(128),
              storageKey: `demo/${space.id}_portal.url`,
              spaceId: space.id,
              uploadedBy: demoUser.id,
              category: 'LINK',
              content: 'https://classroom.google.com',
            },
          ],
        });
      }
    }
  }

  console.log('✅ Demo spaces & files seeded');
  console.log('🎉 Seeding completed!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
