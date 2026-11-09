const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const User = require('../models/User');
const Group = require('../models/Group');
const Expense = require('../models/Expense');

// All group routes require authentication
router.use(authMiddleware);

/**
 * Helper: Debt Simplification & Settlement Algorithm
 * Balances net amounts and matches debtors with creditors to minimize transactions.
 */
function calculateSettlements(acceptedMembers, expenses) {
  const memberBalances = {}; // email -> { name, email, userId, netBalance, totalPaid, totalShare }

  for (const m of acceptedMembers) {
    const email = m.email.toLowerCase();
    memberBalances[email] = {
      name: m.name,
      email: email,
      userId: m.user ? m.user.toString() : null,
      totalPaid: 0,
      totalShare: 0,
      netBalance: 0,
    };
  }

  // Calculate totals from expenses
  for (const exp of expenses) {
    const paidByEmail = (exp.paidByEmail || '').toLowerCase();
    if (memberBalances[paidByEmail]) {
      memberBalances[paidByEmail].totalPaid += exp.amount;
    }

    if (exp.splits && exp.splits.length > 0) {
      for (const s of exp.splits) {
        const splitEmail = (s.email || '').toLowerCase();
        if (memberBalances[splitEmail]) {
          memberBalances[splitEmail].totalShare += s.shareAmount;
        }
      }
    }
  }

  // Calculate net balances (Net = TotalPaid - TotalShare)
  const debtors = [];
  const creditors = [];

  for (const email of Object.keys(memberBalances)) {
    const item = memberBalances[email];
    item.netBalance = Math.round((item.totalPaid - item.totalShare) * 100) / 100;

    if (item.netBalance > 0.01) {
      creditors.push({ ...item, remaining: item.netBalance });
    } else if (item.netBalance < -0.01) {
      debtors.push({ ...item, remaining: Math.abs(item.netBalance) });
    }
  }

  // Sort: biggest debtor first, biggest creditor first
  creditors.sort((a, b) => b.remaining - a.remaining);
  debtors.sort((a, b) => b.remaining - a.remaining);

  const settlements = [];
  let dIdx = 0;
  let cIdx = 0;

  while (dIdx < debtors.length && cIdx < creditors.length) {
    const debtor = debtors[dIdx];
    const creditor = creditors[cIdx];

    const amount = Math.min(debtor.remaining, creditor.remaining);
    const roundedAmount = Math.round(amount * 100) / 100;

    if (roundedAmount > 0.01) {
      settlements.push({
        fromEmail: debtor.email,
        fromName: debtor.name,
        fromUserId: debtor.userId,
        toEmail: creditor.email,
        toName: creditor.name,
        toUserId: creditor.userId,
        amount: roundedAmount,
      });
    }

    debtor.remaining = Math.round((debtor.remaining - amount) * 100) / 100;
    creditor.remaining = Math.round((creditor.remaining - amount) * 100) / 100;

    if (debtor.remaining <= 0.01) dIdx++;
    if (creditor.remaining <= 0.01) cIdx++;
  }

  return {
    balances: Object.values(memberBalances),
    settlements,
  };
}

/**
 * Helper: Calculate Group Spending Analytics
 */
function calculateAnalytics(group, expenses, currentEmail) {
  const acceptedMembers = group.members.filter((m) => m.status === 'accepted');
  const { balances, settlements } = calculateSettlements(acceptedMembers, expenses);

  const totalSpend = expenses.reduce((sum, e) => sum + e.amount, 0);
  const myEmail = (currentEmail || '').toLowerCase();
  const myStat = balances.find((b) => b.email === myEmail) || {
    totalPaid: 0,
    totalShare: 0,
    netBalance: 0,
  };

  // Category breakdown
  const categoryTotals = {};
  for (const e of expenses) {
    const cat = e.category || 'Other';
    categoryTotals[cat] = (categoryTotals[cat] || 0) + e.amount;
  }

  const categoryBreakdown = Object.keys(categoryTotals).map((cat) => ({
    category: cat,
    totalAmount: Math.round(categoryTotals[cat] * 100) / 100,
    percentage: totalSpend > 0 ? Math.round((categoryTotals[cat] / totalSpend) * 1000) / 10 : 0,
  }));
  categoryBreakdown.sort((a, b) => b.totalAmount - a.totalAmount);

  // Member spend breakdown
  const memberBreakdown = balances.map((b) => ({
    name: b.name,
    email: b.email,
    userId: b.userId,
    totalPaid: Math.round(b.totalPaid * 100) / 100,
    totalShare: Math.round(b.totalShare * 100) / 100,
    netBalance: Math.round(b.netBalance * 100) / 100,
    percentageOfTotalPaid: totalSpend > 0 ? Math.round((b.totalPaid / totalSpend) * 1000) / 10 : 0,
  }));
  memberBreakdown.sort((a, b) => b.totalPaid - a.totalPaid);

  return {
    totalSpend: Math.round(totalSpend * 100) / 100,
    expenseCount: expenses.length,
    myTotalPaid: Math.round(myStat.totalPaid * 100) / 100,
    myTotalShare: Math.round(myStat.totalShare * 100) / 100,
    myNetBalance: Math.round(myStat.netBalance * 100) / 100,
    categoryBreakdown,
    memberBreakdown,
    settlements,
  };
}

/**
 * 1. POST /api/groups - Create a new group
 */
router.post('/', async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Group name is required.' });
    }

    const newGroup = new Group({
      name: name.trim(),
      description: (description || '').trim(),
      createdBy: req.user._id,
      createdByName: req.user.name,
      createdByEmail: req.user.email.toLowerCase(),
      members: [
        {
          user: req.user._id,
          email: req.user.email.toLowerCase(),
          name: req.user.name,
          status: 'accepted',
          role: 'admin',
          joinedAt: new Date(),
        },
      ],
    });

    await newGroup.save();

    res.status(201).json({
      success: true,
      message: 'Group created successfully.',
      group: newGroup,
    });
  } catch (err) {
    console.error('[Groups] Create group error:', err);
    res.status(500).json({ success: false, message: 'Failed to create group: ' + err.message });
  }
});

/**
 * 2. GET /api/groups - List user's groups & pending invitations
 */
router.get('/', async (req, res) => {
  try {
    const userEmail = req.user.email.toLowerCase();

    // Groups where user is accepted
    const myGroups = await Group.find({
      members: {
        $elemMatch: {
          email: userEmail,
          status: 'accepted',
        },
      },
    }).sort({ updatedAt: -1 });

    // Pending invitations for user
    const pendingInvitations = await Group.find({
      members: {
        $elemMatch: {
          email: userEmail,
          status: 'pending',
        },
      },
    }).sort({ createdAt: -1 });

    // Attach summary stats to myGroups
    const groupsWithStats = await Promise.all(
      myGroups.map(async (group) => {
        const expenses = await Expense.find({ group: group._id });
        const acceptedMembers = group.members.filter((m) => m.status === 'accepted');
        const { balances } = calculateSettlements(acceptedMembers, expenses);
        const myStat = balances.find((b) => b.email === userEmail) || { netBalance: 0, totalPaid: 0 };
        const totalSpend = expenses.reduce((s, e) => s + e.amount, 0);

        return {
          ...group.toObject(),
          totalSpend: Math.round(totalSpend * 100) / 100,
          myNetBalance: Math.round(myStat.netBalance * 100) / 100,
          expenseCount: expenses.length,
          acceptedMemberCount: acceptedMembers.length,
        };
      })
    );

    res.json({
      success: true,
      groups: groupsWithStats,
      pendingInvitations,
    });
  } catch (err) {
    console.error('[Groups] List groups error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch groups: ' + err.message });
  }
});

/**
 * 3. GET /api/groups/:id - Get details of a single group
 */
router.get('/:id', async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const currentMember = group.members.find((m) => m.email.toLowerCase() === userEmail);
    if (!currentMember) {
      return res.status(403).json({ success: false, message: 'You are not a member of this group.' });
    }

    const expenses = await Expense.find({ group: group._id }).sort({ date: -1 });
    const acceptedMembers = group.members.filter((m) => m.status === 'accepted');
    const pendingMembers = group.members.filter((m) => m.status === 'pending');

    const analytics = calculateAnalytics(group, expenses, userEmail);

    res.json({
      success: true,
      group: group.toObject(),
      membershipStatus: currentMember.status,
      role: currentMember.role,
      acceptedMembers,
      pendingMembers,
      analytics,
      recentExpenses: expenses.slice(0, 50),
    });
  } catch (err) {
    console.error('[Groups] Get group error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch group details: ' + err.message });
  }
});

/**
 * 4. POST /api/groups/:id/invite - Invite someone by registered email
 */
router.post('/:id/invite', async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const callerEmail = req.user.email.toLowerCase();
    const caller = group.members.find((m) => m.email.toLowerCase() === callerEmail && m.status === 'accepted');
    if (!caller) {
      return res.status(403).json({ success: false, message: 'Only active group members can invite others.' });
    }

    const { email } = req.body;
    if (!email || !email.includes('@')) {
      return res.status(400).json({ success: false, message: 'A valid email address is required.' });
    }

    const inviteeEmail = email.toLowerCase().trim();

    // Check if user is already a member or pending
    const existing = group.members.find((m) => m.email.toLowerCase() === inviteeEmail);
    if (existing) {
      if (existing.status === 'accepted') {
        return res.status(400).json({ success: false, message: 'This user is already a member of the group.' });
      } else if (existing.status === 'pending') {
        return res.status(400).json({ success: false, message: 'An invitation is already pending for this email.' });
      }
    }

    // Check if registered user exists
    const registeredUser = await User.findOne({ email: inviteeEmail });
    const inviteeName = registeredUser ? registeredUser.name : inviteeEmail.split('@')[0];

    group.members.push({
      user: registeredUser ? registeredUser._id : null,
      email: inviteeEmail,
      name: inviteeName,
      status: 'pending',
      role: 'member',
      joinedAt: new Date(),
    });

    await group.save();

    res.json({
      success: true,
      message: `Invitation sent to ${inviteeEmail}. They will see this request in their app to accept.`,
      group,
    });
  } catch (err) {
    console.error('[Groups] Invite member error:', err);
    res.status(500).json({ success: false, message: 'Failed to invite member: ' + err.message });
  }
});

/**
 * 5. POST /api/groups/:id/respond - Accept or Decline group invitation
 */
router.post('/:id/respond', async (req, res) => {
  try {
    const { action } = req.body; // 'accept' or 'decline'
    if (!['accept', 'decline', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, message: 'Action must be accept or decline.' });
    }

    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const memberIndex = group.members.findIndex((m) => m.email.toLowerCase() === userEmail);

    if (memberIndex === -1) {
      return res.status(404).json({ success: false, message: 'No invitation found for your email in this group.' });
    }

    if (action === 'accept') {
      group.members[memberIndex].status = 'accepted';
      group.members[memberIndex].user = req.user._id;
      group.members[memberIndex].name = req.user.name;
      group.members[memberIndex].joinedAt = new Date();
    } else {
      // Remove or set rejected
      group.members.splice(memberIndex, 1);
    }

    await group.save();

    res.json({
      success: true,
      message: action === 'accept' ? 'You have joined the group!' : 'Invitation declined.',
      group,
    });
  } catch (err) {
    console.error('[Groups] Respond invite error:', err);
    res.status(500).json({ success: false, message: 'Failed to respond to invitation: ' + err.message });
  }
});

/**
 * 6. GET /api/groups/:id/expenses - List all expenses of a group
 */
router.get('/:id/expenses', async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const isMember = group.members.some((m) => m.email.toLowerCase() === userEmail && m.status === 'accepted');
    if (!isMember) {
      return res.status(403).json({ success: false, message: 'Access denied. You must be an accepted member.' });
    }

    const expenses = await Expense.find({ group: group._id }).sort({ date: -1 });
    res.json({ success: true, expenses });
  } catch (err) {
    console.error('[Groups] List expenses error:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch expenses: ' + err.message });
  }
});

/**
 * 7. POST /api/groups/:id/expenses - Add an expense
 * User enters what they paid, with amount, tag/title, note, and optional custom splits.
 */
router.post('/:id/expenses', async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const currentMember = group.members.find((m) => m.email.toLowerCase() === userEmail && m.status === 'accepted');
    if (!currentMember) {
      return res.status(403).json({ success: false, message: 'Only accepted members can add expenses.' });
    }

    const { title, amount, category, date, note, customSplits } = req.body;
    const numAmount = parseFloat(amount);
    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Expense title is required.' });
    }
    if (isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({ success: false, message: 'A valid positive amount is required.' });
    }

    const acceptedMembers = group.members.filter((m) => m.status === 'accepted');
    if (acceptedMembers.length === 0) {
      return res.status(400).json({ success: false, message: 'No active members in group to split with.' });
    }

    let finalSplits = [];

    if (Array.isArray(customSplits) && customSplits.length > 0) {
      // Custom splits provided by user
      finalSplits = customSplits.map((s) => ({
        user: s.user || null,
        email: s.email.toLowerCase().trim(),
        name: s.name || s.email,
        shareAmount: Math.round(parseFloat(s.shareAmount) * 100) / 100,
      }));
    } else {
      // Default: Equal split among ALL accepted members
      const splitCount = acceptedMembers.length;
      const baseShare = Math.floor((numAmount / splitCount) * 100) / 100;
      let remainder = Math.round((numAmount - baseShare * splitCount) * 100) / 100;

      finalSplits = acceptedMembers.map((m) => {
        let share = baseShare;
        if (remainder > 0.005) {
          share = Math.round((share + 0.01) * 100) / 100;
          remainder = Math.round((remainder - 0.01) * 100) / 100;
        }
        return {
          user: m.user,
          email: m.email.toLowerCase(),
          name: m.name,
          shareAmount: share,
        };
      });
    }

    const expense = new Expense({
      group: group._id,
      title: title.trim(),
      amount: Math.round(numAmount * 100) / 100,
      category: category || 'Food',
      paidBy: req.user._id,
      paidByName: req.user.name,
      paidByEmail: userEmail,
      splits: finalSplits,
      note: (note || '').trim(),
      date: date ? new Date(date) : new Date(),
    });

    await expense.save();

    // Touch group updatedAt
    group.updatedAt = new Date();
    await group.save();

    res.status(201).json({
      success: true,
      message: 'Expense added successfully.',
      expense,
    });
  } catch (err) {
    console.error('[Groups] Add expense error:', err);
    res.status(500).json({ success: false, message: 'Failed to add expense: ' + err.message });
  }
});

/**
 * 8. DELETE /api/groups/:id/expenses/:expenseId - Delete expense
 */
router.delete('/:id/expenses/:expenseId', async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.expenseId);
    if (!expense) {
      return res.status(404).json({ success: false, message: 'Expense not found.' });
    }

    const group = await Group.findById(expense.group);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const isPayer = expense.paidByEmail.toLowerCase() === userEmail;
    const isGroupAdmin = group.createdByEmail.toLowerCase() === userEmail;

    if (!isPayer && !isGroupAdmin) {
      return res.status(403).json({ success: false, message: 'Only the payer or group admin can delete this expense.' });
    }

    await Expense.findByIdAndDelete(expense._id);

    res.json({ success: true, message: 'Expense deleted successfully.' });
  } catch (err) {
    console.error('[Groups] Delete expense error:', err);
    res.status(500).json({ success: false, message: 'Failed to delete expense: ' + err.message });
  }
});

/**
 * 9. GET /api/groups/:id/analytics - Detailed Analytics Report
 */
router.get('/:id/analytics', async (req, res) => {
  try {
    const group = await Group.findById(req.params.id);
    if (!group) {
      return res.status(404).json({ success: false, message: 'Group not found.' });
    }

    const userEmail = req.user.email.toLowerCase();
    const isMember = group.members.some((m) => m.email.toLowerCase() === userEmail && m.status === 'accepted');
    if (!isMember) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const expenses = await Expense.find({ group: group._id }).sort({ date: -1 });
    const analytics = calculateAnalytics(group, expenses, userEmail);

    res.json({
      success: true,
      analytics,
    });
  } catch (err) {
    console.error('[Groups] Get analytics error:', err);
    res.status(500).json({ success: false, message: 'Failed to compute analytics: ' + err.message });
  }
});

module.exports = router;

