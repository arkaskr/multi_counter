class ExpenseSplitModel {
  final String? userId;
  final String email;
  final String name;
  final double shareAmount;

  ExpenseSplitModel({
    this.userId,
    required this.email,
    required this.name,
    required this.shareAmount,
  });

  factory ExpenseSplitModel.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitModel(
      userId: json['user']?.toString(),
      email: (json['email'] ?? '').toString().toLowerCase().trim(),
      name: (json['name'] ?? '').toString().trim(),
      shareAmount: (json['shareAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': userId,
      'email': email,
      'name': name,
      'shareAmount': shareAmount,
    };
  }
}

class ExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String category;
  final String paidByUserId;
  final String paidByName;
  final String paidByEmail;
  final List<ExpenseSplitModel> splits;
  final String note;
  final DateTime date;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.category,
    required this.paidByUserId,
    required this.paidByName,
    required this.paidByEmail,
    required this.splits,
    required this.note,
    required this.date,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final rawSplits = json['splits'] as List<dynamic>? ?? [];
    return ExpenseModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      groupId: (json['group'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: (json['category'] ?? 'Food').toString(),
      paidByUserId: (json['paidBy'] ?? '').toString(),
      paidByName: (json['paidByName'] ?? '').toString(),
      paidByEmail: (json['paidByEmail'] ?? '').toString().toLowerCase(),
      splits: rawSplits.map((s) => ExpenseSplitModel.fromJson(s as Map<String, dynamic>)).toList(),
      note: (json['note'] ?? '').toString(),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SettlementDebt {
  final String fromEmail;
  final String fromName;
  final String? fromUserId;
  final String toEmail;
  final String toName;
  final String? toUserId;
  final double amount;

  SettlementDebt({
    required this.fromEmail,
    required this.fromName,
    this.fromUserId,
    required this.toEmail,
    required this.toName,
    this.toUserId,
    required this.amount,
  });

  factory SettlementDebt.fromJson(Map<String, dynamic> json) {
    return SettlementDebt(
      fromEmail: (json['fromEmail'] ?? '').toString(),
      fromName: (json['fromName'] ?? '').toString(),
      fromUserId: json['fromUserId']?.toString(),
      toEmail: (json['toEmail'] ?? '').toString(),
      toName: (json['toName'] ?? '').toString(),
      toUserId: json['toUserId']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double totalAmount;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    required this.totalAmount,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: (json['category'] ?? 'Other').toString(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MemberBreakdown {
  final String name;
  final String email;
  final String? userId;
  final double totalPaid;
  final double totalShare;
  final double netBalance;
  final double percentageOfTotalPaid;

  MemberBreakdown({
    required this.name,
    required this.email,
    this.userId,
    required this.totalPaid,
    required this.totalShare,
    required this.netBalance,
    required this.percentageOfTotalPaid,
  });

  factory MemberBreakdown.fromJson(Map<String, dynamic> json) {
    return MemberBreakdown(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      userId: json['userId']?.toString(),
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalShare: (json['totalShare'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['netBalance'] as num?)?.toDouble() ?? 0.0,
      percentageOfTotalPaid: (json['percentageOfTotalPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExpenseAnalyticsReport {
  final double totalSpend;
  final int expenseCount;
  final double myTotalPaid;
  final double myTotalShare;
  final double myNetBalance;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<MemberBreakdown> memberBreakdown;
  final List<SettlementDebt> settlements;

  ExpenseAnalyticsReport({
    required this.totalSpend,
    required this.expenseCount,
    required this.myTotalPaid,
    required this.myTotalShare,
    required this.myNetBalance,
    required this.categoryBreakdown,
    required this.memberBreakdown,
    required this.settlements,
  });

  factory ExpenseAnalyticsReport.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categoryBreakdown'] as List<dynamic>? ?? [];
    final rawMembers = json['memberBreakdown'] as List<dynamic>? ?? [];
    final rawSettlements = json['settlements'] as List<dynamic>? ?? [];

    return ExpenseAnalyticsReport(
      totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0.0,
      expenseCount: (json['expenseCount'] as num?)?.toInt() ?? 0,
      myTotalPaid: (json['myTotalPaid'] as num?)?.toDouble() ?? 0.0,
      myTotalShare: (json['myTotalShare'] as num?)?.toDouble() ?? 0.0,
      myNetBalance: (json['myNetBalance'] as num?)?.toDouble() ?? 0.0,
      categoryBreakdown: rawCats.map((c) => CategoryBreakdown.fromJson(c as Map<String, dynamic>)).toList(),
      memberBreakdown: rawMembers.map((m) => MemberBreakdown.fromJson(m as Map<String, dynamic>)).toList(),
      settlements: rawSettlements.map((s) => SettlementDebt.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

