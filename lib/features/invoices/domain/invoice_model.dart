import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String serviceName;
  final double price;
  final int quantity;

  InvoiceItem({
    required this.serviceName,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  factory InvoiceItem.fromMap(Map<String, dynamic> data) {
    return InvoiceItem(
      serviceName: data['serviceName'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceName': serviceName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}

class Invoice {
  final String invoiceId;
  final String invoiceNumber;
  final String patientId;
  final String staffId;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final List<InvoiceItem> items;
  final String organizationId;
  final String createdBy;
  final DateTime createdAt;
  final String updatedBy;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String paymentStatus;
  final bool isDiscontinued;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int days;
  final String? createdByName;
  final String? createdByRole;
  final String? createdByUid;

  Invoice({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.patientId,
    required this.staffId,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.items,
    required this.organizationId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.paymentStatus = 'Unpaid',
    this.isDiscontinued = false,
    this.fromDate,
    this.toDate,
    this.days = 0,
    this.createdByName,
    this.createdByRole,
    this.createdByUid,
  });

  factory Invoice.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is Map && val.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch((val['_seconds'] as int) * 1000);
      }
      return null;
    }

    int parsedDays = 0;
    if (data['days'] is num) {
      parsedDays = (data['days'] as num).toInt();
    } else if (data['days'] != null) {
      parsedDays = int.tryParse(data['days'].toString()) ?? 0;
    }
    if (parsedDays <= 0 && data['items'] is List && (data['items'] as List).isNotEmpty) {
      final firstItem = (data['items'] as List).first;
      if (firstItem is Map && firstItem['quantity'] != null) {
        parsedDays = (firstItem['quantity'] as num).toInt();
      }
    }
    if (parsedDays <= 0) {
      final from = parseDate(data['fromDate']);
      final to = parseDate(data['toDate']);
      if (from != null && to != null) {
        final diff = to.difference(from).inDays;
        if (diff > 0) parsedDays = diff;
      }
    }

    return Invoice(
      invoiceId: documentId,
      invoiceNumber: (data['invoiceNumber'] ?? data['invoice_number'] ?? (documentId.length > 8 ? documentId.substring(0, 8).toUpperCase() : documentId)).toString(),
      patientId: (data['patientId'] ?? data['patient_id'] ?? '').toString(),
      staffId: (data['staffId'] ?? data['staff_id'] ?? '').toString(),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      grandTotal: (data['grandTotal'] ?? data['grand_total'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => InvoiceItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      organizationId: (data['organizationId'] ?? data['organization_id'] ?? 'default').toString(),
      createdBy: (data['createdBy'] ?? data['created_by'] ?? '').toString(),
      createdAt: parseDate(data['createdAt'] ?? data['created_at']) ?? DateTime.now(),
      updatedBy: (data['updatedBy'] ?? data['updated_by'] ?? '').toString(),
      updatedAt: parseDate(data['updatedAt'] ?? data['updated_at']) ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? data['is_deleted'] ?? false,
      deletedAt: parseDate(data['deletedAt'] ?? data['deleted_at']),
      deletedBy: (data['deletedBy'] ?? data['deleted_by'])?.toString(),
      paymentStatus: (data['paymentStatus'] ?? data['payment_status'] ?? 'Unpaid').toString(),
      isDiscontinued: data['isDiscontinued'] ?? data['is_discontinued'] ?? false,
      fromDate: parseDate(data['fromDate'] ?? data['from_date']),
      toDate: parseDate(data['toDate'] ?? data['to_date']),
      days: parsedDays,
      createdByName: (data['createdByName'] ?? data['created_by_name']) as String?,
      createdByRole: (data['createdByRole'] ?? data['created_by_role']) as String?,
      createdByUid: (data['createdByUid'] ?? data['created_by_uid'] ?? data['createdBy'] ?? data['created_by'] ?? data['staffId'] ?? data['staff_id']) as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'patientId': patientId,
      'staffId': staffId,
      'subtotal': subtotal,
      'discount': discount,
      'grandTotal': grandTotal,
      'items': items.map((e) => e.toMap()).toList(),
      'organizationId': organizationId,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'paymentStatus': paymentStatus,
      'isDiscontinued': isDiscontinued,
      'fromDate': fromDate != null ? Timestamp.fromDate(fromDate!) : null,
      'toDate': toDate != null ? Timestamp.fromDate(toDate!) : null,
      'days': days,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'createdByUid': createdByUid ?? createdBy,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': invoiceId,
      'invoice_number': invoiceNumber,
      'patient_id': patientId.isEmpty ? null : patientId,
      'staff_id': staffId,
      'subtotal': subtotal,
      'discount': discount,
      'grand_total': grandTotal,
      'items': items.map((e) => e.toMap()).toList(),
      'organization_id': organizationId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'deleted_by': deletedBy,
      'payment_status': paymentStatus,
      'is_discontinued': isDiscontinued,
      'from_date': fromDate?.toIso8601String(),
      'to_date': toDate?.toIso8601String(),
      'days': days,
      'created_by_name': createdByName,
      'created_by_role': createdByRole,
    };
  }

  Invoice copyWith({
    String? invoiceId,
    String? invoiceNumber,
    String? patientId,
    String? staffId,
    double? subtotal,
    double? discount,
    double? grandTotal,
    List<InvoiceItem>? items,
    String? organizationId,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? paymentStatus,
    bool? isDiscontinued,
    DateTime? fromDate,
    DateTime? toDate,
    int? days,
    String? createdByName,
    String? createdByRole,
    String? createdByUid,
  }) {
    return Invoice(
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      patientId: patientId ?? this.patientId,
      staffId: staffId ?? this.staffId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      items: items ?? this.items,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isDiscontinued: isDiscontinued ?? this.isDiscontinued,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      days: days ?? this.days,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      createdByUid: createdByUid ?? this.createdByUid,
    );
  }
}
