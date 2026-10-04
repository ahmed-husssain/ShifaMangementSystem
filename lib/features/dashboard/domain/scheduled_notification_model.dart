class ScheduledNotification {
  final String id;
  final String patientId;
  final String patientName;
  final String mrNumber;
  final String phone;
  final String address;
  final String reminderNote;
  final int targetDays; // e.g. 4, 7, 14, 0 for custom
  final DateTime scheduledFor;
  final DateTime createdAt;
  final String createdBy;
  final bool isCompleted;

  ScheduledNotification({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.mrNumber,
    required this.phone,
    required this.address,
    required this.reminderNote,
    required this.targetDays,
    required this.scheduledFor,
    required this.createdAt,
    required this.createdBy,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'mrNumber': mrNumber,
      'phone': phone,
      'address': address,
      'reminderNote': reminderNote,
      'targetDays': targetDays,
      'scheduledFor': scheduledFor.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isCompleted': isCompleted,
    };
  }

  factory ScheduledNotification.fromMap(Map<dynamic, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is Map) {
        if (val['_seconds'] != null) {
          final sec = val['_seconds'];
          if (sec is num) {
            return DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
          }
        }
        if (val['seconds'] != null) {
          final sec = val['seconds'];
          if (sec is num) {
            return DateTime.fromMillisecondsSinceEpoch(sec.toInt() * 1000);
          }
        }
      }
      return DateTime.now();
    }

    final parsedId = (docId.isNotEmpty ? docId : (map['id'] ?? '')).toString();

    String patientName = (map['patientName'] ?? map['patient_name'] ?? '').toString();
    String mrNumber = (map['mrNumber'] ?? map['mr_number'] ?? '').toString();
    final message = (map['message'] ?? '').toString();
    if (patientName.isEmpty && message.isNotEmpty) {
      final nameMatch = RegExp(r'Patient:\s*([^(]+)').firstMatch(message);
      if (nameMatch != null) {
        patientName = nameMatch.group(1)!.trim();
      }
    }
    if (mrNumber.isEmpty && message.isNotEmpty) {
      final mrMatch = RegExp(r'\(([^)]+)\)').firstMatch(message);
      if (mrMatch != null) {
        mrNumber = mrMatch.group(1)!.trim();
      }
    }

    return ScheduledNotification(
      id: parsedId,
      patientId: (map['patientId'] ?? map['patient_id'] ?? '').toString(),
      patientName: patientName,
      mrNumber: mrNumber,
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      reminderNote: (map['reminderNote'] ?? map['title'] ?? '').toString(),
      targetDays: map['targetDays'] != null ? (int.tryParse(map['targetDays'].toString()) ?? 0) : 0,
      scheduledFor: parseDate(map['scheduledFor'] ?? map['scheduled_time']),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      createdBy: (map['createdBy'] ?? map['created_by'] ?? '').toString(),
      isCompleted: map['isCompleted'] == true || map['is_sent'] == true,
    );
  }
}
