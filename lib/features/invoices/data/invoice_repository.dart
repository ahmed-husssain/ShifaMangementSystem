import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/invoice_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../patients/data/patient_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(
    supabase: ref.watch(supabaseClientProvider),
  );
});

bool matchesStaffInvoice(
  Invoice inv,
  Set<String> staffPatientIds, {
  Set<String>? staffIdentifiers,
}) {
  // 1. Strict Patient Ownership:
  // If the invoice is linked to a patient, it belongs to the staff member who holds that patient
  if (inv.patientId.isNotEmpty && staffPatientIds.contains(inv.patientId)) {
    return true;
  }
  // 2. Direct Staff Invoice match (invoices created by or assigned to this staff member)
  if (staffIdentifiers != null && staffIdentifiers.isNotEmpty) {
    return matchesStaffIdentifier(inv.createdByName, staffIdentifiers) ||
        matchesStaffIdentifier(inv.createdBy, staffIdentifiers) ||
        matchesStaffIdentifier(inv.createdByUid, staffIdentifiers) ||
        matchesStaffIdentifier(inv.staffId, staffIdentifiers);
  }
  return false;
}

class InvoiceRepository {
  final SupabaseClient _supabase;

  InvoiceRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Stream<List<Invoice>> watchStaffInvoices(
    String staffId, {
    Set<String>? staffIdentifiers,
    Set<String>? staffPatientIds,
    int limit = 500,
  }) {
    return _supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) {
          final pIds = staffPatientIds ?? {};
          final sIds = staffIdentifiers ?? {};
          if (pIds.isEmpty && sIds.isEmpty) return <Invoice>[];

          final list = rows
              .map((doc) => Invoice.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((inv) {
                if (inv.isDeleted || inv.isDiscontinued) return false;
                return matchesStaffInvoice(inv, pIds, staffIdentifiers: sIds);
              })
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Invoice>> watchAllInvoices({bool includeDeleted = false, int limit = 500}) {
    return _supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) {
          final seenIds = <String>{};
          final list = <Invoice>[];
          for (final doc in rows) {
            final inv = Invoice.fromMap(doc, (doc['id'] ?? '').toString());
            if (inv.isDiscontinued) continue;
            if (!includeDeleted && inv.isDeleted) continue;
            final key = inv.invoiceId.isNotEmpty ? inv.invoiceId : inv.invoiceNumber;
            if (seenIds.add(key)) {
              list.add(inv);
            }
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<String> createInvoice(Invoice invoice, {String? userName}) async {
    final invoiceId = invoice.invoiceId.isNotEmpty
        ? invoice.invoiceId
        : DateTime.now().millisecondsSinceEpoch.toString();

    final invMap = invoice.toSupabaseMap();
    invMap['id'] = invoiceId;

    await _supabase.from('invoices').insert(invMap);

    // Log activity
    await _supabase.from('activities').insert({
      'user_id': invoice.createdBy,
      'user_name': (userName != null && userName.isNotEmpty) ? userName : (invoice.createdByName ?? 'Staff User'),
      'role': invoice.createdByRole ?? 'staff',
      'action': 'INVOICE_CREATED',
      'entity_type': 'invoice',
      'entity_id': invoiceId,
      'description': 'Created invoice ${invoice.invoiceNumber} for amount PKR ${invoice.grandTotal.toStringAsFixed(0)}',
      'organization_id': invoice.organizationId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return invoiceId;
  }

  Future<void> updateInvoice(Invoice invoice, {String? previousPaymentStatus}) async {
    await _supabase
        .from('invoices')
        .update(invoice.toSupabaseMap())
        .eq('id', invoice.invoiceId);
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status, {String? previousPaymentStatus}) async {
    await _supabase.from('invoices').update({
      'payment_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', invoiceId);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await _supabase.from('invoices').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', invoiceId);
  }

  Future<void> softDeleteInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String userId,
    required String organizationId,
    String? userName,
    String? role,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('invoices').update({
      'is_deleted': true,
      'deleted_at': now,
      'deleted_by': userId,
    }).eq('id', invoiceId);

    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': userName ?? 'User',
      'role': role ?? 'staff',
      'action': 'INVOICE_DELETED',
      'entity_type': 'invoice',
      'entity_id': invoiceId,
      'description': 'Deleted invoice $invoiceNumber',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<void> restoreInvoice({
    required String invoiceId,
    required String invoiceNumber,
    required String userId,
    required String organizationId,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('invoices').update({
      'is_deleted': false,
      'deleted_at': null,
      'deleted_by': null,
      'updated_at': now,
    }).eq('id', invoiceId);

    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': 'Admin',
      'role': 'admin',
      'action': 'INVOICE_RESTORED',
      'entity_type': 'invoice',
      'entity_id': invoiceId,
      'description': 'Restored invoice $invoiceNumber',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<List<Invoice>> getInvoicesForPatient(String patientId) async {
    final res = await _supabase
        .from('invoices')
        .select()
        .eq('patient_id', patientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return (res as List)
        .map((r) => Invoice.fromMap(r, (r['id'] ?? '').toString()))
        .toList();
  }
}

final staffInvoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final staffIdentifiers = ref.watch(currentStaffIdentifiersProvider);
  final staffPatientsAsync = ref.watch(staffPatientsProvider);
  final allInvoicesAsync = ref.watch(allInvoicesProvider(false));

  if (allInvoicesAsync.isLoading || staffPatientsAsync.isLoading) {
    return const Stream.empty();
  }

  return allInvoicesAsync.when(
    data: (allInvoices) {
      final staffPatients = staffPatientsAsync.value ?? [];
      final activePatients = staffPatients.where((p) => !p.isDiscontinued && !p.isDeleted).toList();
      final staffPatientIds = <String>{};
      for (final p in activePatients) {
        if (p.patientId.isNotEmpty) staffPatientIds.add(p.patientId);
        if (p.mrNumber.isNotEmpty) staffPatientIds.add(p.mrNumber);
      }

      // If the staff member has no registered patients and no matching invoices, return empty
      if (staffPatientIds.isEmpty && staffIdentifiers.isEmpty) {
        return Stream.value(<Invoice>[]);
      }

      final seenIds = <String>{};
      final uniqueList = <Invoice>[];
      for (final inv in allInvoices) {
        if (inv.isDeleted || inv.isDiscontinued) continue;
        if (matchesStaffInvoice(inv, staffPatientIds, staffIdentifiers: staffIdentifiers)) {
          final key = inv.invoiceId.isNotEmpty ? inv.invoiceId : inv.invoiceNumber;
          if (seenIds.add(key)) {
            uniqueList.add(inv);
          }
        }
      }

      uniqueList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(uniqueList);
    },
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e, st),
  );
});

final allInvoicesProvider = StreamProvider.family<List<Invoice>, bool>((ref, includeDeleted) {
  return ref.watch(invoiceRepositoryProvider).watchAllInvoices(includeDeleted: includeDeleted);
});
