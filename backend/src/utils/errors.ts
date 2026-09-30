// ─── Custom Error Classes ────────────────────────────────────
// Structured errors with HTTP status codes for consistent API responses

export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode: number,
    code: string = 'INTERNAL_ERROR',
    isOperational: boolean = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = isOperational;
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export class BadRequestError extends AppError {
  constructor(message: string = 'Bad request', code: string = 'BAD_REQUEST') {
    super(message, 400, code);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized', code: string = 'UNAUTHORIZED') {
    super(message, 401, code);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Forbidden', code: string = 'FORBIDDEN') {
    super(message, 403, code);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found', code: string = 'NOT_FOUND') {
    super(message, 404, code);
  }
}

export class ConflictError extends AppError {
  constructor(message: string = 'Resource already exists', code: string = 'CONFLICT') {
    super(message, 409, code);
  }
}

export class TooManyRequestsError extends AppError {
  constructor(message: string = 'Too many requests', code: string = 'RATE_LIMITED') {
    super(message, 429, code);
  }
}

export class PayloadTooLargeError extends AppError {
  constructor(message: string = 'File too large', code: string = 'PAYLOAD_TOO_LARGE') {
    super(message, 413, code);
  }
}

export class InternalError extends AppError {
  constructor(message: string = 'Internal server error', code: string = 'INTERNAL_ERROR') {
    super(message, 500, code, false);
  }
}
