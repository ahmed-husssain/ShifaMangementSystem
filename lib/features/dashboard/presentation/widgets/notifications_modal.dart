import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/providers/plan_expiration_provider.dart';
import '../../../invoices/presentation/invoice_form_screen.dart';
import '../../data/scheduled_notification_repository.dart';
import 'schedule_notification_modal.dart';

class NotificationsModal extends ConsumerStatefulWidget {
  const NotificationsModal({super.key});

  @override
  ConsumerState<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends ConsumerState<NotificationsModal> {
  String _selectedFilter = 'all'; // 'all', 'expired', 'today', 'upcoming', 'scheduled'

  Future<void> _launchWhatsApp(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    try {
      final uri = Uri.parse('tel:$clean');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place call: $e')),
        );
      }
    }
  }

  Future<void> _handleDone(ExpiringPatientPlan item) async {
    final name = item.patient.patientName;
    if (item.scheduledNotification != null) {
      try {
        await ref
            .read(scheduledNotificationRepositoryProvider)
            .markAsCompleted(item.patient.patientId, item.scheduledNotification!.id);
      } catch (_) {}
    }
    ref.read(dismissedNotificationsProvider.notifier).dismiss(item.id);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Plan notification for $name marked as handled!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amberAccent,
            onPressed: () {
              ref.read(dismissedNotificationsProvider.notifier).undo(item.id);
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleDelete(ExpiringPatientPlan item) async {
    final name = item.patient.patientName;
    if (item.scheduledNotification != null) {
      try {
        await ref
            .read(scheduledNotificationRepositoryProvider)
            .deleteScheduledNotification(item.patient.patientId, item.scheduledNotification!.id);
      } catch (_) {}
    }
    ref.read(dismissedNotificationsProvider.notifier).dismiss(item.id);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dismissed notification for $name'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amberAccent,
            onPressed: () {
              ref.read(dismissedNotificationsProvider.notifier).undo(item.id);
            },
          ),
        ),
      );
    }
  }

  void _openScheduleModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScheduleNotificationModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiringPlansAsync = ref.watch(expiringPlansProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Modal Title & + Schedule Reminder Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Color(0xFF1565C0), size: 22),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'PLAN NOTIFICATIONS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openScheduleModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_alarm_rounded, size: 14),
                        label: const Text(
                          '+ Schedule',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Content & Filter Logic
              Expanded(
                child: expiringPlansAsync.when(
                  data: (allPlans) {
                    final expiredCount = allPlans.where((p) => p.category == 'expired' || (p.category == 'scheduled' && p.hoursRemaining < 0)).length;
                    final todayCount = allPlans.where((p) => p.category == 'today' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 24)).length;
                    final upcomingCount = allPlans.where((p) => p.category == 'upcoming' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 168)).length;
                    final scheduledCount = allPlans.where((p) => p.category == 'scheduled').length;

                    // Filter list based on selected tab
                    final filteredPlans = allPlans.where((p) {
                      if (_selectedFilter == 'expired') {
                        return p.category == 'expired' || (p.category == 'scheduled' && p.hoursRemaining < 0);
                      }
                      if (_selectedFilter == 'today') {
                        return p.category == 'today' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 24);
                      }
                      if (_selectedFilter == 'upcoming') {
                        return p.category == 'upcoming' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 168);
                      }
                      if (_selectedFilter == 'scheduled') {
                        return p.category == 'scheduled';
                      }
                      return true;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Interactive Urgency & Scheduled Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildUrgencyChip('All', 'all', allPlans.length, Colors.blue.shade700),
                              const SizedBox(width: 8),
                              _buildUrgencyChip('📌 Scheduled', 'scheduled', scheduledCount, Colors.indigo.shade700),
                              const SizedBox(width: 8),
                              _buildUrgencyChip('🔴 Expired', 'expired', expiredCount, Colors.red.shade700),
                              const SizedBox(width: 8),
                              _buildUrgencyChip('🟡 Expiring Today', 'today', todayCount, Colors.orange.shade800),
                              const SizedBox(width: 8),
                              _buildUrgencyChip('🔵 Upcoming (7 Days)', 'upcoming', upcomingCount, Colors.teal.shade700),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Expanded(
                          child: filteredPlans.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade400),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No notifications in this category.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: filteredPlans.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filteredPlans[index];
                                    final p = item.patient;
                                    final isScheduled = item.category == 'scheduled';

                                    Color accentColor;
                                    Color bgColor;
                                    String tagText;

                                    if (isScheduled) {
                                      accentColor = Colors.indigo.shade700;
                                      bgColor = Colors.indigo.shade50;
                                      tagText = item.scheduledNotification != null && item.scheduledNotification!.targetDays > 0
                                          ? '${item.scheduledNotification!.targetDays}-DAY REMINDER'
                                          : 'SCHEDULED';
                                    } else if (item.category == 'expired') {
                                      accentColor = Colors.red.shade700;
                                      bgColor = Colors.red.shade50;
                                      tagText = item.isFirstInvoice ? 'INITIAL PLAN EXPIRED' : '${item.totalPlanDays}-DAY PLAN EXPIRED';
                                    } else if (item.category == 'today') {
                                      accentColor = Colors.orange.shade800;
                                      bgColor = Colors.amber.shade50;
                                      tagText = 'EXPIRES TODAY (${item.totalPlanDays}D)';
                                    } else {
                                      accentColor = Colors.teal.shade700;
                                      bgColor = Colors.teal.shade50;
                                      final daysLeft = (item.hoursRemaining / 24).ceil();
                                      tagText = 'IN $daysLeft DAYS • ${DateFormat("MMM d").format(item.expirationDate)}';
                                    }

                                    final careTeam = [
                                      if (p.doctor.isNotEmpty) 'Doc: ${p.doctor}',
                                      if (p.nurse.isNotEmpty) 'Nurse: ${p.nurse}',
                                      if (p.caretaker.isNotEmpty) 'Care: ${p.caretaker}',
                                    ].join(' • ');

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Notification Header
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius: BorderRadius.circular(9),
                                                ),
                                                child: Icon(
                                                  isScheduled
                                                      ? Icons.event_available_rounded
                                                      : (item.category == 'expired'
                                                          ? Icons.warning_amber_rounded
                                                          : (item.category == 'today'
                                                              ? Icons.timer_outlined
                                                              : Icons.calendar_today_rounded)),
                                                  color: accentColor,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            p.patientName.trim(),
                                                            style: const TextStyle(
                                                              fontSize: 13.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: Color(0xFF0F172A),
                                                              letterSpacing: -0.1,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: bgColor,
                                                            borderRadius: BorderRadius.circular(5),
                                                            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                                                          ),
                                                          child: Text(
                                                            tagText,
                                                            style: TextStyle(
                                                              fontSize: 8.5,
                                                              fontWeight: FontWeight.w800,
                                                              color: accentColor,
                                                              letterSpacing: 0.3,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item.notificationMessage,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.blueGrey.shade800,
                                                        height: 1.25,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Patient Context & Care Team Details
                                          if (p.phone.isNotEmpty || p.address.isNotEmpty || careTeam.isNotEmpty || p.selectedServices.isNotEmpty) ...[
                                            const SizedBox(height: 9),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.grey.shade300),
                                                        ),
                                                        child: Text(
                                                          'MR: ${p.mrNumber}',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.grey.shade800,
                                                          ),
                                                        ),
                                                      ),
                                                      if (p.phone.isNotEmpty) ...[
                                                        const SizedBox(width: 8),
                                                        Icon(Icons.phone_outlined, size: 11, color: Colors.grey.shade600),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          p.phone,
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                                        ),
                                                      ],
                                                      if (p.selectedServices.isNotEmpty) ...[
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            '• ${p.selectedServices.map((s) => (s['serviceName'] ?? s['name'] ?? '').toString()).where((s) => s.isNotEmpty).join(', ')}',
                                                            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (p.address.isNotEmpty || careTeam.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        if (p.address.isNotEmpty) ...[
                                                          Icon(Icons.location_on_outlined, size: 11, color: Colors.grey.shade500),
                                                          const SizedBox(width: 3),
                                                          Expanded(
                                                            child: Text(
                                                              p.address,
                                                              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                        if (p.address.isNotEmpty && careTeam.isNotEmpty) const SizedBox(width: 8),
                                                        if (careTeam.isNotEmpty) ...[
                                                          Icon(Icons.medical_services_outlined, size: 11, color: Colors.indigo.shade400),
                                                          const SizedBox(width: 3),
                                                          Flexible(
                                                            child: Text(
                                                              careTeam,
                                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: Colors.indigo.shade700),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 10),

                                          // Action Buttons: Single Unified Executive Row
                                          Row(
                                            children: [
                                              // Primary Action: Issue Invoice Button
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  final daysToUse = isScheduled && item.scheduledNotification != null && item.scheduledNotification!.targetDays > 0
                                                      ? item.scheduledNotification!.targetDays
                                                      : (item.totalPlanDays > 0 ? item.totalPlanDays : 30);
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => InvoiceFormScreen(patientId: p.patientId, defaultDays: daysToUse),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF1565C0),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                                ),
                                                icon: const Icon(Icons.receipt_long_rounded, size: 12),
                                                label: Text(
                                                  item.isFirstInvoice ? 'First Invoice ➔' : 'Issue Invoice ➔',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 5),

                                              // 1-Click WhatsApp Button
                                              OutlinedButton.icon(
                                                onPressed: () => _launchWhatsApp(item.whatsappUrl),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF128C7E),
                                                  side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                                                  backgroundColor: const Color(0xFFF0FDF4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6.5),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                                ),
                                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF25D366)),
                                                label: const Text(
                                                  'WhatsApp',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),

                                              // Direct Call Button
                                              if (p.phone.isNotEmpty) ...[
                                                const SizedBox(width: 5),
                                                Tooltip(
                                                  message: 'Direct Call (${p.phone})',
                                                  child: InkWell(
                                                    onTap: () => _launchCall(p.phone),
                                                    borderRadius: BorderRadius.circular(7),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(7),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.phone_in_talk_rounded, color: Colors.blue.shade700, size: 12),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            'Call',
                                                            style: TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.blue.shade800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],

                                              const Spacer(),

                                              // Done / Handled Button (for all notifications)
                                              Tooltip(
                                                message: 'Mark as Handled / Done',
                                                child: InkWell(
                                                  onTap: () => _handleDone(item),
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade50,
                                                      borderRadius: BorderRadius.circular(7),
                                                      border: Border.all(color: Colors.green.shade300),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 13),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          'Done',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.green.shade800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 5),

                                              // Delete / Dismiss Button (for all notifications)
                                              Tooltip(
                                                message: 'Dismiss / Delete Notification',
                                                child: InkWell(
                                                  onTap: () => _handleDelete(item),
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius: BorderRadius.circular(7),
                                                      border: Border.all(color: Colors.red.shade200),
                                                    ),
                                                    child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 13),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading notifications: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUrgencyChip(String label, String value, int count, Color color) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
    );
  }
}
