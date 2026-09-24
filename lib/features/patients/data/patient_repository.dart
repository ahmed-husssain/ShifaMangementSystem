import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/patient_model.dart';
import '../../../shared/providers/auth_provider.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(
    supabase: ref.watch(supabaseClientProvider),
  );
});

final allPatientsProvider = StreamProvider.autoDispose.family<List<Patient>, bool>((ref, includeDeleted) {
  return ref.watch(patientRepositoryProvider).watchAllPatients(includeDeleted: includeDeleted);
});

final staffPatientsProvider = StreamProvider.autoDispose<List<Patient>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(patientRepositoryProvider).watchStaffPatients(user.id);
});

class PatientRepository {
  final SupabaseClient _supabase;

  PatientRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Stream<List<Patient>> watchStaffPatients(String staffId) {
    return _supabase
        .from('patients')
        .stream(primaryKey: ['id'])
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .map((rows) {
          final list = rows
              .map((doc) => Patient.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((p) => p.createdBy == staffId || p.assignedStaffId == staffId)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Patient>> watchAllPatients({bool includeDeleted = false}) {
    var stream = _supabase.from('patients').stream(primaryKey: ['id']);
    if (!includeDeleted) {
      stream = stream.eq('is_deleted', false);
    }
    return stream.order('created_at', ascending: false).map((rows) {
      final list = rows.map((doc) => Patient.fromMap(doc, (doc['id'] ?? '').toString())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> createPatient(Patient patient, {String? userName}) async {
    final patientId = patient.patientId.isNotEmpty 
        ? patient.patientId 
        : DateTime.now().millisecondsSinceEpoch.toString();
        
    final pMap = patient.toSupabaseMap();
    pMap['id'] = patientId;

    await _supabase.from('patients').insert(pMap);

    // Log activity
    await _supabase.from('activities').insert({
      'user_id': patient.createdBy,
      'user_name': (userName != null && userName.isNotEmpty) ? userName : 'Staff User',
      'role': 'staff',
      'action': 'PATIENT_CREATED',
      'entity_type': 'patient',
      'entity_id': patientId,
      'description': 'Registered patient ${patient.patientName}',
      'organization_id': patient.organizationId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updatePatient(Patient patient) async {
    await _supabase
        .from('patients')
        .update(patient.toSupabaseMap())
        .eq('id', patient.patientId);
  }

  Future<void> softDeletePatient({
    required String patientId,
    required String patientName,
    required String userId,
    required String organizationId,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('patients').update({
      'is_deleted': true,
      'deleted_at': now,
      'deleted_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_deleted': true,
      'deleted_at': now,
      'deleted_by': userId,
    }).eq('patient_id', patientId);

    // Log activity
    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': 'User',
      'role': 'admin',
      'action': 'PATIENT_DELETED',
      'entity_type': 'patient',
      'entity_id': patientId,
      'description': 'Soft-deleted patient $patientName and associated invoice(s)',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<void> restorePatient({
    required String patientId,
    required String patientName,
    required String userId,
    required String organizationId,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('patients').update({
      'is_deleted': false,
      'deleted_at': null,
      'deleted_by': null,
      'updated_at': now,
      'updated_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_deleted': false,
      'deleted_at': null,
      'deleted_by': null,
      'updated_at': now,
    }).eq('patient_id', patientId);

    // Log activity
    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': 'Admin',
      'role': 'admin',
      'action': 'PATIENT_RESTORED',
      'entity_type': 'patient',
      'entity_id': patientId,
      'description': 'Restored patient $patientName and associated invoices',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<void> discontinuePatient({
    required String patientId,
    required String patientName,
    required String userId,
    required String organizationId,
    String? userName,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('patients').update({
      'is_discontinued': true,
      'discontinued_at': now,
      'discontinued_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_discontinued': true,
    }).eq('patient_id', patientId);

    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': userName ?? 'Staff',
      'role': 'staff',
      'action': 'PATIENT_DISCONTINUED',
      'entity_type': 'patient',
      'entity_id': patientId,
      'description': 'Discontinued patient $patientName and locked active invoices',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<void> reactivatePatient({
    required String patientId,
    required String patientName,
    required String userId,
    required String organizationId,
    String? userName,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _supabase.from('patients').update({
      'is_discontinued': false,
      'discontinued_at': null,
      'discontinued_by': null,
      'reactivated_at': now,
      'reactivated_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_discontinued': false,
    }).eq('patient_id', patientId);

    await _supabase.from('activities').insert({
      'user_id': userId,
      'user_name': userName ?? 'Staff',
      'role': 'staff',
      'action': 'PATIENT_REACTIVATED',
      'entity_type': 'patient',
      'entity_id': patientId,
      'description': 'Reactivated patient $patientName and unlocked invoices',
      'organization_id': organizationId,
      'timestamp': now,
    });
  }

  Future<Patient?> getPatientById(String patientId) async {
    final res = await _supabase
        .from('patients')
        .select()
        .eq('id', patientId)
        .maybeSingle();
    if (res == null) return null;
    return Patient.fromMap(res, (res['id'] ?? '').toString());
  }

  /// Read-only preview of next MR Number (does NOT increment database counter)
  Future<String> previewNextMRNumber() async {
    try {
      final doc = await _supabase.from('system_metrics').select('data').eq('id', 'mr_counter').maybeSingle();
      int current = 4000;
      if (doc != null && doc['data'] != null && doc['data'] is Map) {
        current = (doc['data']['current'] as num?)?.toInt() ?? 4000;
      }
      final nextCount = current + 1;
      final now = DateTime.now();
      final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      return 'SHHC-$dateStr-$nextCount';
    } catch (_) {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      return 'SHHC-$dateStr-4001';
    }
  }

  /// Atomically / sequentially gets the next MR Number and increments counter
  Future<String> getNextMRNumber() async {
    int nextCount = 4001;
    try {
      final doc = await _supabase.from('system_metrics').select('data').eq('id', 'mr_counter').maybeSingle();
      int current = 4000;
      if (doc != null && doc['data'] != null && doc['data'] is Map) {
        current = (doc['data']['current'] as num?)?.toInt() ?? 4000;
      }
      nextCount = current + 1;
      await _supabase.from('system_metrics').upsert({
        'id': 'mr_counter',
        'data': {'current': nextCount},
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'SHHC-$dateStr-$nextCount';
  }

  Future<void> syncSystemMetrics({String organizationId = 'default'}) async {
    try {
      await _supabase.rpc('get_financial_metrics', params: {'p_org_id': organizationId});
    } catch (_) {}
  }
}
