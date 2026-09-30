import multer from 'multer';
import { env } from '../../config/env';
import { BadRequestError } from '../../utils/errors';
import { isDangerousExtension } from '../../utils/helpers';

// Use memory storage for clean buffer processing and SHA-256 calculation
const storage = multer.memoryStorage();

export const uploadMiddleware = multer({
  storage,
  limits: {
    fileSize: env.maxFileSizeBytes,
  },
  fileFilter: (_req, file, cb) => {
    // Block executable/dangerous files for security
    if (isDangerousExtension(file.originalname)) {
      cb(new BadRequestError('File type not allowed for security reasons (.exe, .bat, etc.)'));
      return;
    }

    // Accept ALL other file formats (images, documents, archives, videos, audio, design, code, etc.)
    cb(null, true);
  },
});
