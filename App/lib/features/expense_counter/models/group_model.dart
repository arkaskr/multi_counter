class GroupMemberModel {
  final String? userId;
  final String email;
  final String name;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final String role; // 'admin' | 'member'
  final DateTime? joinedAt;

  GroupMemberModel({
    this.userId,
    required this.email,
    required this.name,
    required this.status,
    required this.role,
    this.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['user']?.toString(),
      email: (json['email'] ?? '').toString().toLowerCase().trim(),
      name: (json['name'] ?? 'Member').toString().trim(),
      status: (json['status'] ?? 'pending').toString(),
      role: (json['role'] ?? 'member').toString(),
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': userId,
      'email': email,
      'name': name,
      'status': status,
      'role': role,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }

  bool get isAccepted => status == 'accepted';
  bool get isPending => status == 'pending';
  bool get isAdmin => role == 'admin';
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final String createdByName;
  final String createdByEmail;
  final List<GroupMemberModel> members;
  final double totalSpend;
  final double myNetBalance;
  final int expenseCount;
  final int acceptedMemberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdByName,
    required this.createdByEmail,
    required this.members,
    this.totalSpend = 0.0,
    this.myNetBalance = 0.0,
    this.expenseCount = 0,
    this.acceptedMemberCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    final parsedMembers = rawMembers.map((m) => GroupMemberModel.fromJson(m as Map<String, dynamic>)).toList();

    return GroupModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdByName: (json['createdByName'] ?? '').toString(),
      createdByEmail: (json['createdByEmail'] ?? '').toString(),
      members: parsedMembers,
      totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0.0,
      myNetBalance: (json['myNetBalance'] as num?)?.toDouble() ?? 0.0,
      expenseCount: (json['expenseCount'] as num?)?.toInt() ?? 0,
      acceptedMemberCount: (json['acceptedMemberCount'] as num?)?.toInt() ??
          parsedMembers.where((m) => m.isAccepted).length,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  List<GroupMemberModel> get acceptedMembers => members.where((m) => m.isAccepted).toList();
  List<GroupMemberModel> get pendingMembers => members.where((m) => m.isPending).toList();
}

