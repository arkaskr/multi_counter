class FoodRequest {
  final String id;
  final String userId;
  final String foodName;
  final String categoryHint;
  final String brandOrPreparation;
  final String servingDescription;
  final String referenceUrlOrNote;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String adminNotes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const FoodRequest({
    required this.id,
    required this.userId,
    required this.foodName,
    this.categoryHint = '',
    this.brandOrPreparation = '',
    this.servingDescription = '',
    this.referenceUrlOrNote = '',
    this.status = 'pending',
    this.adminNotes = '',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory FoodRequest.fromDbMap(Map<String, dynamic> map) {
    return FoodRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      foodName: map['food_name'] as String,
      categoryHint: (map['category_hint'] ?? '') as String,
      brandOrPreparation: (map['brand_or_preparation'] ?? '') as String,
      servingDescription: (map['serving_description'] ?? '') as String,
      referenceUrlOrNote: (map['reference_url_or_note'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      adminNotes: (map['admin_notes'] ?? '') as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'user_id': userId,
        'food_name': foodName,
        'category_hint': categoryHint,
        'brand_or_preparation': brandOrPreparation,
        'serving_description': servingDescription,
        'reference_url_or_note': referenceUrlOrNote,
        'status': status,
        'admin_notes': adminNotes,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
      };

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'foodName': foodName,
        'categoryHint': categoryHint,
        'brandOrPreparation': brandOrPreparation,
        'servingDescription': servingDescription,
        'referenceUrlOrNote': referenceUrlOrNote,
        'status': status,
        'adminNotes': adminNotes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FoodRequest.fromApiJson(Map<String, dynamic> json, String userId) {
    return FoodRequest(
      id: json['id'] as String,
      userId: userId,
      foodName: json['foodName'] as String,
      categoryHint: (json['categoryHint'] ?? '') as String,
      brandOrPreparation: (json['brandOrPreparation'] ?? '') as String,
      servingDescription: (json['servingDescription'] ?? '') as String,
      referenceUrlOrNote: (json['referenceUrlOrNote'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      adminNotes: (json['adminNotes'] ?? '') as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      syncStatus: 'synced',
    );
  }
}

