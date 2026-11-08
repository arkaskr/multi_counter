const assert = require('assert');
const config = require('../src/config');
const { connectDB, mongoose } = require('../src/db');
const User = require('../src/models/User');
const Otp = require('../src/models/Otp');
const DailyRecord = require('../src/models/DailyRecord');
const { sendOtpEmail } = require('../src/services/mailer');

async function runTests() {
  console.log('[Test] Connecting to test MongoDB Atlas...');
  await connectDB();

  try {
    // 1. Test Mailer dummy fallback
    console.log('[Test 1] Testing OTP Mailer fallback...');
    const mailResult = await sendOtpEmail('automated_test@example.com', '123456', 'Tester');
    assert.strictEqual(mailResult.success, true);
    console.log('  ✓ Mailer handled OTP dispatch cleanly');

    // 2. Test User Model CRUD
    console.log('[Test 2] Testing User model...');
    const testEmail = `test_${Date.now()}@example.com`;
    const user = await User.create({ name: 'Integration Tester', email: testEmail });
    assert.strictEqual(user.name, 'Integration Tester');
    assert.strictEqual(user.email, testEmail);
    console.log('  ✓ User created in MongoDB:', user._id.toString());

    // 3. Test OTP Model
    console.log('[Test 3] Testing OTP model...');
    const otp = await Otp.create({
      email: testEmail,
      otp: '654321',
      expiresAt: new Date(Date.now() + 60000),
    });
    assert.strictEqual(otp.otp, '654321');
    console.log('  ✓ OTP saved in MongoDB');

    // 4. Test DailyRecord sync model
    console.log('[Test 4] Testing DailyRecord sync model...');
    const rec = await DailyRecord.create({
      userId: user._id,
      date: '2026-11-08',
      count: 2,
      amountOverride: 90.0,
      updatedAt: new Date(),
    });
    assert.strictEqual(rec.count, 2);
    console.log('  ✓ Daily record synced to MongoDB');

    // Cleanup test data
    await DailyRecord.deleteMany({ userId: user._id });
    await Otp.deleteMany({ email: testEmail });
    await User.findByIdAndDelete(user._id);
    console.log('  ✓ Cleaned up test records');

    console.log('\n========================================');
    console.log('ALL BACKEND INTEGRATION TESTS PASSED!');
    console.log('========================================\n');
    process.exit(0);
  } catch (err) {
    console.error('Test error:', err);
    process.exit(1);
  }
}

runTests();

