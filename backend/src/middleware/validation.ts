import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';

/**
 * Validate request body, query, or params using a Zod schema.
 * Returns 400 with detailed validation errors on failure.
 */
export function validate(schema: ZodSchema, source: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      const data = schema.parse(req[source]);
      // Replace with parsed (and potentially transformed) data safely in Express 5
      if (source === 'body') {
        req.body = data;
      } else if (source === 'query') {
        Object.assign(req.query, data);
      } else if (source === 'params') {
        Object.assign(req.params, data);
      }
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const formattedErrors = error.errors.map((err) => ({
          field: err.path.join('.'),
          message: err.message,
        }));

        res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Request validation failed',
            details: formattedErrors,
          },
        });
        return;
      }
      next(error);
    }
  };
}
