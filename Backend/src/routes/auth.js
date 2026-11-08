const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const config = require('../config');
const User = require('../models/User');
const Otp = require('../models/Otp');
const { sendOtpEmail } = require('../services/mailer');

/**
 * Generate a random 6-digit OTP string
 */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * POST /api/auth/send-otp
 * Body: { email, name, mode }
 * mode: 'login' | 'register' (optional, defaults to auto-detect)
 */
router.post('/send-otp', async (req, res) => {
  try {
    const { email, name, mode } = req.body;

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ success: false, message: 'Valid email address is required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    let cleanName = (name || '').trim();

    // Basic email validation regex
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(cleanEmail)) {
      return res.status(400).json({ success: false, message: 'Invalid email format.' });
    }

    const existingUser = await User.findOne({ email: cleanEmail });

    // Handle Login mode: require user to already be registered
    if (mode === 'login') {
      if (!existingUser) {
        return res.status(404).json({
          success: false,
          isNotRegistered: true,
          message: 'No account found with this email. Please register first.',
        });
      }
      cleanName = existingUser.name;
    }

    // Handle Register mode: check if email is already registered
    if (mode === 'register') {
      if (existingUser) {
        return res.status(409).json({
          success: false,
          isAlreadyRegistered: true,
          message: 'An account with this email already exists. Please log in instead.',
        });
      }
      if (!cleanName) {
        return res.status(400).json({
          success: false,
          message: 'Please enter your name to register.',
        });
      }
    }

    // If no mode specified, auto-populate name from existing user if available
    if (!cleanName && existingUser) {
      cleanName = existingUser.name;
    }

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Upsert OTP record
    await Otp.findOneAndUpdate(
      { email: cleanEmail },
      { email: cleanEmail, name: cleanName, otp, expiresAt },
      { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true }
    );

    // Send via Nodemailer
    const mailResult = await sendOtpEmail(cleanEmail, otp, cleanName);

    return res.status(200).json({
      success: true,
      message: 'OTP has been generated and sent to your email.',
      email: cleanEmail,
      isRegistered: !!existingUser,
      userName: cleanName || undefined,
      emailSent: mailResult.emailSent,
      // Provide OTP in response only if SMTP failed or dummy credentials detected to facilitate local testing
      devOtp: !mailResult.emailSent ? otp : undefined,
    });
  } catch (err) {
    console.error('[Auth] send-otp error:', err);
    return res.status(500).json({ success: false, message: 'Failed to send OTP. Please try again.' });
  }
});

/**
 * POST /api/auth/verify-otp
 * Body: { email, otp, name }
 */
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, otp, name } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and OTP are required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp.toString().trim();

    // Find the latest valid OTP
    const otpRecord = await Otp.findOne({
      email: cleanEmail,
      otp: cleanOtp,
      expiresAt: { $gt: new Date() },
    });

    if (!otpRecord) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired OTP code. Please request a new one.',
      });
    }

    // OTP is valid! Delete used OTP
    await Otp.deleteMany({ email: cleanEmail });

    // Find or create User
    let user = await User.findOne({ email: cleanEmail });
    if (!user) {
      user = new User({
        name: (name || otpRecord.name || cleanEmail.split('@')[0]).trim(),
        email: cleanEmail,
      });
      await user.save();
      console.log(`[Auth] New user registered: ${user.name} (${user.email})`);
    } else if (name && name.trim() && user.name !== name.trim()) {
      user.name = name.trim();
      await user.save();
    }

    // Generate JWT token (valid for 30 days)
    const token = jwt.sign(
      { userId: user._id, email: user.email },
      config.jwtSecret,
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      success: true,
      message: 'Authentication successful.',
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    console.error('[Auth] verify-otp error:', err);
    return res.status(500).json({ success: false, message: 'Verification failed. Please try again.' });
  }
});

module.exports = router;
