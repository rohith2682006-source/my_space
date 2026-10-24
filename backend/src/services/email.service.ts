import nodemailer, { type Transporter } from 'nodemailer';

interface SendOtpOptions {
  to: string;
  otp: string;
  recipientName?: string;
}

export class EmailService {
  private static transporter: Transporter | null = null;

  private static getTransporter(): Transporter | null {
    if (this.transporter) return this.transporter;

    const host = process.env.SMTP_HOST;
    const port = parseInt(process.env.SMTP_PORT || '587', 10);
    const user = process.env.SMTP_USER || process.env.EMAIL_USER || 'rohithro.sg@gmail.com';
    const pass = process.env.SMTP_PASS || process.env.EMAIL_PASS || 'oarr ygnm tejc ssxz';
    const service = process.env.SMTP_SERVICE || 'gmail'; // e.g. 'gmail'

    if (service && user && pass) {
      const cleanPass = pass.replace(/\s+/g, '');
      this.transporter = nodemailer.createTransport({
        service,
        auth: { user: user.trim(), pass: cleanPass },
      });
      return this.transporter;
    }

    if (host && user && pass) {
      const cleanPass = pass.replace(/\s+/g, '');
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user: user.trim(), pass: cleanPass },
      });
      return this.transporter;
    }

    return null;
  }

  static async sendPasswordResetOtp({ to, otp, recipientName }: SendOtpOptions): Promise<{ sent: boolean; message: string }> {
    const transporter = this.getTransporter();

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

    if (transporter) {
      try {
        const fromAddress = process.env.SMTP_FROM || process.env.EMAIL_FROM || process.env.SMTP_USER || 'rohithro.sg@gmail.com';
        const info = await transporter.sendMail({
          from: `"Spaces Security" <${fromAddress}>`,
          to,
          subject,
          text,
          html,
        });
        console.log(`[EMAIL SENT] Password reset OTP sent successfully to ${to}. MessageId: ${info.messageId}`);
        return { sent: true, message: `OTP sent to ${to}` };
      } catch (err: any) {
        console.error(`[EMAIL ERROR] Failed to send email via SMTP:`, err.message);
        // Fallback to console
        console.log(`\n=========================================\n[FALLBACK OTP] OTP for ${to} is: ${otp}\n=========================================\n`);
        return { sent: false, message: `Email sending failed (${err.message}). Code: ${otp}` };
      }
    } else {
      // Realtime logging & dev delivery
      console.log(`\n=========================================\n[REALTIME OTP GENERATED]\nTo: ${to}\nOTP Code: ${otp}\nExpires: 10 minutes\n(Add SMTP_USER and SMTP_PASS in backend/.env for live inbox delivery)\n=========================================\n`);
      return { sent: true, message: `OTP generated for ${to}` };
    }
  }
}
