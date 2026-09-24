import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/scheduled_notification_model.dart';
import '../../../shared/providers/auth_provider.dart';

final scheduledNotificationRepositoryProvider = Provider<ScheduledNotificationRepository>((ref) {
  return ScheduledNotificationRepository(ref.watch(supabaseClientProvider));
});

final activeScheduledNotificationsProvider = StreamProvider<List<ScheduledNotification>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(<ScheduledNotification>[]);
  }

  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('scheduled_notifications')
      .stream(primaryKey: ['id'])
      .map((rows) {
        return rows
            .map((doc) => ScheduledNotification.fromMap(doc, (doc['id'] ?? '').toString()))
            .where((n) => !n.isCompleted)
            .toList();
      }).handleError((err) {
        return <ScheduledNotification>[];
      });
});

class ScheduledNotificationRepository {
  final SupabaseClient _supabase;

  ScheduledNotificationRepository(this._supabase);

  Future<void> addScheduledNotification(ScheduledNotification notification) async {
    final idStr = notification.id.isNotEmpty ? notification.id : DateTime.now().millisecondsSinceEpoch.toString();

    final reminderMap = {
      'id': idStr,
      'title': notification.reminderNote.isNotEmpty ? notification.reminderNote : 'Care Plan Reminder',
      'message': 'Patient: ${notification.patientName} (${notification.mrNumber})',
      'scheduled_time': notification.scheduledFor.toIso8601String(),
      'patient_id': notification.patientId,
      'is_sent': notification.isCompleted,
      'created_at': notification.createdAt.toIso8601String(),
    };

    await _supabase.from('scheduled_notifications').insert(reminderMap);
  }

  Future<void> markAsCompleted(String patientId, String reminderId) async {
    try {
      await _supabase.from('scheduled_notifications').update({
        'is_sent': true,
      }).eq('id', reminderId);
    } catch (_) {}
  }

  Future<void> deleteScheduledNotification(String patientId, String reminderId) async {
    try {
      await _supabase.from('scheduled_notifications').delete().eq('id', reminderId);
    } catch (_) {}
  }
}
