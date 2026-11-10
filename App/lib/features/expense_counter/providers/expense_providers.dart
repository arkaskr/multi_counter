import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ExpenseService(authService: authService);
});

typedef GroupsData = ({List<GroupModel> groups, List<GroupModel> pendingInvitations});

class GroupsNotifier extends AsyncNotifier<GroupsData> {
  @override
  Future<GroupsData> build() async {
    final service = ref.watch(expenseServiceProvider);
    final authState = ref.watch(authStateProvider);

    if (!authState.isLoggedIn || authState.token == null) {
      return (groups: <GroupModel>[], pendingInvitations: <GroupModel>[]);
    }

    return await service.getGroups();
  }

  Future<void> refresh() async {
    final service = ref.read(expenseServiceProvider);
    final authState = ref.read(authStateProvider);

    if (!authState.isLoggedIn || authState.token == null) {
      state = const AsyncValue.data((groups: <GroupModel>[], pendingInvitations: <GroupModel>[]));
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await service.getGroups();
    });
  }

  Future<GroupModel> createGroup(String name, String description) async {
    final service = ref.read(expenseServiceProvider);
    final group = await service.createGroup(name, description);
    await refresh();
    return group;
  }

  Future<void> respondInvitation(String groupId, String action) async {
    final service = ref.read(expenseServiceProvider);
    await service.respondInvitation(groupId, action);
    await refresh();
  }

  Future<void> deleteGroup(String groupId) async {
    final service = ref.read(expenseServiceProvider);
    await service.deleteGroup(groupId);
    await refresh();
  }
}

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, GroupsData>(GroupsNotifier.new);

typedef GroupDetailData = ({
  GroupModel group,
  String membershipStatus,
  String role,
  ExpenseAnalyticsReport analytics,
  List<ExpenseModel> expenses,
});

final groupDetailProvider = FutureProvider.family<GroupDetailData, String>((ref, groupId) async {
  final service = ref.watch(expenseServiceProvider);
  final map = await service.getGroupDetail(groupId);

  return (
    group: map['group'] as GroupModel,
    membershipStatus: (map['membershipStatus'] ?? 'accepted').toString(),
    role: (map['role'] ?? 'member').toString(),
    analytics: map['analytics'] as ExpenseAnalyticsReport,
    expenses: map['expenses'] as List<ExpenseModel>,
  );
});

