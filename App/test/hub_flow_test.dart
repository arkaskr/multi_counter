import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/services/auth_service.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/calorie_counter/models/meal_log_model.dart';
import 'package:daily_counter/features/calorie_counter/models/nutrition_goal_models.dart';
import 'package:daily_counter/features/calorie_counter/providers/calorie_providers.dart';
import 'package:daily_counter/features/calorie_counter/screens/calorie_counter_screen.dart';
import 'package:daily_counter/features/expense_counter/models/group_model.dart';
import 'package:daily_counter/features/expense_counter/providers/expense_providers.dart';
import 'package:daily_counter/features/expense_counter/screens/expense_counter_screen.dart';
import 'package:daily_counter/features/hub/screens/hub_screen.dart';
import 'package:daily_counter/features/meal_counter/meal_counter_shell.dart';
import 'package:daily_counter/features/surprise/screens/surprise_screen.dart';
import 'package:daily_counter/shared/models/user_model.dart';

class FakeLoggedInAuthService extends AuthService {
  FakeLoggedInAuthService() : super.internal();

  @override
  Future<void> init() async {}

  @override
  bool get isInitialized => true;

  @override
  bool get isLoggedIn => true;

  @override
  String? get token => 'test_token';

  @override
  UserModel? get currentUser => const UserModel(
        id: 'u1',
        name: 'Arka Sarkar',
        email: 'arka@example.com',
      );
}

class FakeGroupsNotifier extends GroupsNotifier {
  @override
  Future<GroupsData> build() async {
    return (groups: <GroupModel>[], pendingInvitations: <GroupModel>[]);
  }
}

class FakeDailyDashboardNotifier extends DailyDashboardNotifier {
  @override
  Future<DailyDashboardState> build() async {
    const uid = 'u1';
    const date = '2026-11-12';
    return DailyDashboardState(
      dateString: date,
      totals: DailyNutritionTotals.fromLogs(date: date, logs: const []),
      goal: DailyNutritionGoal.fallbackDefault(uid),
      recentFoods: const [],
      preferences: UserNutritionPreferences.initial(uid),
    );
  }
}

void main() {
  testWidgets('HubScreen renders 4 cards in 2x2 setup with icon and name', (tester) async {
    final fakeAuth = FakeLoggedInAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          groupsProvider.overrideWith(FakeGroupsNotifier.new),
          dailyDashboardProvider.overrideWith(FakeDailyDashboardNotifier.new),
        ],
        child: const MaterialApp(
          home: HubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify user greeting & top section
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Arka Sarkar'), findsOneWidget);

    // Verify the 4 cards by title
    expect(find.text('Meal Counter'), findsOneWidget);
    expect(find.text('Calorie Counter'), findsOneWidget);
    expect(find.text('Expense Counter'), findsOneWidget);
    expect(find.text('Surprise'), findsOneWidget);

    // Verify the 4 cards by icons
    expect(find.byIcon(Icons.lunch_dining_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

    // Verify no "ACTIVE" tag on hub cards
    expect(find.text('ACTIVE'), findsNothing);
  });

  testWidgets('Tapping Meal Counter navigates to MealCounterShell and can return to Hub', (tester) async {
    final fakeAuth = FakeLoggedInAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          groupsProvider.overrideWith(FakeGroupsNotifier.new),
          dailyDashboardProvider.overrideWith(FakeDailyDashboardNotifier.new),
        ],
        child: const MaterialApp(
          home: HubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Meal Counter card
    await tester.tap(find.text('Meal Counter'));
    await tester.pumpAndSettle();

    // Verify MealCounterShell is opened
    expect(find.byType(MealCounterShell), findsOneWidget);
    expect(find.text("TODAY'S COUNTER"), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap Hub button in header to return
    expect(find.text('Hub'), findsOneWidget);
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();

    // We are back at HubScreen
    expect(find.byType(HubScreen), findsOneWidget);
  });

  testWidgets('Tapping Calorie Counter, Expense Counter, and Surprise opens respective Coming Soon screens', (tester) async {
    final fakeAuth = FakeLoggedInAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          groupsProvider.overrideWith(FakeGroupsNotifier.new),
          dailyDashboardProvider.overrideWith(FakeDailyDashboardNotifier.new),
        ],
        child: const MaterialApp(
          home: HubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Calorie Counter
    await tester.ensureVisible(find.text('Calorie Counter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calorie Counter'));
    await tester.pumpAndSettle();
    expect(find.byType(CalorieCounterScreen), findsOneWidget);
    expect(find.text('Quick Add Food'), findsOneWidget);

    // Back to hub via top app bar back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HubScreen), findsOneWidget);

    // 2. Expense Counter
    await tester.ensureVisible(find.text('Expense Counter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expense Counter'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseCounterScreen), findsOneWidget);
    expect(find.text('YOUR GROUPS'), findsOneWidget);

    // Back to hub via top Hub button
    await tester.tap(find.text('Hub'));
    await tester.pumpAndSettle();
    expect(find.byType(HubScreen), findsOneWidget);

    // 3. Surprise
    await tester.ensureVisible(find.text('Surprise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surprise'));
    await tester.pumpAndSettle();
    expect(find.byType(SurpriseScreen), findsOneWidget);
    expect(find.text('Something Special is Cooking!'), findsOneWidget);

    // Back to hub via top app bar back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HubScreen), findsOneWidget);
  });
}
