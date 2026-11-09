import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:daily_counter/core/config/app_config.dart';
import 'package:daily_counter/core/services/auth_service.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';

class ExpenseService {
  final AuthService _authService;
  final http.Client _client;

  ExpenseService({
    AuthService? authService,
    http.Client? client,
  })  : _authService = authService ?? AuthService.instance,
        _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = _authService.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get list of user's accepted groups and pending invitations
  Future<({List<GroupModel> groups, List<GroupModel> pendingInvitations})> getGroups() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups');
    final response = await _client.get(url, headers: _headers());

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch groups: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawGroups = data['groups'] as List<dynamic>? ?? [];
    final rawPending = data['pendingInvitations'] as List<dynamic>? ?? [];

    final groups = rawGroups.map((g) => GroupModel.fromJson(g as Map<String, dynamic>)).toList();
    final pending = rawPending.map((g) => GroupModel.fromJson(g as Map<String, dynamic>)).toList();

    return (groups: groups, pendingInvitations: pending);
  }

  /// Create a new group
  Future<GroupModel> createGroup(String name, String description) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups');
    final response = await _client.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name.trim(),
        'description': description.trim(),
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to create group');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupModel.fromJson(data['group'] as Map<String, dynamic>);
  }

  /// Fetch full details of a single group
  Future<Map<String, dynamic>> getGroupDetail(String groupId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId');
    final response = await _client.get(url, headers: _headers());

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to load group details');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final group = GroupModel.fromJson(data['group'] as Map<String, dynamic>);
    final analytics = ExpenseAnalyticsReport.fromJson(data['analytics'] as Map<String, dynamic>);

    final rawExpenses = data['recentExpenses'] as List<dynamic>? ?? [];
    final expenses = rawExpenses.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'group': group,
      'membershipStatus': data['membershipStatus'],
      'role': data['role'],
      'analytics': analytics,
      'expenses': expenses,
    };
  }

  /// Invite a person by registered email
  Future<String> inviteMember(String groupId, String email) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/invite');
    final response = await _client.post(
      url,
      headers: _headers(),
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to send invitation');
    }

    return (data['message'] ?? 'Invitation sent successfully.').toString();
  }

  /// Respond to group invitation ('accept' or 'decline')
  Future<String> respondInvitation(String groupId, String action) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/respond');
    final response = await _client.post(
      url,
      headers: _headers(),
      body: jsonEncode({'action': action}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to respond to invitation');
    }

    return (data['message'] ?? 'Success').toString();
  }

  /// Get list of expenses for a group
  Future<List<ExpenseModel>> getExpenses(String groupId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/expenses');
    final response = await _client.get(url, headers: _headers());

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch expenses');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawExpenses = data['expenses'] as List<dynamic>? ?? [];
    return rawExpenses.map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Add a new expense (user logs what they paid)
  Future<ExpenseModel> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String note = '',
    List<Map<String, dynamic>>? customSplits,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/expenses');
    final response = await _client.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'title': title.trim(),
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'note': note.trim(),
        if (customSplits != null) 'customSplits': customSplits,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to add expense');
    }

    return ExpenseModel.fromJson(data['expense'] as Map<String, dynamic>);
  }

  /// Delete an expense
  Future<void> deleteExpense(String groupId, String expenseId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/expenses/$expenseId');
    final response = await _client.delete(url, headers: _headers());

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Failed to delete expense');
    }
  }

  /// Get detailed group analytics
  Future<ExpenseAnalyticsReport> getAnalytics(String groupId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/groups/$groupId/analytics');
    final response = await _client.get(url, headers: _headers());

    if (response.statusCode != 200) {
      throw Exception('Failed to load analytics');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ExpenseAnalyticsReport.fromJson(data['analytics'] as Map<String, dynamic>);
  }
}

