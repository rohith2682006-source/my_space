import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function clearAll() {
  await prisma.activity.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.shareLink.deleteMany();
  await prisma.filePermission.deleteMany();
  await prisma.favorite.deleteMany();
  await prisma.fileTag.deleteMany();
  await prisma.tag.deleteMany();
  await prisma.fileVersion.deleteMany();
  await prisma.file.deleteMany();
  await prisma.spaceMember.deleteMany();
  await prisma.space.deleteMany();
  await prisma.storageUsage.deleteMany();
  await prisma.refreshToken.deleteMany();
  console.log('✅ All data cleared successfully');
}

clearAll()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
