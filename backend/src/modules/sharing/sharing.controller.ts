import { Request, Response, NextFunction } from 'express';
import { sharingService } from './sharing.service';
import { AuthenticatedRequest } from '../../middleware/auth';

export class SharingController {
  async createLink(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await sharingService.createShareLink(req.user!.userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Share link created',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async resolveLink(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const token = req.params.token as string;
      const result = await sharingService.resolveShareLink(token, req.body);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async revokeLink(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = req.params.id as string;
      const result = await sharingService.revokeShareLink(id, req.user!.userId);
      res.status(200).json({
        success: true,
        message: result.message,
      });
    } catch (error) {
      next(error);
    }
  }

  async listUserLinks(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const links = await sharingService.listUserShareLinks(req.user!.userId);
      res.status(200).json({
        success: true,
        data: links,
      });
    } catch (error) {
      next(error);
    }
  }

  async getStats(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = req.params.id as string;
      const stats = await sharingService.getShareLinkStats(id, req.user!.userId);
      res.status(200).json({
        success: true,
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }

  async downloadFile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const token = req.params.token as string;
      const password = (req.query.password as string) || (req.body?.password as string);
      const { stream, file } = await sharingService.getShareFileStream(token, password);

      res.setHeader('Content-Type', file.mimeType);
      res.setHeader('Content-Length', file.size.toString());
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${encodeURIComponent(file.name)}"`
      );

      stream.pipe(res);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Directly view/stream the shared file in real-time without the entire app host
   */
  async viewFile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const token = req.params.token as string;
      const password = (req.query.password as string) || (req.body?.password as string);
      const link = await sharingService.getShareLinkByToken(token);

      if (!link || !link.isActive) {
        res.status(404).send(renderErrorPage('Link Unavailable', 'This share link has expired, been revoked, or does not exist.'));
        return;
      }

      if (link.expiresAt && link.expiresAt < new Date()) {
        res.status(410).send(renderErrorPage('Link Expired', 'This share link is no longer valid because it reached its expiration date.'));
        return;
      }

      if (link.maxDownloads && link.downloadCount >= link.maxDownloads) {
        res.status(403).send(renderErrorPage('Limit Reached', 'This link has reached its maximum view / download limit.'));
        return;
      }

      if (link.password && !password) {
        const title = link.file ? link.file.name : (link.space ? link.space.name : 'Protected Resource');
        res.status(200).send(renderPasswordPrompt(token, title, false));
        return;
      }

      // If it's a file, stream directly!
      if (link.file) {
        try {
          const { stream, file } = await sharingService.getShareFileStream(token, password);
          const isDownload = req.query.download === '1' || req.query.download === 'true';

          res.setHeader('Content-Type', file.mimeType || 'application/octet-stream');
          res.setHeader('Content-Length', file.size.toString());
          res.setHeader(
            'Content-Disposition',
            `${isDownload ? 'attachment' : 'inline'}; filename="${encodeURIComponent(file.name)}"`
          );
          res.setHeader('Cache-Control', 'public, max-age=3600');

          stream.pipe(res);
          return;
        } catch (err: any) {
          if (err.statusCode === 401 && link.password) {
            const title = link.file ? link.file.name : 'Protected Resource';
            res.status(401).send(renderPasswordPrompt(token, title, true));
            return;
          }
          throw err;
        }
      }

      // If it's a space, redirect to resolution endpoint
      if (link.space) {
        res.redirect(`/api/v1/share/resolve/${token}`);
        return;
      }

      res.status(404).send(renderErrorPage('Resource Not Found', 'Could not locate the shared resource.'));
    } catch (error) {
      next(error);
    }
  }
}

function renderPasswordPrompt(token: string, resourceName: string, isError: boolean): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Locked File • Spaces</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: radial-gradient(circle at top, #1E1B4B 0%, #0B0F19 60%);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #F8FAFC;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: rgba(30, 41, 59, 0.7);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 28px;
      padding: 36px 32px;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.6);
      text-align: center;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 64px;
      height: 64px;
      background: rgba(99, 102, 241, 0.15);
      border: 1px solid rgba(99, 102, 241, 0.3);
      border-radius: 20px;
      font-size: 28px;
      margin-bottom: 20px;
    }
    h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.3px; margin-bottom: 8px; color: #FFFFFF; }
    .filename {
      font-size: 14px;
      color: #94A3B8;
      margin-bottom: 24px;
      word-break: break-all;
    }
    .error-box {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.3);
      color: #FCA5A5;
      padding: 10px 14px;
      border-radius: 12px;
      font-size: 13px;
      margin-bottom: 18px;
    }
    input {
      width: 100%;
      background: rgba(15, 23, 42, 0.6);
      border: 1.5px solid rgba(255, 255, 255, 0.12);
      border-radius: 16px;
      padding: 14px 18px;
      font-size: 15px;
      color: #FFFFFF;
      outline: none;
      margin-bottom: 18px;
      transition: all 0.2s ease;
    }
    input:focus {
      border-color: #6366F1;
      box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.25);
    }
    button {
      width: 100%;
      background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%);
      color: #FFFFFF;
      border: none;
      border-radius: 16px;
      padding: 14px;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
      box-shadow: 0 10px 25px -5px rgba(99, 102, 241, 0.5);
      transition: all 0.2s ease;
    }
    button:hover {
      transform: translateY(-1px);
      box-shadow: 0 14px 28px -5px rgba(99, 102, 241, 0.6);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">🔒</div>
    <h1>Protected File</h1>
    <div class="filename">${escapeHtml(resourceName)}</div>
    ${isError ? '<div class="error-box">Incorrect password. Please verify and try again.</div>' : ''}
    <form method="GET" action="/share/${token}">
      <input type="password" name="password" placeholder="Enter link password" autofocus required />
      <button type="submit">Unlock & Open File</button>
    </form>
  </div>
</body>
</html>`;
}

function renderErrorPage(title: string, message: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} • Spaces</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: radial-gradient(circle at top, #1E1B4B 0%, #0B0F19 60%);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #F8FAFC;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: rgba(30, 41, 59, 0.7);
      backdrop-filter: blur(24px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 28px;
      padding: 36px 32px;
      max-width: 420px;
      width: 100%;
      text-align: center;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 64px;
      height: 64px;
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.3);
      border-radius: 20px;
      font-size: 28px;
      margin-bottom: 20px;
    }
    h1 { font-size: 20px; font-weight: 800; margin-bottom: 8px; color: #FFFFFF; }
    p { font-size: 14px; color: #94A3B8; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">⚠️</div>
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(message)}</p>
  </div>
</body>
</html>`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export const sharingController = new SharingController();

