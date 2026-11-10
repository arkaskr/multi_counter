import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/services/auth_service.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/expense_counter/models/expense_model.dart';
import 'package:daily_counter/features/expense_counter/models/group_model.dart';
import 'package:daily_counter/features/expense_counter/providers/expense_providers.dart';
import 'package:daily_counter/features/expense_counter/screens/group_detail_screen.dart';
import 'package:daily_counter/features/expense_counter/screens/group_list_screen.dart';
import 'package:daily_counter/shared/models/user_model.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super.internal();

  @override
  bool get isLoggedIn => true;

  @override
  String? get token => 'mock_token';

  @override
  UserModel? get currentUser => const UserModel(
        id: 'u_alice',
        name: 'Alice',
        email: 'alice@example.com',
      );
}

void main() {
  group('Expense Counter Models & Calculations', () {
    test('GroupModel and GroupMemberModel JSON parsing', () {
      final json = {
        '_id': 'g123',
        'name': 'Goa Trip',
        'description': 'Vacation expenses',
        'createdBy': 'u_alice',
        'createdByName': 'Alice',
        'createdByEmail': 'alice@example.com',
        'totalSpend': 1200.0,
        'myNetBalance': 400.0,
        'expenseCount': 2,
        'members': [
          {
            'user': 'u_alice',
            'email': 'alice@example.com',
            'name': 'Alice',
            'status': 'accepted',
            'role': 'admin',
          },
          {
            'user': 'u_bob',
            'email': 'bob@example.com',
            'name': 'Bob',
            'status': 'pending',
            'role': 'member',
          },
        ],
      };

      final group = GroupModel.fromJson(json);
      expect(group.id, 'g123');
      expect(group.name, 'Goa Trip');
      expect(group.totalSpend, 1200.0);
      expect(group.myNetBalance, 400.0);
      expect(group.acceptedMembers.length, 1);
      expect(group.pendingMembers.length, 1);
      expect(group.acceptedMembers.first.isAdmin, true);
      expect(group.pendingMembers.first.isPending, true);
    });

    test('ExpenseModel JSON parsing', () {
      final json = {
        '_id': 'e1',
        'group': 'g123',
        'title': 'Beach Dinner',
        'amount': 600.0,
        'category': 'Food',
        'paidBy': 'u_alice',
        'paidByName': 'Alice',
        'paidByEmail': 'alice@example.com',
        'splits': [
          {'email': 'alice@example.com', 'name': 'Alice', 'shareAmount': 300.0},
          {'email': 'bob@example.com', 'name': 'Bob', 'shareAmount': 300.0},
        ],
        'note': 'Seafood and drinks',
        'date': '2026-11-09T12:00:00.000Z',
      };

      final exp = ExpenseModel.fromJson(json);
      expect(exp.id, 'e1');
      expect(exp.title, 'Beach Dinner');
      expect(exp.amount, 600.0);
      expect(exp.category, 'Food');
      expect(exp.splits.length, 2);
      expect(exp.splits[0].shareAmount, 300.0);
    });

    test('SettlementDebt model parses debt transactions correctly', () {
      final json = {
        'fromEmail': 'bob@example.com',
        'fromName': 'Bob',
        'toEmail': 'alice@example.com',
        'toName': 'Alice',
        'amount': 300.0,
      };

      final debt = SettlementDebt.fromJson(json);
      expect(debt.fromName, 'Bob');
      expect(debt.toName, 'Alice');
      expect(debt.amount, 300.0);
    });
  });

  group('Expense Counter UI Widget Tests', () {
    testWidgets('GroupListScreen displays groups and pending invitations', (tester) async {
      final fakeAuth = FakeAuthService();

      final testGroup = GroupModel(
        id: 'g1',
        name: 'Flat 301',
        description: 'Roommate split',
        createdBy: 'u_alice',
        createdByName: 'Alice',
        createdByEmail: 'alice@example.com',
        totalSpend: 1500.0,
        myNetBalance: 500.0,
        expenseCount: 3,
        acceptedMemberCount: 2,
        members: [
          GroupMemberModel(email: 'alice@example.com', name: 'Alice', status: 'accepted', role: 'admin'),
          GroupMemberModel(email: 'bob@example.com', name: 'Bob', status: 'accepted', role: 'member'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pendingGroup = GroupModel(
        id: 'g2',
        name: 'Road Trip',
        description: 'Weekend drive',
        createdBy: 'u_charlie',
        createdByName: 'Charlie',
        createdByEmail: 'charlie@example.com',
        totalSpend: 0.0,
        myNetBalance: 0.0,
        expenseCount: 0,
        acceptedMemberCount: 1,
        members: [
          GroupMemberModel(email: 'charlie@example.com', name: 'Charlie', status: 'accepted', role: 'admin'),
          GroupMemberModel(email: 'alice@example.com', name: 'Alice', status: 'pending', role: 'member'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            groupsProvider.overrideWith(() => _MockGroupsNotifier(
                  groups: [testGroup],
                  pending: [pendingGroup],
                )),
          ],
          child: const MaterialApp(
            home: GroupListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Expense Counter'), findsOneWidget);
      expect(find.text('GROUP INVITATIONS (1)'), findsOneWidget);
      expect(find.text('Road Trip'), findsOneWidget);
      expect(find.text('Invited by Charlie'), findsOneWidget);
      expect(find.text('Accept Invite'), findsOneWidget);

      expect(find.text('YOUR GROUPS'), findsOneWidget);
      expect(find.text('Flat 301'), findsOneWidget);
      expect(find.text('+₹500'), findsOneWidget);
      expect(find.text('New Group'), findsOneWidget);
    });

    testWidgets('GroupDetailScreen renders expenses, settlements, analytics and members tabs', (tester) async {
      final fakeAuth = FakeAuthService();

      final testGroup = GroupModel(
        id: 'g1',
        name: 'Flat 301',
        description: 'Roommate split',
        createdBy: 'u_alice',
        createdByName: 'Alice',
        createdByEmail: 'alice@example.com',
        totalSpend: 600.0,
        myNetBalance: 300.0,
        expenseCount: 1,
        acceptedMemberCount: 2,
        members: [
          GroupMemberModel(email: 'alice@example.com', name: 'Alice', status: 'accepted', role: 'admin'),
          GroupMemberModel(email: 'bob@example.com', name: 'Bob', status: 'accepted', role: 'member'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final analytics = ExpenseAnalyticsReport(
        totalSpend: 600.0,
        expenseCount: 1,
        myTotalPaid: 600.0,
        myTotalShare: 300.0,
        myNetBalance: 300.0,
        categoryBreakdown: [
          CategoryBreakdown(category: 'Food', totalAmount: 600.0, percentage: 100.0),
        ],
        memberBreakdown: [
          MemberBreakdown(
            name: 'Alice',
            email: 'alice@example.com',
            totalPaid: 600.0,
            totalShare: 300.0,
            netBalance: 300.0,
            percentageOfTotalPaid: 100.0,
          ),
          MemberBreakdown(
            name: 'Bob',
            email: 'bob@example.com',
            totalPaid: 0.0,
            totalShare: 300.0,
            netBalance: -300.0,
            percentageOfTotalPaid: 0.0,
          ),
        ],
        settlements: [
          SettlementDebt(
            fromEmail: 'bob@example.com',
            fromName: 'Bob',
            toEmail: 'alice@example.com',
            toName: 'Alice',
            amount: 300.0,
          ),
        ],
      );

      final expense = ExpenseModel(
        id: 'e1',
        groupId: 'g1',
        title: 'Groceries',
        amount: 600.0,
        category: 'Groceries',
        paidByUserId: 'u_alice',
        paidByName: 'Alice',
        paidByEmail: 'alice@example.com',
        splits: [
          ExpenseSplitModel(email: 'alice@example.com', name: 'Alice', shareAmount: 300.0),
          ExpenseSplitModel(email: 'bob@example.com', name: 'Bob', shareAmount: 300.0),
        ],
        note: 'Milk and bread',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            groupDetailProvider('g1').overrideWith((ref) async => (
                  group: testGroup,
                  membershipStatus: 'accepted',
                  role: 'admin',
                  analytics: analytics,
                  expenses: [expense],
                )),
          ],
          child: const MaterialApp(
            home: GroupDetailScreen(groupId: 'g1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top Header checks
      expect(find.text('Flat 301'), findsOneWidget);
      expect(find.text('TOTAL GROUP SPEND'), findsOneWidget);
      expect(find.text('YOU ARE OWED'), findsOneWidget);
      expect(find.text('+₹300'), findsOneWidget);

      // Verify Tab 1: Expenses
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('You paid'), findsOneWidget);

      // Switch to Tab 2: Settlement
      await tester.tap(find.widgetWithText(Tab, 'Settlement'));
      await tester.pumpAndSettle();
      expect(find.text('Bob should pay you'), findsOneWidget);
      expect(find.text('₹300'), findsAtLeastNWidgets(1));

      // Switch to Tab 3: Analytics
      await tester.tap(find.widgetWithText(Tab, 'Analytics'));
      await tester.pumpAndSettle();
      expect(find.text('SPENDING BY CATEGORY'), findsOneWidget);
      expect(find.text('MEMBER CONTRIBUTIONS & SHARES'), findsOneWidget);

      // Switch to Tab 4: Members
      await tester.tap(find.widgetWithText(Tab, 'Members'));
      await tester.pumpAndSettle();
      expect(find.text('ACTIVE MEMBERS (2)'), findsOneWidget);
      expect(find.text('Alice (You)'), findsOneWidget);
      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.text('Delete Group'), findsAtLeastNWidgets(1));
    });

    testWidgets('GroupDetailScreen formats fractional net balances with decimals and uses "You owe"', (tester) async {
      final fakeAuth = FakeAuthService(); // alice@example.com

      final testGroup = GroupModel(
        id: 'g2',
        name: 'Till 2028',
        description: 'Roommate split',
        createdBy: 'u_alice',
        createdByName: 'Alice',
        createdByEmail: 'alice@example.com',
        totalSpend: 735.0,
        myNetBalance: -47.5,
        expenseCount: 1,
        acceptedMemberCount: 2,
        members: [
          GroupMemberModel(email: 'alice@example.com', name: 'Alice', status: 'accepted', role: 'admin'),
          GroupMemberModel(email: 'subhajit@example.com', name: 'Subhajit', status: 'accepted', role: 'member'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final analytics = ExpenseAnalyticsReport(
        totalSpend: 735.0,
        expenseCount: 1,
        myTotalPaid: 320.0,
        myTotalShare: 367.5,
        myNetBalance: -47.5,
        categoryBreakdown: [
          CategoryBreakdown(category: 'Food', totalAmount: 735.0, percentage: 100.0),
        ],
        memberBreakdown: [
          MemberBreakdown(
            name: 'Alice',
            email: 'alice@example.com',
            totalPaid: 320.0,
            totalShare: 367.5,
            netBalance: -47.5,
            percentageOfTotalPaid: 43.54,
          ),
          MemberBreakdown(
            name: 'Subhajit',
            email: 'subhajit@example.com',
            totalPaid: 415.0,
            totalShare: 367.5,
            netBalance: 47.5,
            percentageOfTotalPaid: 56.46,
          ),
        ],
        settlements: [
          SettlementDebt(
            fromEmail: 'alice@example.com',
            fromName: 'Alice',
            toEmail: 'subhajit@example.com',
            toName: 'Subhajit',
            amount: 47.5,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            groupDetailProvider('g2').overrideWith((ref) async => (
                  group: testGroup,
                  membershipStatus: 'accepted',
                  role: 'admin',
                  analytics: analytics,
                  expenses: <ExpenseModel>[],
                )),
          ],
          child: const MaterialApp(
            home: GroupDetailScreen(groupId: 'g2'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify exact decimal display for fractional net balance
      expect(find.text('YOU OWE'), findsOneWidget);
      expect(find.text('-₹47.50'), findsOneWidget);

      // Verify Settlement tab uses "You owe Subhajit" instead of "You owes"
      await tester.tap(find.widgetWithText(Tab, 'Settlement'));
      await tester.pumpAndSettle();
      expect(find.text('You need to pay Subhajit'), findsOneWidget);
      expect(find.text('₹47.50'), findsOneWidget);
    });
  });
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<GroupModel> _groups;
  final List<GroupModel> _pending;

  _MockGroupsNotifier({required List<GroupModel> groups, required List<GroupModel> pending})
      : _groups = groups,
        _pending = pending;

  @override
  Future<GroupsData> build() async {
    return (groups: _groups, pendingInvitations: _pending);
  }
}
