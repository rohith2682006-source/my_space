import { Response } from 'express';

export class RealtimeService {
  private static userClients = new Map<string, Set<Response>>();
  private static heartbeatStarted = false;

  /**
   * Subscribe an authenticated HTTP response to the SSE stream.
   */
  static subscribe(userId: string, res: Response): void {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof (res as any).flushHeaders === 'function') {
      (res as any).flushHeaders();
    }

    if (!this.heartbeatStarted) {
      this.startHeartbeat();
      this.heartbeatStarted = true;
    }

    if (!this.userClients.has(userId)) {
      this.userClients.set(userId, new Set());
    }
    const clientSet = this.userClients.get(userId)!;
    clientSet.add(res);

    // Initial connection event
    res.write(`event: CONNECTED\ndata: ${JSON.stringify({ message: 'Realtime SSE stream connected', userId, timestamp: new Date().toISOString() })}\n\n`);

    // Clean up on disconnect
    res.on('close', () => {
      clientSet.delete(res);
      if (clientSet.size === 0) {
        this.userClients.delete(userId);
      }
    });
  }

  /**
   * Broadcast an event to all active sessions of a given user.
   */
  static emitToUser(userId: string, event: string, data: Record<string, unknown>): void {
    const clients = this.userClients.get(userId);
    if (!clients || clients.size === 0) return;

    const payload = `event: ${event}\ndata: ${JSON.stringify({ ...data, event, timestamp: new Date().toISOString() })}\n\n`;
    for (const res of clients) {
      try {
        res.write(payload);
      } catch {
        clients.delete(res);
      }
    }
  }

  /**
   * Broadcast an event to multiple user IDs.
   */
  static emitToUsers(userIds: string[], event: string, data: Record<string, unknown>): void {
    for (const userId of userIds) {
      this.emitToUser(userId, event, data);
    }
  }

  /**
   * Periodic keep-alive heartbeat.
   */
  private static startHeartbeat(): void {
    setInterval(() => {
      for (const [, clients] of this.userClients) {
        for (const res of clients) {
          try {
            res.write(': heartbeat\n\n');
          } catch {
            clients.delete(res);
          }
        }
      }
    }, 25_000).unref();
  }
}
