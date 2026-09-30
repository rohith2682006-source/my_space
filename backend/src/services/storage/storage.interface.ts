import { Readable } from 'stream';

export interface UploadOptions {
  key: string;
  buffer: Buffer;
  mimeType: string;
  metadata?: Record<string, string>;
}

export interface FileMetadata {
  key: string;
  size: number;
  mimeType: string;
  lastModified: Date;
  etag?: string;
}

export interface IStorageProvider {
  /**
   * Upload a file to storage
   */
  upload(options: UploadOptions): Promise<string>;

  /**
   * Download a file from storage as a buffer
   */
  download(key: string): Promise<Buffer>;

  /**
   * Get a readable stream for a file
   */
  getStream(key: string): Promise<Readable>;

  /**
   * Delete a file from storage
   */
  delete(key: string): Promise<void>;

  /**
   * Check if a file exists in storage
   */
  exists(key: string): Promise<boolean>;

  /**
   * Get file metadata
   */
  getMetadata(key: string): Promise<FileMetadata>;

  /**
   * Get a signed or direct URL for file access
   */
  getUrl(key: string, expiresInSeconds?: number): Promise<string>;
}
