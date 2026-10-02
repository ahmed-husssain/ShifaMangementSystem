import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/providers/plan_expiration_provider.dart';
import '../../../../core/services/device_notification_service.dart';
import '../../../invoices/presentation/invoice_form_screen.dart';
import '../../data/scheduled_notification_repository.dart';
import '../providers/staff_filter_provider.dart';
import 'schedule_notification_modal.dart';
import 'staff_filter_bar.dart';

class NotificationsModal extends ConsumerStatefulWidget {
  const NotificationsModal({super.key});

  @override
  ConsumerState<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends ConsumerState<NotificationsModal> {
  String _selectedFilter = 'all'; // 'all', 'expired', 'today', 'upcoming', 'scheduled'

  @override
  void initState() {
    super.initState();
    DeviceNotificationService.instance.initialize();
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Modal Title & Action Bar (Optimized for Mobile Viewports)
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Test Alert Icon Action
                  Tooltip(
                    message: 'Test Phone Alert',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final ok = await DeviceNotificationService.instance.showTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '🔔 Test phone alert sent! Check your notification bar or lock screen.'
                                      : 'Alert sent. Please check your notification permissions.',
                                ),
                                backgroundColor: const Color(0xFF1565C0),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phonelink_ring_rounded, size: 13, color: Colors.blue.shade700),
                              const SizedBox(width: 3),
                              Text(
                                'Test',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // + Schedule Button
                  ElevatedButton.icon(
                    onPressed: _openScheduleModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_alarm_rounded, size: 12),
                    label: const Text(
                      '+ Schedule',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Close Button
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 19, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Content & Filter Logic
              Expanded(
                child: expiringPlansAsync.when(
                  data: (allPlans) {
                    // Synchronize phone lock-screen alerts for due-today or expired plans
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      DeviceNotificationService.instance.syncPlanAlerts(allPlans);
                    });

                    final effectivePlans = ref.watch(staffFilteredExpiringPlansProvider);

                    final expiredCount = effectivePlans.where((p) => p.category == 'expired' || (p.category == 'scheduled' && p.hoursRemaining < 0)).length;
                    final todayCount = effectivePlans.where((p) => p.category == 'today' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 24)).length;
                    final upcomingCount = effectivePlans.where((p) => p.category == 'upcoming' || (p.category == 'scheduled' && p.hoursRemaining >= 0 && p.hoursRemaining <= 168)).length;
                    final scheduledCount = effectivePlans.where((p) => p.category == 'scheduled').length;

                    // Filter list based on selected tab
                    final filteredPlans = effectivePlans.where((p) {
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
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildUrgencyChip('All', 'all', effectivePlans.length, Colors.blue.shade700),
                              const SizedBox(width: 6),
                              _buildUrgencyChip('Scheduled', 'scheduled', scheduledCount, Colors.indigo.shade700, icon: Icons.event_available_rounded),
                              const SizedBox(width: 6),
                              _buildUrgencyChip('Expired', 'expired', expiredCount, Colors.red.shade700, icon: Icons.error_outline_rounded),
                              const SizedBox(width: 6),
                              _buildUrgencyChip('Today', 'today', todayCount, Colors.orange.shade800, icon: Icons.alarm_rounded),
                              const SizedBox(width: 6),
                              _buildUrgencyChip('Upcoming', 'upcoming', upcomingCount, Colors.teal.shade700, icon: Icons.calendar_month_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Admin Multi-Staff Queue Filter Bar (only renders if admin)
                        const StaffFilterBar(),
                        const SizedBox(height: 8),

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
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                                                    ],
                                                  ),
                                                  if (p.selectedServices.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.medical_information_outlined, size: 10.5, color: Colors.blueGrey.shade400),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            p.selectedServices.map((s) => (s['serviceName'] ?? s['name'] ?? '').toString()).where((s) => s.isNotEmpty).join(', '),
                                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: Colors.blueGrey.shade700),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                  if (p.address.isNotEmpty || careTeam.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        if (p.address.isNotEmpty) ...[
                                                          Icon(Icons.location_on_outlined, size: 10.5, color: Colors.grey.shade500),
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
                                                          Icon(Icons.health_and_safety_outlined, size: 10.5, color: Colors.indigo.shade400),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            careTeam,
                                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.indigo.shade700),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),

                                          // Action Buttons: 2-Tier Senior Architecture (Zero Overflow on 360px)
                                          // Tier 1: Primary Executive CTAs (Issue Invoice & WhatsApp)
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    final daysToUse = isScheduled && item.scheduledNotification != null && item.scheduledNotification!.targetDays > 0
                                                        ? item.scheduledNotification!.targetDays
                                                        : (item.totalPlanDays > 0 ? item.totalPlanDays : 30);
                                                    
                                                    // Zero-gap billing date continuity
                                                    final DateTime targetFromDate;
                                                    if (item.isFirstInvoice) {
                                                      targetFromDate = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
                                                    } else {
                                                      final exp = item.expirationDate;
                                                      targetFromDate = DateTime(exp.year, exp.month, exp.day).add(const Duration(days: 1));
                                                    }

                                                    Navigator.pop(context);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => InvoiceFormScreen(
                                                          patientId: p.patientId,
                                                          defaultDays: daysToUse,
                                                          initialFromDate: targetFromDate,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1565C0),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.receipt_long_rounded, size: 13),
                                                  label: Text(
                                                    item.isFirstInvoice ? 'First Invoice ➔' : 'Issue Invoice ➔',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _launchWhatsApp(item.whatsappUrl),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF128C7E),
                                                    side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                                                    backgroundColor: const Color(0xFFF0FDF4),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF25D366)),
                                                  label: const Text(
                                                    'WhatsApp',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Tier 2: Utility & Resolution Bar (Direct Call, Mark Done, Dismiss)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Direct Call Button
                                              if (p.phone.isNotEmpty)
                                                Tooltip(
                                                  message: 'Direct Call (${p.phone})',
                                                  child: InkWell(
                                                    onTap: () => _launchCall(p.phone),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.phone_in_talk_rounded, color: Colors.blue.shade700, size: 11),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Call',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.blue.shade800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                const SizedBox.shrink(),

                                              // Resolution Cluster (Done & Dismiss)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Tooltip(
                                                    message: 'Mark as Handled / Done',
                                                    child: InkWell(
                                                      onTap: () => _handleDone(item),
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade50,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.green.shade300),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 12),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Done',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.green.shade800,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Tooltip(
                                                    message: 'Dismiss / Delete Notification',
                                                    child: InkWell(
                                                      onTap: () => _handleDelete(item),
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade50,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.red.shade200),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 12),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              'Dismiss',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.red.shade700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
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

  Widget _buildUrgencyChip(String label, String value, int count, Color color, {IconData? icon}) {
    final isSelected = _selectedFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: isSelected ? Colors.white : color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
