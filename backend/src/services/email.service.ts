import dns from 'dns';
try {
  dns.setDefaultResultOrder('ipv4first');
} catch (_) {}

import nodemailer, { type Transporter } from 'nodemailer';
import { Resend } from 'resend';

interface SendOtpOptions {
  to: string;
  otp: string;
  recipientName?: string;
}

export class EmailService {
  private static transporter: Transporter | null = null;
  private static resendClient: Resend | null = null;

  static init(): void {
    this.getResendClient();
    this.getTransporter();
  }

  private static getResendClient(): Resend | null {
    if (this.resendClient) return this.resendClient;
    const key = process.env.RESEND_API_KEY;
    if (key && key.trim().startsWith('re_')) {
      this.resendClient = new Resend(key.trim());
      console.log('[EMAIL] High-speed Resend API client initialized.');
    }
    return this.resendClient;
  }

  private static getTransporter(): Transporter | null {
    if (this.transporter) return this.transporter;

    const host = process.env.SMTP_HOST || 'smtp.gmail.com';
    const port = parseInt(process.env.SMTP_PORT || '465', 10);
    const user = (process.env.SMTP_USER || process.env.EMAIL_USER || 'spacesro.official@gmail.com').trim();
    const rawPass = process.env.SMTP_PASS || process.env.EMAIL_PASS || 'oarr ygnm tejc ssxz';
    const cleanPass = rawPass.replace(/\s+/g, '');
    const isGmail = (process.env.SMTP_SERVICE || '').toLowerCase() === 'gmail' || host.includes('gmail');

    const poolOpts = { pool: true, maxConnections: 3, maxMessages: 100 } as const;

    if (isGmail) {
      this.transporter = nodemailer.createTransport({
        service: 'gmail',
        ...poolOpts,
        auth: { user, pass: cleanPass },
      });
    } else {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        ...poolOpts,
        auth: { user, pass: cleanPass },
      });
    }

    this.transporter.verify((err) => {
      if (err) {
        console.warn('[EMAIL] SMTP connection warning:', err.message);
      } else {
        console.log('[EMAIL] SMTP fallback transporter is verified and ready.');
      }
    });

    return this.transporter;
  }

  static async sendPasswordResetOtp({ to, otp, recipientName }: SendOtpOptions): Promise<{ sent: boolean; message: string }> {
    const startTime = Date.now();
    const subject = `${otp} is your Spaces verification code`;
    const text = `Hi ${recipientName || 'there'},\n\nYour Spaces password reset OTP is: ${otp}\n\nThis code will expire in 10 minutes.\nIf you did not request this, please ignore this email.`;
    const html = `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 520px; margin: 0 auto; padding: 32px 24px; background: #0F172A; color: #F8FAFC; border-radius: 16px; border: 1px solid #334155;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #A855F7; margin: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">Spaces</h2>
          <p style="color: #94A3B8; font-size: 14px; margin-top: 4px;">Password Reset Request</p>
        </div>
        <p style="font-size: 15px; color: #E2E8F0; line-height: 1.5;">Hi <strong>${recipientName || 'there'}</strong>,</p>
        <p style="font-size: 14px; color: #CBD5E1; line-height: 1.5;">Use the following 4-digit code to securely reset your password. This code is valid for <strong>10 minutes</strong>.</p>
        <div style="margin: 28px 0; text-align: center;">
          <span style="display: inline-block; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #FFFFFF; background: linear-gradient(135deg, #7C3AED, #A855F7); padding: 14px 28px; border-radius: 12px; box-shadow: 0 8px 24px rgba(168, 85, 247, 0.35);">${otp}</span>
        </div>
        <p style="font-size: 13px; color: #94A3B8; line-height: 1.5; text-align: center;">If you didn't ask to reset your password, you can safely ignore this email.</p>
        <hr style="border: none; border-top: 1px solid #1E293B; margin: 24px 0;" />
        <p style="font-size: 11px; color: #64748B; text-align: center; margin: 0;">Spaces Platform • Digital Organization & AI Search</p>
      </div>
    `;

    // ── 1. Priority: Resend Dedicated API (sub-second delivery) ────────
    const resend = this.getResendClient();
    if (resend) {
      try {
        const fromAddress = process.env.RESEND_FROM || 'Spaces Security <onboarding@resend.dev>';
        const replyTo = process.env.EMAIL_REPLY_TO || process.env.SMTP_USER || 'spacesro.official@gmail.com';
        const result = await resend.emails.send({
          from: fromAddress,
          replyTo: replyTo,
          to: [to],
          subject,
          text,
          html,
        });

        if (result.error) {
          console.warn(`[RESEND WARNING] Resend returned error (${result.error.message}). Falling back to SMTP...`);
        } else {
          const duration = Date.now() - startTime;
          console.log(`⚡ [RESEND SENT] OTP to ${to} in ${duration}ms! ID: ${result.data?.id}`);
          return { sent: true, message: `OTP sent via Resend to ${to}` };
        }
      } catch (err: any) {
        console.warn(`[RESEND ERROR] Resend dispatch failed: ${err.message}. Falling back to SMTP...`);
      }
    }

    // ── 2. Fallback: Persistent Pooled SMTP (Gmail) ────────────────────
    const transporter = this.getTransporter();
    if (transporter) {
      const fromAddress = process.env.SMTP_FROM || process.env.EMAIL_FROM || process.env.SMTP_USER || 'spacesro.official@gmail.com';
      const mail = {
        from: `"Spaces Security" <${fromAddress}>`,
        to,
        subject,
        text,
        html,
        priority: 'high' as const,
        headers: {
          'X-Priority': '1 (Highest)',
          'X-MSMail-Priority': 'High',
          'Importance': 'high',
        },
      };

      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          const info: any = await transporter.sendMail(mail);
          const duration = Date.now() - startTime;
          console.log(`[EMAIL SENT] OTP to ${to} via SMTP in ${duration}ms (attempt ${attempt}). MessageId: ${info?.messageId}`);
          return { sent: true, message: `OTP sent to ${to}` };
        } catch (err: any) {
          console.error(`[EMAIL ERROR] SMTP send attempt ${attempt} failed:`, err.message);
          if (attempt === 2) {
            return { sent: false, message: `Email sending failed (${err.message})` };
          }
        }
      }
      return { sent: false, message: 'Email sending failed' };
    }

    return { sent: false, message: 'No email service configured' };
  }
}
