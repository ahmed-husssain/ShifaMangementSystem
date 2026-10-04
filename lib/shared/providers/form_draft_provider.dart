import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. PATIENT REGISTRATION DRAFT
// ==========================================

class PatientRegistrationDraft {
  final String patientName;
  final String cnic;
  final String phone;
  final String address;
  final String diagnosis;
  final String doctor;
  final String nurse;
  final String caretaker;
  final String staffPhone;
  final String patientAmount;
  final String staffPayment;
  final String days;
  final List<Map<String, dynamic>> selectedServices;
  final double monthlyServiceCost;
  final bool hasDraft;

  const PatientRegistrationDraft({
    this.patientName = '',
    this.cnic = '',
    this.phone = '',
    this.address = '',
    this.diagnosis = '',
    this.doctor = '',
    this.nurse = '',
    this.caretaker = '',
    this.staffPhone = '',
    this.patientAmount = '',
    this.staffPayment = '',
    this.days = '',
    this.selectedServices = const [],
    this.monthlyServiceCost = 0.0,
    this.hasDraft = false,
  });

  PatientRegistrationDraft copyWith({
    String? patientName,
    String? cnic,
    String? phone,
    String? address,
    String? diagnosis,
    String? doctor,
    String? nurse,
    String? caretaker,
    String? staffPhone,
    String? patientAmount,
    String? staffPayment,
    String? days,
    List<Map<String, dynamic>>? selectedServices,
    double? monthlyServiceCost,
    bool? hasDraft,
  }) {
    return PatientRegistrationDraft(
      patientName: patientName ?? this.patientName,
      cnic: cnic ?? this.cnic,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      diagnosis: diagnosis ?? this.diagnosis,
      doctor: doctor ?? this.doctor,
      nurse: nurse ?? this.nurse,
      caretaker: caretaker ?? this.caretaker,
      staffPhone: staffPhone ?? this.staffPhone,
      patientAmount: patientAmount ?? this.patientAmount,
      staffPayment: staffPayment ?? this.staffPayment,
      days: days ?? this.days,
      selectedServices: selectedServices ?? this.selectedServices,
      monthlyServiceCost: monthlyServiceCost ?? this.monthlyServiceCost,
      hasDraft: hasDraft ?? this.hasDraft,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientName': patientName,
      'cnic': cnic,
      'phone': phone,
      'address': address,
      'diagnosis': diagnosis,
      'doctor': doctor,
      'nurse': nurse,
      'caretaker': caretaker,
      'staffPhone': staffPhone,
      'patientAmount': patientAmount,
      'staffPayment': staffPayment,
      'days': days,
      'selectedServices': selectedServices,
      'monthlyServiceCost': monthlyServiceCost,
      'hasDraft': hasDraft,
    };
  }

  factory PatientRegistrationDraft.fromMap(Map<String, dynamic> map) {
    return PatientRegistrationDraft(
      patientName: (map['patientName'] ?? '').toString(),
      cnic: (map['cnic'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      diagnosis: (map['diagnosis'] ?? '').toString(),
      doctor: (map['doctor'] ?? '').toString(),
      nurse: (map['nurse'] ?? '').toString(),
      caretaker: (map['caretaker'] ?? '').toString(),
      staffPhone: (map['staffPhone'] ?? '').toString(),
      patientAmount: (map['patientAmount'] ?? '').toString(),
      staffPayment: (map['staffPayment'] ?? '').toString(),
      days: (map['days'] ?? '').toString(),
      selectedServices: List<Map<String, dynamic>>.from(map['selectedServices'] ?? []),
      monthlyServiceCost: (map['monthlyServiceCost'] ?? 0.0).toDouble(),
      hasDraft: map['hasDraft'] == true,
    );
  }
}

class PatientRegistrationDraftNotifier extends Notifier<PatientRegistrationDraft> {
  static const _storageKey = 'shifa_patient_registration_draft_v1';

  @override
  PatientRegistrationDraft build() {
    _loadFromStorage();
    return const PatientRegistrationDraft();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = PatientRegistrationDraft.fromMap(map);
      }
    } catch (_) {}
  }

  Future<void> saveDraft({
    required String patientName,
    required String cnic,
    required String phone,
    required String address,
    required String diagnosis,
    required String doctor,
    required String nurse,
    required String caretaker,
    String staffPhone = '',
    required String patientAmount,
    required String staffPayment,
    required String days,
    required List<Map<String, dynamic>> selectedServices,
    required double monthlyServiceCost,
  }) async {
    final isNotEmpty = patientName.isNotEmpty ||
        cnic.isNotEmpty ||
        phone.isNotEmpty ||
        address.isNotEmpty ||
        diagnosis.isNotEmpty ||
        doctor.isNotEmpty ||
        nurse.isNotEmpty ||
        caretaker.isNotEmpty ||
        staffPhone.isNotEmpty ||
        selectedServices.isNotEmpty;

    if (!isNotEmpty) return;

    final updated = PatientRegistrationDraft(
      patientName: patientName,
      cnic: cnic,
      phone: phone,
      address: address,
      diagnosis: diagnosis,
      doctor: doctor,
      nurse: nurse,
      caretaker: caretaker,
      staffPhone: staffPhone,
      patientAmount: patientAmount,
      staffPayment: staffPayment,
      days: days,
      selectedServices: selectedServices,
      monthlyServiceCost: monthlyServiceCost,
      hasDraft: true,
    );

    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(updated.toMap()));
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    state = const PatientRegistrationDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}

final patientRegistrationDraftProvider =
    NotifierProvider<PatientRegistrationDraftNotifier, PatientRegistrationDraft>(
  PatientRegistrationDraftNotifier.new,
);

// ==========================================
// 2. INVOICE FORM DRAFT
// ==========================================

class InvoiceFormDraft {
  final String? patientId;
  final String mrNumber;
  final String patientName;
  final String phone;
  final String address;
  final String cnic;
  final String paymentStatus;
  final int days;
  final double discount;
  final List<Map<String, dynamic>> items;
  final String fromDateIso;
  final String toDateIso;
  final bool hasDraft;

  const InvoiceFormDraft({
    this.patientId,
    this.mrNumber = '',
    this.patientName = '',
    this.phone = '',
    this.address = '',
    this.cnic = '',
    this.paymentStatus = 'Unpaid',
    this.days = 15,
    this.discount = 0.0,
    this.items = const [],
    this.fromDateIso = '',
    this.toDateIso = '',
    this.hasDraft = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'mrNumber': mrNumber,
      'patientName': patientName,
      'phone': phone,
      'address': address,
      'cnic': cnic,
      'paymentStatus': paymentStatus,
      'days': days,
      'discount': discount,
      'items': items,
      'fromDateIso': fromDateIso,
      'toDateIso': toDateIso,
      'hasDraft': hasDraft,
    };
  }

  factory InvoiceFormDraft.fromMap(Map<String, dynamic> map) {
    return InvoiceFormDraft(
      patientId: map['patientId'] as String?,
      mrNumber: (map['mrNumber'] ?? '').toString(),
      patientName: (map['patientName'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      cnic: (map['cnic'] ?? '').toString(),
      paymentStatus: (map['paymentStatus'] ?? 'Unpaid').toString(),
      days: (map['days'] is num) ? (map['days'] as num).toInt() : 15,
      discount: (map['discount'] ?? 0.0).toDouble(),
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      fromDateIso: (map['fromDateIso'] ?? '').toString(),
      toDateIso: (map['toDateIso'] ?? '').toString(),
      hasDraft: map['hasDraft'] == true,
    );
  }
}

class InvoiceFormDraftNotifier extends Notifier<InvoiceFormDraft> {
  static const _storageKey = 'shifa_invoice_form_draft_v1';

  @override
  InvoiceFormDraft build() {
    _loadFromStorage();
    return const InvoiceFormDraft();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = InvoiceFormDraft.fromMap(map);
      }
    } catch (_) {}
  }

  Future<void> saveDraft({
    String? patientId,
    required String mrNumber,
    required String patientName,
    required String phone,
    required String address,
    required String cnic,
    required String paymentStatus,
    required int days,
    required double discount,
    required List<Map<String, dynamic>> items,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final isNotEmpty = patientName.isNotEmpty ||
        phone.isNotEmpty ||
        mrNumber.isNotEmpty ||
        items.isNotEmpty;

    if (!isNotEmpty) return;

    final updated = InvoiceFormDraft(
      patientId: patientId,
      mrNumber: mrNumber,
      patientName: patientName,
      phone: phone,
      address: address,
      cnic: cnic,
      paymentStatus: paymentStatus,
      days: days,
      discount: discount,
      items: items,
      fromDateIso: fromDate.toIso8601String(),
      toDateIso: toDate.toIso8601String(),
      hasDraft: true,
    );

    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(updated.toMap()));
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    state = const InvoiceFormDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}

final invoiceFormDraftProvider =
    NotifierProvider<InvoiceFormDraftNotifier, InvoiceFormDraft>(
  InvoiceFormDraftNotifier.new,
);
