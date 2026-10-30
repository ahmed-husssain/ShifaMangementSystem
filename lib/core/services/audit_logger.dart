import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized, defensive audit logging service.
/// Ensures audit logging failures never crash primary business transactions.
class AuditLogger {
  static Future<void> log({
    required SupabaseClient supabase,
    required String action,
    required String entityType,
    required String entityId,
    required String description,
    required String organizationId,
    String? userId,
    String? userName,
    String? role,
  }) async {
    try {
      final effectiveUserId = userId ?? supabase.auth.currentUser?.id ?? 'system';
      final effectiveRole = role ?? 'staff';
      final now = DateTime.now().toIso8601String();

      await supabase.from('activities').insert({
        'user_id': effectiveUserId,
        'user_name': (userName != null && userName.isNotEmpty) ? userName : 'User',
        'role': effectiveRole,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'description': description,
        'organization_id': organizationId,
        'timestamp': now,
      });
    } catch (e) {
      debugPrint('⚠️ [AuditLogger] Failed to record activity log ($action on $entityType): $e');
    }
  }
}
