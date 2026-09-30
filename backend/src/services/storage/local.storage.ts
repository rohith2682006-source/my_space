import fs from 'fs';
import path from 'path';
import { Readable } from 'stream';
import {
  IStorageProvider,
  UploadOptions,
  FileMetadata,
} from './storage.interface';
import { env } from '../../config/env';
import { NotFoundError } from '../../utils/errors';

export class LocalStorageProvider implements IStorageProvider {
  private baseDir: string;

  constructor(baseDir?: string) {
    this.baseDir = baseDir || env.uploadDir;
    this.ensureDirectory(this.baseDir);
  }

  private ensureDirectory(dirPath: string): void {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  }

  private getFilePath(key: string): string {
    // Prevent directory traversal attacks
    const safeKey = path.normalize(key).replace(/^(\.\.(\/|\\|$))+/, '');
    return path.join(this.baseDir, safeKey);
  }

  async upload(options: UploadOptions): Promise<string> {
    const filePath = this.getFilePath(options.key);
    this.ensureDirectory(path.dirname(filePath));

    await fs.promises.writeFile(filePath, options.buffer);
    return options.key;
  }

  async download(key: string): Promise<Buffer> {
    const filePath = this.getFilePath(key);
    if (!fs.existsSync(filePath)) {
      throw new NotFoundError(`File with key "${key}" not found in storage`);
    }
    return fs.promises.readFile(filePath);
  }

  async getStream(key: string): Promise<Readable> {
    const filePath = this.getFilePath(key);
    if (!fs.existsSync(filePath)) {
      throw new NotFoundError(`File with key "${key}" not found in storage`);
    }
    return fs.createReadStream(filePath);
  }

  async delete(key: string): Promise<void> {
    const filePath = this.getFilePath(key);
    if (fs.existsSync(filePath)) {
      await fs.promises.unlink(filePath);
    }
  }

  async exists(key: string): Promise<boolean> {
    const filePath = this.getFilePath(key);
    return fs.existsSync(filePath);
  }

  async getMetadata(key: string): Promise<FileMetadata> {
    const filePath = this.getFilePath(key);
    if (!fs.existsSync(filePath)) {
      throw new NotFoundError(`File with key "${key}" not found in storage`);
    }

    const stats = await fs.promises.stat(filePath);
    return {
      key,
      size: stats.size,
      mimeType: 'application/octet-stream', // default or lookup from extension
      lastModified: stats.mtime,
    };
  }

  async getUrl(key: string): Promise<string> {
    // For local dev, route through the secure /api/v1/files/raw/:key or static preview endpoint
    return `/api/v1/files/raw/${encodeURIComponent(key)}`;
  }
}
