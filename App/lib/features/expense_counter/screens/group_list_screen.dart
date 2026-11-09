import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/auth/screens/login_screen.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import '../models/group_model.dart';
import '../providers/expense_providers.dart';
import 'create_group_dialog.dart';
import 'group_detail_screen.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  Future<void> _handleCreateGroup(BuildContext context, WidgetRef ref) async {
    final newGroup = await showDialog<GroupModel>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );

    if (newGroup != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: newGroup.id),
        ),
      );
      if (context.mounted) {
        ref.read(groupsProvider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final authState = ref.watch(authStateProvider);

    // Guard: Account is required
    if (!authState.isLoggedIn || authState.user == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hub navigation pill
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
                        Icon(Icons.grid_view_rounded, size: 14, color: theme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Hub',
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
                const SizedBox(height: 16),
                Text(
                  'EXPENSE SPLITTER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expense Counter',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.text),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_outline_rounded, size: 54, color: theme.accent),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Account Required',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.text),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expense Counter splits group expenses in real-time. Everyone in the group must have an account so debts and invitations sync across devices.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: theme.secondaryText, height: 1.4),
                          ),
                          const SizedBox(height: 28),
                          NeumorphicButton(
                            isProminent: true,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text(
                              'Sign In / Register',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: theme.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.accent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Group',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        onPressed: () => _handleCreateGroup(context, ref),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Bar (Consistent with Meal Counter)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back to Hub Pill Button
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
                              Icon(Icons.grid_view_rounded, size: 14, color: theme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Hub',
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

                      // Refresh Pill Button
                      GestureDetector(
                        onTap: () => ref.read(groupsProvider.notifier).refresh(),
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 14, color: theme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Refresh',
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Header Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSE SPLITTER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expense Counter',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: groupsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: theme.accent),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 14),
                        Text(
                          'Failed to load expense groups',
                          style: TextStyle(color: theme.text, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString().replaceAll('Exception:', '').trim(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.secondaryText, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        NeumorphicButton(
                          onTap: () => ref.read(groupsProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) {
                  final groups = data.groups;
                  final pending = data.pendingInvitations;

                  return RefreshIndicator(
                    color: theme.accent,
                    onRefresh: () => ref.read(groupsProvider.notifier).refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PENDING INVITATIONS BANNER (if any)
                          if (pending.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.mail_outline_rounded, size: 16, color: Colors.amber),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GROUP INVITATIONS (${pending.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...pending.map((invGroup) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: NeumorphicContainer(
                                  borderRadius: 20,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.group_add_rounded, color: Colors.amber, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  invGroup.name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: theme.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Invited by ${invGroup.createdByName}',
                                                  style: TextStyle(fontSize: 12, color: theme.secondaryText),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (invGroup.description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          invGroup.description,
                                          style: TextStyle(fontSize: 12, color: theme.secondaryText),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              await ref
                                                  .read(groupsProvider.notifier)
                                                  .respondInvitation(invGroup.id, 'decline');
                                            },
                                            child: Text('Decline', style: TextStyle(color: theme.secondaryText)),
                                          ),
                                          const SizedBox(width: 8),
                                          NeumorphicButton(
                                            isProminent: true,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            onTap: () async {
                                              await ref
                                                  .read(groupsProvider.notifier)
                                                  .respondInvitation(invGroup.id, 'accept');
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Joined ${invGroup.name}!'),
                                                    backgroundColor: Colors.green[700],
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text(
                                              'Accept Invite',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // MY GROUPS SECTION
                          Text(
                            'YOUR GROUPS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (groups.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: theme.accent.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.groups_rounded, size: 40, color: theme.accent),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'No Expense Groups Yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: theme.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create a group for your trip, flat, or outing, invite friends by email, and log expenses effortlessly.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: theme.secondaryText, height: 1.4),
                                    ),
                                    const SizedBox(height: 24),
                                    NeumorphicButton(
                                      isProminent: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      onTap: () => _handleCreateGroup(context, ref),
                                      child: const Text(
                                        'Create First Group',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...groups.map((group) {
                              final myNet = group.myNetBalance;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: GestureDetector(
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => GroupDetailScreen(groupId: group.id),
                                      ),
                                    );
                                    if (context.mounted) {
                                      ref.read(groupsProvider.notifier).refresh();
                                    }
                                  },
                                  child: NeumorphicContainer(
                                    borderRadius: 22,
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Group Avatar
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: theme.accent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w900,
                                                    color: theme.accent,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Title & Member Count
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    group.name,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w800,
                                                      color: theme.text,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${group.acceptedMemberCount} members • ${group.expenseCount} expenses',
                                                    style: TextStyle(fontSize: 12, color: theme.secondaryText),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Net Balance Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: myNet > 0.01
                                                    ? Colors.green.withValues(alpha: 0.15)
                                                    : (myNet < -0.01
                                                        ? Colors.redAccent.withValues(alpha: 0.15)
                                                        : theme.secondaryText.withValues(alpha: 0.1)),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                myNet > 0.01
                                                    ? '+₹${myNet.toStringAsFixed(0)}'
                                                    : (myNet < -0.01
                                                        ? '-₹${myNet.abs().toStringAsFixed(0)}'
                                                        : 'Settled'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: myNet > 0.01
                                                      ? Colors.green[400]
                                                      : (myNet < -0.01 ? Colors.redAccent : theme.secondaryText),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (group.description.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            group.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: theme.secondaryText),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        Divider(color: theme.secondaryText.withValues(alpha: 0.12)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total Spent: ${CurrencyUtils.formatCurrency(group.totalSpend, '₹')}',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'View',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: theme.accent,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.chevron_right_rounded, size: 18, color: theme.accent),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
