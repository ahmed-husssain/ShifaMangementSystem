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

class InvoiceRepository {
  final SupabaseClient _supabase;

  InvoiceRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Stream<List<Invoice>> watchStaffInvoices(String staffId, {Set<String>? staffPatientIds, int limit = 500}) {
    return _supabase
        .from('invoices')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) {
          final list = rows
              .map((doc) => Invoice.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((inv) {
                if (inv.isDiscontinued) return false;
                final isForStaffPatient = staffPatientIds != null && staffPatientIds.contains(inv.patientId);
                final isCreatedByStaff = inv.createdBy == staffId || inv.staffId == staffId;
                return isForStaffPatient || isCreatedByStaff;
              })
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Invoice>> watchAllInvoices({bool includeDeleted = false, int limit = 500}) {
    var stream = _supabase.from('invoices').stream(primaryKey: ['id']);
    if (!includeDeleted) {
      stream = stream.eq('is_deleted', false);
    }
    return stream
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) {
          final list = rows
              .map((doc) => Invoice.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((inv) => !inv.isDiscontinued)
              .toList();
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
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  final staffPatientsAsync = ref.watch(staffPatientsProvider);
  final allInvoicesAsync = ref.watch(allInvoicesProvider(false));

  final staffPatients = staffPatientsAsync.value ?? [];
  final allInvoices = allInvoicesAsync.value ?? [];

  final staffPatientIds = staffPatients.map((p) => p.patientId).toSet();

  final list = allInvoices.where((inv) {
    if (inv.isDeleted || inv.isDiscontinued) return false;
    final isForStaffPatient = staffPatientIds.contains(inv.patientId);
    final isCreatedByStaff = inv.createdBy == user.id || inv.staffId == user.id;
    return isForStaffPatient || isCreatedByStaff;
  }).toList();

  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return Stream.value(list);
});

final allInvoicesProvider = StreamProvider.family<List<Invoice>, bool>((ref, includeDeleted) {
  return ref.watch(invoiceRepositoryProvider).watchAllInvoices(includeDeleted: includeDeleted);
});
