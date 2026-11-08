const nodemailer = require('nodemailer');
const config = require('../config');

let transporter = null;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.secure,
      auth: {
        user: config.smtp.user,
        pass: config.smtp.pass,
      },
      tls: {
        rejectUnauthorized: false,
      },
    });
  }
  return transporter;
}

/**
 * Sends a 6-digit OTP code to the specified email address.
 * If SMTP fails (e.g. dummy credentials), logs the OTP clearly in server console
 * and returns info gracefully without throwing.
 */
async function sendOtpEmail(email, otp, name) {
  const recipientName = name ? name.trim() : 'User';
  const mailOptions = {
    from: config.smtp.from,
    to: email,
    subject: `${otp} is your Daily Counter Verification Code`,
    text: `Hello ${recipientName},\n\nYour verification code for Daily Counter is: ${otp}\n\nThis code will expire in 10 minutes.\n\nIf you did not request this code, you can safely ignore this email.\n\nBest regards,\nDaily Counter Team`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; background: #f8fafc; border-radius: 16px; border: 1px solid #e2e8f0;">
        <h2 style="color: #1e293b; margin-top: 0;">Daily Counter Verification</h2>
        <p style="color: #475569; font-size: 15px;">Hello <strong>${recipientName}</strong>,</p>
        <p style="color: #475569; font-size: 15px;">Use the following 6-digit code to complete your login or registration:</p>
        <div style="text-align: center; margin: 28px 0;">
          <span style="display: inline-block; font-size: 32px; font-weight: 800; letter-spacing: 6px; padding: 12px 28px; background: #3b82f6; color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);">
            ${otp}
          </span>
        </div>
        <p style="color: #64748b; font-size: 13px;">This code will expire in <strong>10 minutes</strong>. Never share this code with anyone.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
        <p style="color: #94a3b8; font-size: 11px; text-align: center;">Daily Counter &bull; Offline & Cloud Meal Tracker</p>
      </div>
    `,
  };

  try {
    const info = await getTransporter().sendMail(mailOptions);
    console.log(`[Mailer] OTP email successfully sent to ${email} (MessageId: ${info.messageId})`);
    return { success: true, messageId: info.messageId, emailSent: true };
  } catch (err) {
    console.warn(`[Mailer] Could not send email via SMTP (${err.message}).`);
    console.log(`\n======================================================`);
    console.log(`[DEVELOPMENT / DUMMY SMTP FALLBACK]`);
    console.log(`Recipient: ${email} (${recipientName})`);
    console.log(`OTP Code:  >>> ${otp} <<<`);
    console.log(`Expires:   in 10 minutes`);
    console.log(`======================================================\n`);
    return {
      success: true,
      emailSent: false,
      note: 'SMTP error caught; OTP logged to server console (dummy credentials mode)',
    };
  }
}

module.exports = { sendOtpEmail };

