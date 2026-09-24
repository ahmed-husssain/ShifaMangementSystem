import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/domain/scheduled_notification_model.dart';

class Patient {
  final String patientId;
  final String mrNumber;
  final String patientName;
  final String cnic;
  final String phone;
  final String address;
  final String diagnosis;
  final String doctor;
  final String nurse;
  final String caretaker;
  final List<Map<String, dynamic>> selectedServices;
  final double monthlyServiceCost;
  final double patientAmount;
  final double staffPayment;
  final double profit;
  final int days;
  final String assignedStaffId;
  final String organizationId;
  final String createdBy;
  final DateTime createdAt;
  final String updatedBy;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool isDiscontinued;
  final DateTime? discontinuedAt;
  final String? discontinuedBy;
  final DateTime? reactivatedAt;
  final String? reactivatedBy;
  final List<ScheduledNotification> scheduledReminders;

  Patient({
    required this.patientId,
    required this.mrNumber,
    required this.patientName,
    required this.cnic,
    required this.phone,
    required this.address,
    required this.diagnosis,
    required this.doctor,
    required this.nurse,
    required this.caretaker,
    required this.selectedServices,
    required this.monthlyServiceCost,
    required this.patientAmount,
    required this.staffPayment,
    required this.profit,
    this.days = 0,
    required this.assignedStaffId,
    required this.organizationId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.isDiscontinued = false,
    this.discontinuedAt,
    this.discontinuedBy,
    this.reactivatedAt,
    this.reactivatedBy,
    this.scheduledReminders = const [],
  });

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is Map && val.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch((val['_seconds'] as int) * 1000);
    }
    return null;
  }

  factory Patient.fromMap(Map<String, dynamic> data, String documentId) {
    List<ScheduledNotification> reminders = [];
    final rawReminders = data['scheduledReminders'] ?? data['scheduled_reminders'];
    if (rawReminders != null && rawReminders is List) {
      for (final item in rawReminders) {
        if (item is Map) {
          try {
            reminders.add(ScheduledNotification.fromMap(Map<String, dynamic>.from(item), (item['id'] ?? '').toString()));
          } catch (_) {}
        }
      }
    }

    final now = DateTime.now();

    return Patient(
      patientId: documentId,
      mrNumber: (data['mrNumber'] ?? data['mr_number'] ?? '').toString(),
      patientName: (data['patientName'] ?? data['patient_name'] ?? '').toString(),
      cnic: (data['cnic'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      diagnosis: (data['diagnosis'] ?? '').toString(),
      doctor: (data['doctor'] ?? '').toString(),
      nurse: (data['nurse'] ?? '').toString(),
      caretaker: (data['caretaker'] ?? '').toString(),
      selectedServices: List<Map<String, dynamic>>.from(data['selectedServices'] ?? data['selected_services'] ?? []),
      monthlyServiceCost: (data['monthlyServiceCost'] ?? data['monthly_service_cost'] ?? 0.0).toDouble(),
      patientAmount: (data['patientAmount'] ?? data['patient_amount'] ?? 0.0).toDouble(),
      staffPayment: (data['staffPayment'] ?? data['staff_payment'] ?? 0.0).toDouble(),
      profit: (data['profit'] ?? 0.0).toDouble(),
      days: (data['days'] is num ? (data['days'] as num).toInt() : int.tryParse(data['days']?.toString() ?? '0') ?? 0),
      assignedStaffId: (data['assignedStaffId'] ?? data['assigned_staff_id'] ?? '').toString(),
      organizationId: (data['organizationId'] ?? data['organization_id'] ?? 'default').toString(),
      createdBy: (data['createdBy'] ?? data['created_by'] ?? '').toString(),
      createdAt: _parseDate(data['createdAt'] ?? data['created_at']) ?? now,
      updatedBy: (data['updatedBy'] ?? data['updated_by'] ?? '').toString(),
      updatedAt: _parseDate(data['updatedAt'] ?? data['updated_at']) ?? now,
      isDeleted: data['isDeleted'] ?? data['is_deleted'] ?? false,
      deletedAt: _parseDate(data['deletedAt'] ?? data['deleted_at']),
      deletedBy: data['deletedBy'] ?? data['deleted_by'],
      isDiscontinued: data['isDiscontinued'] ?? data['is_discontinued'] ?? (data['status'] == 'discontinued'),
      discontinuedAt: _parseDate(data['discontinuedAt'] ?? data['discontinued_at']),
      discontinuedBy: data['discontinuedBy'] ?? data['discontinued_by'],
      reactivatedAt: _parseDate(data['reactivatedAt'] ?? data['reactivated_at']),
      reactivatedBy: data['reactivatedBy'] ?? data['reactivated_by'],
      scheduledReminders: reminders,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mrNumber': mrNumber,
      'patientName': patientName,
      'cnic': cnic,
      'phone': phone,
      'address': address,
      'diagnosis': diagnosis,
      'doctor': doctor,
      'nurse': nurse,
      'caretaker': caretaker,
      'selectedServices': selectedServices,
      'monthlyServiceCost': monthlyServiceCost,
      'patientAmount': patientAmount,
      'staffPayment': staffPayment,
      'profit': profit,
      'days': days,
      'assignedStaffId': assignedStaffId,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'isDiscontinued': isDiscontinued,
      'discontinuedAt': discontinuedAt,
      'discontinuedBy': discontinuedBy,
      'reactivatedAt': reactivatedAt,
      'reactivatedBy': reactivatedBy,
      'scheduledReminders': scheduledReminders.map((r) => r.toMap()).toList(),
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': patientId,
      'patient_name': patientName,
      'mr_number': mrNumber,
      'cnic': cnic,
      'phone': phone,
      'address': address,
      'diagnosis': diagnosis,
      'doctor': doctor,
      'nurse': nurse,
      'caretaker': caretaker,
      'selected_services': selectedServices,
      'monthly_service_cost': monthlyServiceCost,
      'patient_amount': patientAmount,
      'staff_payment': staffPayment,
      'profit': profit,
      'days': days,
      'assigned_staff_id': assignedStaffId,
      'organization_id': organizationId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'deleted_by': deletedBy,
      'is_discontinued': isDiscontinued,
      'discontinued_at': discontinuedAt?.toIso8601String(),
      'discontinued_by': discontinuedBy,
      'reactivated_at': reactivatedAt?.toIso8601String(),
      'reactivated_by': reactivatedBy,
      'scheduled_reminders': scheduledReminders.map((r) => r.toMap()).toList(),
    };
  }
}
