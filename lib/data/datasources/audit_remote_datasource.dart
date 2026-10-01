import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/audit_log.dart';

abstract class AuditRemoteDatasource {
  Future<List<AuditLog>> fetchAuditLogs({int limit = 50});
  Future<void> writeLog(String actionType, {Map<String, dynamic>? metadata});
}

class AuditRemoteDatasourceImpl implements AuditRemoteDatasource {
  final List<AuditLog> _mockLogs = [];

  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) return Supabase.instance.client;
    } catch (_) {}
    return null;
  }

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return 'mock-user';
    }
  }

  @override
  Future<List<AuditLog>> fetchAuditLogs({int limit = 50}) async {
    final client = _client;
    final uid = _userId;
    if (client != null && uid != null && uid != 'mock-user') {
      try {
        final res = await client
            .from('audit_logs')
            .select()
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(limit);
        return (res as List).map((row) => AuditLog.fromJson(row as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Fetch audit logs error: $e');
      }
    }
    return List.from(_mockLogs.take(limit));
  }

  @override
  Future<void> writeLog(String actionType, {Map<String, dynamic>? metadata}) async {
    final uid = _userId ?? 'mock-user';
    final log = AuditLog(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      actionType: actionType,
      ipAddressRedacted: null,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final client = _client;
    if (client != null && uid != 'mock-user') {
      try {
        await client.from('audit_logs').insert({
          'user_id': uid,
          'action_type': actionType,
          'metadata': metadata,
        });
        return;
      } catch (e) {
        debugPrint('Write audit log error: $e');
      }
    }

    _mockLogs.insert(0, log);
    if (_mockLogs.length > 100) _mockLogs.removeLast();
  }
}
