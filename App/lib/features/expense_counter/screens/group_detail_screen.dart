import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../providers/expense_providers.dart';
import 'add_expense_screen.dart';
import 'invite_member_dialog.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.directions_car_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'rent':
        return Icons.home_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_filter_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _handleInvite() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => InviteMemberDialog(groupId: widget.groupId),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.green[700]),
      );
    }
  }

  Future<void> _handleDeleteExpense(ExpenseModel expense) async {
    final theme = context.appTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Expense?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text('Delete "${expense.title}" of ₹${expense.amount}?', style: TextStyle(color: theme.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final service = ref.read(expenseServiceProvider);
        await service.deleteExpense(widget.groupId, expense.id);
        ref.invalidate(groupDetailProvider(widget.groupId));
        ref.invalidate(groupsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception:', '')), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final authState = ref.watch(authStateProvider);
    final myEmail = authState.user?.email.toLowerCase() ?? '';

    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: CircularProgressIndicator(color: theme.accent),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.text),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  err.toString().replaceAll('Exception:', '').trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.text, fontSize: 16),
                ),
                const SizedBox(height: 16),
                NeumorphicButton(
                  onTap: () => ref.invalidate(groupDetailProvider(widget.groupId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        final group = data.group;
        final analytics = data.analytics;
        final expenses = data.expenses;
        final myNet = analytics.myNetBalance;

        return Scaffold(
          backgroundColor: theme.background,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: theme.accent,
            elevation: 4,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Add Expense',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(group: group),
                ),
              );
            },
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Row
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: theme.secondaryText),
                              const SizedBox(width: 4),
                              Icon(Icons.groups_rounded, size: 14, color: theme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Groups',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _handleInvite,
                            child: NeumorphicContainer(
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_add_alt_1_rounded, size: 14, color: theme.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Invite',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => ref.invalidate(groupDetailProvider(widget.groupId)),
                            child: NeumorphicContainer(
                              borderRadius: 14,
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.refresh_rounded, size: 14, color: theme.accent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Header Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GROUP DETAILS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Hero Card: Total Spend & My Net Balance
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NeumorphicContainer(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL GROUP SPEND',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: theme.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyUtils.formatCurrency(analytics.totalSpend, '₹'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: theme.text,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: myNet > 0.01
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : (myNet < -0.01
                                        ? Colors.redAccent.withValues(alpha: 0.15)
                                        : theme.secondaryText.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: myNet > 0.01
                                      ? Colors.green.withValues(alpha: 0.4)
                                      : (myNet < -0.01
                                          ? Colors.redAccent.withValues(alpha: 0.4)
                                          : theme.secondaryText.withValues(alpha: 0.2)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    myNet > 0.01
                                        ? 'YOU ARE OWED'
                                        : (myNet < -0.01 ? 'YOU OWE' : 'SETTLED'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: myNet > 0.01
                                          ? Colors.green[400]
                                          : (myNet < -0.01 ? Colors.redAccent : theme.secondaryText),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    myNet > 0.01
                                        ? '+₹${myNet.toStringAsFixed(0)}'
                                        : (myNet < -0.01
                                            ? '-₹${myNet.abs().toStringAsFixed(0)}'
                                            : '₹0'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: myNet > 0.01
                                          ? Colors.green[400]
                                          : (myNet < -0.01 ? Colors.redAccent : theme.secondaryText),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: theme.secondaryText.withValues(alpha: 0.12)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat('You Paid', CurrencyUtils.formatCurrency(analytics.myTotalPaid, '₹'), theme),
                            _buildMiniStat('Your Fair Share', CurrencyUtils.formatCurrency(analytics.myTotalShare, '₹'), theme),
                            _buildMiniStat('Members', '${group.acceptedMembers.length}', theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Pinned Tab Bar (ALWAYS VISIBLE & PERFECTLY FORMATTED)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: theme.secondaryText,
                      labelPadding: EdgeInsets.zero,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Settlement'),
                        Tab(text: 'Analytics'),
                        Tab(text: 'Members'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Expanded Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: EXPENSES LIST
                      _buildExpensesTab(expenses, myEmail, theme),

                      // TAB 2: SETTLEMENTS ("WHO OWES WHOM")
                      _buildSettlementsTab(analytics.settlements, myEmail, theme),

                      // TAB 3: ANALYTICS
                      _buildAnalyticsTab(analytics, theme),

                      // TAB 4: MEMBERS & INVITATIONS
                      _buildMembersTab(group, myEmail, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, dynamic theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.secondaryText),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.text),
        ),
      ],
    );
  }

  Widget _buildExpensesTab(List<ExpenseModel> expenses, String myEmail, dynamic theme) {
    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 54, color: theme.secondaryText.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                'No expenses logged yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "+ Add Expense" below whenever someone pays for the group.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final exp = expenses[index];
        final isPayer = exp.paidByEmail.toLowerCase() == myEmail;
        final dateStr = AppDateUtils.formatShortDate(
          '${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}-${exp.date.day.toString().padLeft(2, '0')}',
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NeumorphicContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getCategoryIcon(exp.category), color: theme.accent, size: 22),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            isPayer ? 'You paid' : '${exp.paidByName} paid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPayer ? Colors.green[400] : theme.secondaryText,
                            ),
                          ),
                          Text(' • $dateStr', style: TextStyle(fontSize: 11, color: theme.secondaryText)),
                        ],
                      ),
                      if (exp.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exp.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),

                // Amount & Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.formatCurrency(exp.amount, '₹'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                    if (isPayer) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _handleDeleteExpense(exp),
                        child: Text(
                          'Delete',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red[300]),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab(List<SettlementDebt> settlements, String myEmail, dynamic theme) {
    if (settlements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
              ),
              const SizedBox(height: 16),
              Text(
                'All Settled Up!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.text),
              ),
              const SizedBox(height: 6),
              Text(
                'No one owes any money. The group balance is zero.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 80),
      physics: const BouncingScrollPhysics(),
      children: [
        NeumorphicContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Debts are mathematically simplified to clear all group balances with the fewest possible payments.',
                  style: TextStyle(fontSize: 12, color: theme.secondaryText, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...settlements.map((debt) {
          final isPayer = debt.fromEmail.toLowerCase() == myEmail;
          final isReceiver = debt.toEmail.toLowerCase() == myEmail;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Debtor circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPayer ? Colors.redAccent.withValues(alpha: 0.15) : theme.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        debt.fromName.isNotEmpty ? debt.fromName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPayer ? Colors.redAccent : theme.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Debt Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: theme.text),
                            children: [
                              TextSpan(
                                text: isPayer ? 'You' : debt.fromName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const TextSpan(text: ' owes '),
                              TextSpan(
                                text: isReceiver ? 'You' : debt.toName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isReceiver ? Colors.green[400] : theme.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPayer
                              ? 'You need to pay ${debt.toName}'
                              : (isReceiver ? '${debt.fromName} should pay you' : 'Settlement between members'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isPayer ? Colors.redAccent : (isReceiver ? Colors.green[400] : theme.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPayer
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : (isReceiver ? Colors.green.withValues(alpha: 0.15) : theme.accent.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      CurrencyUtils.formatCurrency(debt.amount, '₹'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isPayer
                            ? Colors.redAccent
                            : (isReceiver ? Colors.green[400] : theme.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAnalyticsTab(ExpenseAnalyticsReport analytics, dynamic theme) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 80),
      physics: const BouncingScrollPhysics(),
      children: [
        // Category Breakdown Card
        Text(
          'SPENDING BY CATEGORY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        NeumorphicContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          child: analytics.categoryBreakdown.isEmpty
              ? Text('No category data available', style: TextStyle(color: theme.secondaryText))
              : Column(
                  children: analytics.categoryBreakdown.map((cat) {
                    final percent = (cat.percentage / 100.0).clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_getCategoryIcon(cat.category), size: 16, color: theme.accent),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.category,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
                                  ),
                                ],
                              ),
                              Text(
                                '${CurrencyUtils.formatCurrency(cat.totalAmount, '₹')} (${cat.percentage.toStringAsFixed(0)}%)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 8,
                              backgroundColor: theme.background,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),

        // Member Spending Breakdown
        Text(
          'MEMBER CONTRIBUTIONS & SHARES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        NeumorphicContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: analytics.memberBreakdown.map((member) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
                        ),
                        Text(
                          'Paid: ${CurrencyUtils.formatCurrency(member.totalPaid, '₹')} • Share: ${CurrencyUtils.formatCurrency(member.totalShare, '₹')}',
                          style: TextStyle(fontSize: 11, color: theme.secondaryText),
                        ),
                      ],
                    ),
                    Text(
                      member.netBalance > 0
                          ? '+₹${member.netBalance.toStringAsFixed(0)}'
                          : (member.netBalance < 0
                              ? '-₹${member.netBalance.abs().toStringAsFixed(0)}'
                              : '₹0'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: member.netBalance > 0
                            ? Colors.green[400]
                            : (member.netBalance < 0 ? Colors.redAccent : theme.secondaryText),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(GroupModel group, String myEmail, dynamic theme) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 80),
      physics: const BouncingScrollPhysics(),
      children: [
        // Accepted Members Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE MEMBERS (${group.acceptedMembers.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.secondaryText,
              ),
            ),
            GestureDetector(
              onTap: _handleInvite,
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: theme.accent),
                  const SizedBox(width: 4),
                  Text('Invite', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...group.acceptedMembers.map((m) {
          final isMe = m.email.toLowerCase() == myEmail;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeumorphicContainer(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : 'U',
                        style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isMe ? '${m.name} (You)' : m.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            if (m.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Admin', style: TextStyle(fontSize: 10, color: theme.accent, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(m.email, style: TextStyle(fontSize: 11, color: theme.secondaryText)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                ],
              ),
            ),
          );
        }),

        if (group.pendingMembers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'PENDING INVITATIONS (${group.pendingMembers.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.amber[700],
            ),
          ),
          const SizedBox(height: 10),
          ...group.pendingMembers.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeumorphicContainer(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.amber),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
                          ),
                          Text(m.email, style: TextStyle(fontSize: 11, color: theme.secondaryText)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Awaiting Acceptance',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber[700]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

