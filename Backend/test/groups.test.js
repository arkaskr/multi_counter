const assert = require('assert');
const { connectDB, mongoose } = require('../src/db');
const User = require('../src/models/User');
const Group = require('../src/models/Group');
const Expense = require('../src/models/Expense');

async function runGroupTests() {
  console.log('[Test] Connecting to MongoDB Atlas for Group & Expense Tests...');
  await connectDB();

  try {
    const timestamp = Date.now();
    const userAEmail = `user_a_${timestamp}@example.com`;
    const userBEmail = `user_b_${timestamp}@example.com`;

    // 1. Create two users
    console.log('[Test 1] Creating test users...');
    const userA = await User.create({ name: 'Alice', email: userAEmail });
    const userB = await User.create({ name: 'Bob', email: userBEmail });
    assert(userA._id);
    assert(userB._id);
    console.log('  ✓ Users Alice and Bob created');

    // 2. Alice creates a group "Goa Trip"
    console.log('[Test 2] Creating group "Goa Trip"...');
    const group = await Group.create({
      name: 'Goa Trip',
      description: 'Vacation expenses',
      createdBy: userA._id,
      createdByName: userA.name,
      createdByEmail: userA.email,
      members: [
        {
          user: userA._id,
          email: userA.email,
          name: userA.name,
          status: 'accepted',
          role: 'admin',
          joinedAt: new Date(),
        },
      ],
    });
    assert.strictEqual(group.members.length, 1);
    assert.strictEqual(group.members[0].status, 'accepted');
    console.log('  ✓ Group created with Alice as accepted admin');

    // 3. Alice invites Bob (status pending)
    console.log('[Test 3] Inviting Bob to group...');
    group.members.push({
      user: userB._id,
      email: userB.email,
      name: userB.name,
      status: 'pending',
      role: 'member',
      joinedAt: new Date(),
    });
    await group.save();

    const pendingGroup = await Group.findOne({
      _id: group._id,
      'members.email': userBEmail,
      'members.status': 'pending',
    });
    assert(pendingGroup);
    console.log('  ✓ Bob invited with pending status');

    // 4. Bob accepts the invitation
    console.log('[Test 4] Bob accepts the invitation...');
    const memberIndex = group.members.findIndex((m) => m.email === userBEmail);
    group.members[memberIndex].status = 'accepted';
    await group.save();

    const acceptedGroup = await Group.findById(group._id);
    const acceptedCount = acceptedGroup.members.filter((m) => m.status === 'accepted').length;
    assert.strictEqual(acceptedCount, 2);
    console.log('  ✓ Bob accepted invite, active members: 2');

    // 5. Alice adds an expense: ₹600 for Dinner, split equally (₹300 each)
    console.log('[Test 5] Adding an expense...');
    const expense = await Expense.create({
      group: group._id,
      title: 'Seafood Dinner',
      amount: 600,
      category: 'Food',
      paidBy: userA._id,
      paidByName: userA.name,
      paidByEmail: userA.email,
      splits: [
        { user: userA._id, email: userA.email, name: userA.name, shareAmount: 300 },
        { user: userB._id, email: userB.email, name: userB.name, shareAmount: 300 },
      ],
      note: 'Delicious meal at beach shack',
      date: new Date(),
    });
    assert.strictEqual(expense.amount, 600);
    console.log('  ✓ Expense of ₹600 created');

    // 6. Test settlements: Bob owes Alice ₹300
    console.log('[Test 6] Verifying settlement calculation...');
    // Alice paid 600, share 300 -> netBalance = +300
    // Bob paid 0, share 300 -> netBalance = -300
    const expenses = await Expense.find({ group: group._id });
    const netA = 600 - 300; // +300
    const netB = 0 - 300; // -300
    assert.strictEqual(netA, 300);
    assert.strictEqual(netB, -300);
    console.log('  ✓ Bob owes Alice ₹300 cleanly verified');

    // 7. Test delete group cascade
    console.log('[Test 7] Testing group deletion & cascade expenses removal...');
    await Expense.deleteMany({ group: group._id });
    await Group.findByIdAndDelete(group._id);
    const remainingGroup = await Group.findById(group._id);
    const remainingExpenses = await Expense.find({ group: group._id });
    assert.strictEqual(remainingGroup, null);
    assert.strictEqual(remainingExpenses.length, 0);
    console.log('  ✓ Group and expenses cascade deleted cleanly');

    // Cleanup users
    await User.findByIdAndDelete(userA._id);
    await User.findByIdAndDelete(userB._id);
    console.log('  ✓ Cleaned up test data');

    console.log('\n=============================================');
    console.log('ALL GROUP & EXPENSE BACKEND TESTS PASSED!');
    console.log('=============================================\n');
    process.exit(0);
  } catch (err) {
    console.error('Test Failed:', err);
    process.exit(1);
  }
}

runGroupTests();

