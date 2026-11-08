class UserModel {
  final String id;
  final String name;
  final String email;
  final String? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      name: map['name'] as String? ?? 'User',
      email: map['email'] as String? ?? '',
      createdAt: map['createdAt'] as String?,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserModel(id: $id, name: $name, email: $email)';
}

