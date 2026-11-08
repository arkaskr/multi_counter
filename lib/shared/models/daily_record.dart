class DailyRecord {
  final int? id;
  final String date;
  final int count;
  final double? amountOverride;
  final String updatedAt;

  const DailyRecord({
    this.id,
    required this.date,
    required this.count,
    this.amountOverride,
    required this.updatedAt,
  });

  /// Calculates the effective amount for this day based on unit amount.
  /// If amountOverride is present, it takes precedence.
  double calculateAmount(double unitAmount) {
    if (amountOverride != null) {
      return amountOverride!;
    }
    return count * unitAmount;
  }

  DailyRecord copyWith({
    int? id,
    String? date,
    int? count,
    double? amountOverride,
    bool clearAmountOverride = false,
    String? updatedAt,
  }) {
    return DailyRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      count: count ?? this.count,
      amountOverride: clearAmountOverride ? null : (amountOverride ?? this.amountOverride),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'count': count,
      'amount_override': amountOverride,
      'updated_at': updatedAt,
    };
  }

  factory DailyRecord.fromMap(Map<String, dynamic> map) {
    return DailyRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      count: (map['count'] as num?)?.toInt() ?? 0,
      amountOverride: (map['amount_override'] as num?)?.toDouble(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory DailyRecord.empty(String date) {
    return DailyRecord(
      date: date,
      count: 0,
      amountOverride: null,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  String toString() {
    return 'DailyRecord(id: $id, date: $date, count: $count, amountOverride: $amountOverride, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyRecord &&
        other.id == id &&
        other.date == date &&
        other.count == count &&
        other.amountOverride == amountOverride &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, date, count, amountOverride, updatedAt);
  }
}
