import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/patients/data/patient_repository.dart';
import '../../features/patients/domain/patient_model.dart';
import '../../features/invoices/data/invoice_repository.dart';
import '../../features/invoices/domain/invoice_model.dart';
import '../../features/dashboard/domain/scheduled_notification_model.dart';
import '../../features/dashboard/data/scheduled_notification_repository.dart';
import 'auth_provider.dart';

class ExpiringPatientPlan {
  final Patient patient;
  final DateTime latestInvoiceDate;
  final DateTime expirationDate;
  final int hoursRemaining;
  final int calendarDaysRemaining;
  final bool isExpired;
  final String category; // 'expired', 'today', 'upcoming', 'scheduled'
  final int totalPlanDays;
  final bool isFirstInvoice;
  final ScheduledNotification? scheduledNotification;

  ExpiringPatientPlan({
    required this.patient,
    required this.latestInvoiceDate,
    required this.expirationDate,
    required this.hoursRemaining,
    required this.calendarDaysRemaining,
    required this.isExpired,
    required this.category,
    this.totalPlanDays = 30,
    this.isFirstInvoice = false,
    this.scheduledNotification,
  });

  String get id {
    if (scheduledNotification != null) {
      return 'sched_${scheduledNotification!.id}';
    }
    return 'plan_${patient.patientId}_${DateFormat('yyyyMMdd').format(expirationDate)}';
  }

  String get notificationMessage {
    if (scheduledNotification != null) {
      final note = scheduledNotification!.reminderNote.trim();
      final reason = note.isNotEmpty ? note : 'Scheduled Follow-Up';
      if (isExpired) {
        return "SCHEDULED REMINDER: ${patient.patientName} ($reason) was due on ${DateFormat('MMM d').format(expirationDate)}. Click to issue invoice.";
      } else {
        return "SCHEDULED REMINDER: ${patient.patientName} ($reason) scheduled for ${DateFormat('MMM d').format(expirationDate)}. Click to issue invoice.";
      }
    }

    final planType = isFirstInvoice ? 'initial $totalPlanDays-day registration' : '$totalPlanDays-day plan';
    final actionText = isFirstInvoice ? 'issue their first invoice' : 'issue renewal invoice';

    if (category == 'expired') {
      final hoursAgo = hoursRemaining.abs();
      if (hoursAgo < 24) {
        final h = hoursAgo < 1 ? 1 : hoursAgo;
        return "${patient.patientName}'s $planType expired $h hour${h == 1 ? '' : 's'} ago. Click here to $actionText.";
      }
      final daysAgo = calendarDaysRemaining < 0 ? calendarDaysRemaining.abs() : (hoursAgo / 24).floor();
      return "${patient.patientName}'s $planType expired $daysAgo day${daysAgo == 1 ? '' : 's'} ago on ${DateFormat('MMM d').format(expirationDate)}. Click to $actionText.";
    } else if (category == 'today') {
      if (hoursRemaining <= 0) {
        return "${patient.patientName}'s $planType expires today in less than an hour. Click here to $actionText.";
      }
      return "${patient.patientName}'s $planType expires today in $hoursRemaining hour${hoursRemaining == 1 ? '' : 's'}. Click here to $actionText.";
    } else {
      final days = calendarDaysRemaining > 0 ? calendarDaysRemaining : (hoursRemaining / 24).ceil();
      final prepText = isFirstInvoice ? 'Click to issue their first invoice.' : 'Click to prepare invoice.';
      return "${patient.patientName}'s $planType expires in $days day${days == 1 ? '' : 's'} on ${DateFormat('MMM d').format(expirationDate)}. $prepText";
    }
  }

  String get whatsappUrl {
    var phone = patient.phone.replaceAll(RegExp(r'[^\d+`]'), '').trim();
    if (phone.startsWith('0')) {
      phone = '92${phone.substring(1)}';
    } else if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }

    final servicesList = patient.selectedServices
        .map((s) => (s['serviceName'] ?? s['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(', ');

    final serviceText = servicesList.isNotEmpty ? servicesList : 'Home Health Care Services';
    final dateText = DateFormat('EEEE, MMM d, yyyy').format(expirationDate);

    String noteText = '';
    if (scheduledNotification != null && scheduledNotification!.reminderNote.isNotEmpty) {
      noteText = "\n\nReminder Note: ${scheduledNotification!.reminderNote}";
    }

    String msg;
    if (scheduledNotification != null) {
      msg =
          "Dear ${patient.patientName},\n\n"
          "Your Shifa Home Health Care service plan for ($serviceText) is scheduled for renewal on $dateText.$noteText\n\n"
          "Please pay your bill or contact us at Shifa Home Health Care to confirm your service renewal. Thank you!";
    } else if (category == 'expired') {
      msg =
          "Dear ${patient.patientName},\n\n"
          "Your Shifa Home Health Care service plan for ($serviceText) expired on $dateText.\n\n"
          "Please clear your invoice and contact us at Shifa Home Health Care to confirm your service renewal and ensure uninterrupted care. Thank you!";
    } else if (category == 'today') {
      msg =
          "Dear ${patient.patientName},\n\n"
          "This is a reminder that your Shifa Home Health Care service plan for ($serviceText) ends today ($dateText).\n\n"
          "Please clear your invoice or contact us at Shifa Home Health Care to confirm continuation of your services. Thank you!";
    } else {
      final days = calendarDaysRemaining > 0 ? calendarDaysRemaining : (hoursRemaining / 24).ceil();
      msg =
          "Dear ${patient.patientName},\n\n"
          "Friendly reminder that your Shifa Home Health Care service plan for ($serviceText) is scheduled for renewal in $days days on $dateText.\n\n"
          "Please contact us at Shifa Home Health Care to confirm your upcoming cycle. Thank you!";
    }

    return 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
  }
}

/// Pure calculation function for plan expirations, fully unit-testable
List<ExpiringPatientPlan> calculateExpiringPlans({
  required List<Patient> patients,
  required List<Invoice> invoices,
  required List<ScheduledNotification> standaloneScheduled,
  required DateTime now,
}) {
  final List<ExpiringPatientPlan> expiringList = [];
  final Set<String> processedIds = {};
  final dateOnlyNow = DateTime(now.year, now.month, now.day);

  // 1A. Process standalone scheduled_notifications collection
  for (final rem in standaloneScheduled) {
    if (rem.isCompleted) continue;
    if (rem.id.isNotEmpty) processedIds.add(rem.id);

    final patientMatches = patients.where((p) => p.patientId == rem.patientId).toList();
    final patient = patientMatches.isNotEmpty
        ? patientMatches.first
        : Patient(
            patientId: rem.patientId,
            mrNumber: rem.mrNumber,
            patientName: rem.patientName,
            cnic: '',
            phone: rem.phone,
            address: rem.address,
            diagnosis: '',
            doctor: '',
            nurse: '',
            caretaker: '',
            selectedServices: const [],
            monthlyServiceCost: 0,
            patientAmount: 0,
            staffPayment: 0,
            profit: 0,
            days: 0,
            assignedStaffId: '',
            organizationId: 'default',
            createdBy: rem.createdBy,
            createdAt: rem.createdAt,
            updatedBy: '',
            updatedAt: now,
          );

    final diff = rem.scheduledFor.difference(now);
    final dateOnlyExp = DateTime(rem.scheduledFor.year, rem.scheduledFor.month, rem.scheduledFor.day);
    final calendarDays = dateOnlyExp.difference(dateOnlyNow).inDays;

    expiringList.add(ExpiringPatientPlan(
      patient: patient,
      latestInvoiceDate: rem.createdAt,
      expirationDate: rem.scheduledFor,
      hoursRemaining: diff.inHours,
      calendarDaysRemaining: calendarDays,
      isExpired: diff.inHours < 0,
      category: 'scheduled',
      totalPlanDays: rem.targetDays > 0 ? rem.targetDays : 0,
      isFirstInvoice: false,
      scheduledNotification: rem,
    ));
  }

  // 1B. Process patient-nested scheduledReminders as backup
  for (final patient in patients) {
    if (patient.isDiscontinued || patient.isDeleted) continue;
    if (patient.scheduledReminders.isNotEmpty) {
      for (final rem in patient.scheduledReminders) {
        if (rem.isCompleted || (rem.id.isNotEmpty && processedIds.contains(rem.id))) continue;
        if (rem.id.isNotEmpty) processedIds.add(rem.id);

        final diff = rem.scheduledFor.difference(now);
        final dateOnlyExp = DateTime(rem.scheduledFor.year, rem.scheduledFor.month, rem.scheduledFor.day);
        final calendarDays = dateOnlyExp.difference(dateOnlyNow).inDays;

        expiringList.add(ExpiringPatientPlan(
          patient: patient,
          latestInvoiceDate: rem.createdAt,
          expirationDate: rem.scheduledFor,
          hoursRemaining: diff.inHours,
          calendarDaysRemaining: calendarDays,
          isExpired: diff.inHours < 0,
          category: 'scheduled',
          totalPlanDays: rem.targetDays > 0 ? rem.targetDays : 0,
          isFirstInvoice: false,
          scheduledNotification: rem,
        ));
      }
    }
  }

  // 2. Process automatic dynamic plan expirations (Invoices & New Patients)
  for (final patient in patients) {
    if (patient.isDiscontinued || patient.isDeleted) continue;

    final patientInvoices = invoices.where((inv) => inv.patientId == patient.patientId && !inv.isDeleted).toList();

    DateTime latestDate;
    DateTime expirationDate;
    int planDays;
    bool isFirstInvoice;

    if (patientInvoices.isNotEmpty) {
      // Sort by end of coverage descending (or createdAt descending)
      patientInvoices.sort((a, b) {
        final aEnd = a.toDate ?? (a.fromDate != null && a.days > 0 ? a.fromDate!.add(Duration(days: a.days)) : a.createdAt);
        final bEnd = b.toDate ?? (b.fromDate != null && b.days > 0 ? b.fromDate!.add(Duration(days: b.days)) : b.createdAt);
        return bEnd.compareTo(aEnd);
      });

      final latestInvoice = patientInvoices.first;
      latestDate = latestInvoice.createdAt;
      isFirstInvoice = false;

      // Extract plan days
      if (latestInvoice.days > 0) {
        planDays = latestInvoice.days;
      } else if (latestInvoice.toDate != null && latestInvoice.fromDate != null) {
        planDays = latestInvoice.toDate!.difference(latestInvoice.fromDate!).inDays;
        if (planDays <= 0) planDays = 1;
      } else {
        planDays = patient.days > 0 ? patient.days : 30;
      }

      // Exact expiration timestamp (inclusive end of coverage day)
      if (latestInvoice.toDate != null) {
        final td = latestInvoice.toDate!;
        expirationDate = DateTime(td.year, td.month, td.day, 23, 59, 59);
      } else if (latestInvoice.fromDate != null && planDays > 0) {
        final fd = latestInvoice.fromDate!;
        expirationDate = DateTime(fd.year, fd.month, fd.day, 23, 59, 59).add(Duration(days: planDays));
      } else {
        expirationDate = latestInvoice.createdAt.add(Duration(days: planDays));
      }
    } else {
      // No invoices yet: Newly registered patient!
      latestDate = patient.createdAt;
      isFirstInvoice = true;
      planDays = patient.days > 0 ? patient.days : 30;

      final start = patient.createdAt;
      expirationDate = DateTime(start.year, start.month, start.day, 23, 59, 59).add(Duration(days: planDays));
    }

    final dateOnlyExp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    final calendarDaysRemaining = dateOnlyExp.difference(dateOnlyNow).inDays;
    final difference = expirationDate.difference(now);
    final hoursRemaining = difference.inHours;

    String category;
    if (calendarDaysRemaining < 0 || hoursRemaining < 0) {
      category = 'expired';
    } else if (calendarDaysRemaining == 0 || hoursRemaining <= 24) {
      category = 'today';
    } else if (calendarDaysRemaining <= 7) { // Upcoming within 7 days
      category = 'upcoming';
    } else {
      // More than 7 days remaining: Service is currently active, no notification needed
      continue;
    }

    // Keep active/recent notifications (within 30 days of expiry)
    if (difference.inDays > -30) {
      expiringList.add(ExpiringPatientPlan(
        patient: patient,
        latestInvoiceDate: latestDate,
        expirationDate: expirationDate,
        hoursRemaining: hoursRemaining,
        calendarDaysRemaining: calendarDaysRemaining,
        isExpired: hoursRemaining < 0 || calendarDaysRemaining < 0,
        category: category,
        totalPlanDays: planDays,
        isFirstInvoice: isFirstInvoice,
      ));
    }
  }

  // Sort by most urgent (lowest hoursRemaining first)
  expiringList.sort((a, b) => a.hoursRemaining.compareTo(b.hoursRemaining));
  return expiringList;
}

class DismissedNotificationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void dismiss(String id) {
    state = {...state, id};
  }

  void undo(String id) {
    state = state.where((item) => item != id).toSet();
  }

  void clearAll() {
    state = <String>{};
  }
}

final dismissedNotificationsProvider = NotifierProvider<DismissedNotificationsNotifier, Set<String>>(
  DismissedNotificationsNotifier.new,
);

final expiringPlansProvider = StreamProvider<List<ExpiringPatientPlan>>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  final role = profile?['role'] ?? 'staff';

  final patientsAsync = role == 'admin'
      ? ref.watch(allPatientsProvider(false))
      : ref.watch(staffPatientsProvider);

  final invoicesAsync = role == 'admin'
      ? ref.watch(allInvoicesProvider(false))
      : ref.watch(staffInvoicesProvider);

  final standaloneScheduledAsync = ref.watch(activeScheduledNotificationsProvider);
  final dismissedIds = ref.watch(dismissedNotificationsProvider);

  final patients = patientsAsync.value ?? [];
  final invoices = invoicesAsync.value ?? [];
  final standaloneScheduled = standaloneScheduledAsync.value ?? [];

  final expiringList = calculateExpiringPlans(
    patients: patients,
    invoices: invoices,
    standaloneScheduled: standaloneScheduled,
    now: DateTime.now(),
  );

  final activeList = expiringList.where((p) => !dismissedIds.contains(p.id)).toList();
  return Stream.value(activeList);
});
