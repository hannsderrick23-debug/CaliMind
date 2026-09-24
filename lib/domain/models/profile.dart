class PrivacyProfile {
  final String userId;
  final int dataRetentionDays;
  final bool allowEmailProcessing;
  final bool marketingOptIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PrivacyProfile({
    required this.userId,
    this.dataRetentionDays = 90,
    this.allowEmailProcessing = true,
    this.marketingOptIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrivacyProfile.fromJson(Map<String, dynamic> json) => PrivacyProfile(
        userId: json['user_id'] as String? ?? '',
        dataRetentionDays: json['data_retention_days'] as int? ?? 90,
        allowEmailProcessing: json['allow_email_processing'] as bool? ?? true,
        marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'data_retention_days': dataRetentionDays,
        'allow_email_processing': allowEmailProcessing,
        'marketing_opt_in': marketingOptIn,
        'updated_at': DateTime.now().toIso8601String(),
      };

  PrivacyProfile copyWith({
    int? dataRetentionDays,
    bool? allowEmailProcessing,
    bool? marketingOptIn,
  }) =>
      PrivacyProfile(
        userId: userId,
        dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
        allowEmailProcessing: allowEmailProcessing ?? this.allowEmailProcessing,
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
