class AuditLog {
  final String id;
  final String userId;
  final String actionType;
  final String? ipAddressRedacted;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.actionType,
    this.ipAddressRedacted,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        actionType: json['action_type'] as String? ?? 'UNKNOWN',
        ipAddressRedacted: json['ip_address_redacted'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'action_type': actionType,
        'ip_address_redacted': ipAddressRedacted,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };
}
