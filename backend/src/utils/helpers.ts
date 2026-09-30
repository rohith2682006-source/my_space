import crypto from 'crypto';

export type FileCategory =
  | 'DOCUMENT'
  | 'IMAGE'
  | 'VIDEO'
  | 'AUDIO'
  | 'ARCHIVE'
  | 'CODE'
  | 'NOTE'
  | 'LINK'
  | 'OTHER';

/**
 * Categorize a file based on its MIME type
 */
export function categorizeFile(mimeType: string, filename?: string): FileCategory {
  const ext = filename ? getFileExtension(filename).toLowerCase() : '';

  if (mimeType.startsWith('image/') || ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'tiff', 'ico', 'heic', 'raw'].includes(ext)) {
    return 'IMAGE';
  }
  if (mimeType.startsWith('video/') || ['mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv', '3gp'].includes(ext)) {
    return 'VIDEO';
  }
  if (mimeType.startsWith('audio/') || ['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a', 'wma'].includes(ext)) {
    return 'AUDIO';
  }
  if (
    mimeType.includes('pdf') ||
    mimeType.includes('document') ||
    mimeType.includes('spreadsheet') ||
    mimeType.includes('presentation') ||
    mimeType.includes('text/') ||
    mimeType.includes('msword') ||
    mimeType.includes('ms-excel') ||
    mimeType.includes('ms-powerpoint') ||
    mimeType.includes('officedocument') ||
    ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'md', 'rtf', 'odt', 'ods', 'odp'].includes(ext)
  ) {
    return 'DOCUMENT';
  }
  if (
    mimeType.includes('zip') ||
    mimeType.includes('rar') ||
    mimeType.includes('tar') ||
    mimeType.includes('gzip') ||
    mimeType.includes('7z') ||
    mimeType.includes('compressed') ||
    ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso'].includes(ext)
  ) {
    return 'ARCHIVE';
  }
  if (
    mimeType.includes('javascript') ||
    mimeType.includes('json') ||
    mimeType.includes('xml') ||
    mimeType.includes('html') ||
    mimeType.includes('css') ||
    mimeType.includes('python') ||
    mimeType.includes('java') ||
    ['js', 'ts', 'jsx', 'tsx', 'dart', 'py', 'java', 'c', 'cpp', 'cs', 'go', 'rs', 'php', 'rb', 'swift', 'kt', 'html', 'css', 'json', 'xml', 'yaml', 'yml', 'sql', 'sh'].includes(ext)
  ) {
    return 'CODE';
  }
  return 'OTHER';
}

/**
 * Generate a SHA-256 checksum for duplicate detection
 */
export function generateChecksum(buffer: Buffer): string {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

/**
 * Generate a secure random token
 */
export function generateSecureToken(length: number = 32): string {
  return crypto.randomBytes(length).toString('hex');
}

/**
 * Format bytes to human-readable string
 */
export function formatBytes(bytes: number | bigint): string {
  const b = Number(bytes);
  if (b === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(b) / Math.log(k));
  return `${parseFloat((b / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

/**
 * Sanitize filename to prevent path traversal
 */
export function sanitizeFilename(filename: string): string {
  return filename
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/\.{2,}/g, '.')
    .slice(0, 255);
}

/**
 * Get file extension from filename
 */
export function getFileExtension(filename: string): string {
  const parts = filename.split('.');
  return parts.length > 1 ? parts.pop()!.toLowerCase() : '';
}

/**
 * Dangerous extensions that could compromise host or client systems
 */
export const DANGEROUS_EXTENSIONS = new Set([
  'exe',
  'bat',
  'cmd',
  'sh',
  'ps1',
  'dll',
  'sys',
  'vbs',
  'msi',
  'com',
  'scr',
  'cpl',
  'gadget',
  'wsf',
  'jse',
  'pif',
  'reg',
  'hta',
]);

export function isDangerousExtension(filename: string): boolean {
  const ext = getFileExtension(filename).toLowerCase();
  return DANGEROUS_EXTENSIONS.has(ext);
}

/**
 * Allowed MIME types for upload
 */
export const ALLOWED_MIME_TYPES = new Set([
  // Documents
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain',
  'text/csv',
  'text/markdown',
  // Images
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'image/bmp',
  'image/tiff',
  // Videos
  'video/mp4',
  'video/quicktime',
  'video/x-msvideo',
  'video/webm',
  'video/x-matroska',
  // Audio
  'audio/mpeg',
  'audio/wav',
  'audio/ogg',
  'audio/aac',
  'audio/flac',
  'audio/x-m4a',
  // Archives
  'application/zip',
  'application/x-rar-compressed',
  'application/x-7z-compressed',
  'application/gzip',
  'application/x-tar',
  // Code
  'application/json',
  'application/xml',
  'text/html',
  'text/css',
  'application/javascript',
  'text/xml',
  // Other
  'application/octet-stream',
]);

/**
 * Pagination helper
 */
export interface PaginationParams {
  page: number;
  limit: number;
}

export interface PaginatedResult<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasMore: boolean;
  };
}

export function buildPaginatedResponse<T>(
  data: T[],
  total: number,
  params: PaginationParams
): PaginatedResult<T> {
  const totalPages = Math.ceil(total / params.limit);
  return {
    data,
    pagination: {
      page: params.page,
      limit: params.limit,
      total,
      totalPages,
      hasMore: params.page < totalPages,
    },
  };
}
