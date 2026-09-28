import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/patient_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/domain/invoice_model.dart';
import '../../users/presentation/pages/users_page.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(
    supabase: ref.watch(supabaseClientProvider),
  );
});

/// Map of patient entity_id (or MR number) -> creator user_name from activities log
final patientCreatorsMapProvider = StreamProvider<Map<String, String>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('activities')
      .stream(primaryKey: ['id'])
      .order('timestamp', ascending: false)
      .limit(500)
      .map((rows) {
        final map = <String, String>{};
        for (final row in rows) {
          final entityId = (row['entity_id'] ?? row['entityId'] ?? '').toString().trim();
          final userName = (row['user_name'] ?? row['userName'] ?? '').toString().trim();
          final action = (row['action'] ?? '').toString().toUpperCase();
          if (entityId.isNotEmpty && userName.isNotEmpty && !isGenericStaffIdentifier(userName)) {
            if (action == 'PATIENT_CREATED' || action.contains('REGISTER') || action.contains('CREATE')) {
              map[entityId] = userName;
            } else if (!map.containsKey(entityId)) {
              map[entityId] = userName;
            }
          }
        }
        return map;
      });
});

/// Map of legacy user_id (e.g. Firebase UIDs) -> user_name from activities log
final legacyUidToNameProvider = StreamProvider<Map<String, String>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('activities')
      .stream(primaryKey: ['id'])
      .order('timestamp', ascending: false)
      .limit(500)
      .map((rows) {
        final map = <String, String>{};
        for (final row in rows) {
          final userId = (row['user_id'] ?? row['userId'] ?? '').toString().trim().toLowerCase();
          final userName = (row['user_name'] ?? row['userName'] ?? '').toString().trim();
          if (userId.isNotEmpty && userName.isNotEmpty && !isGenericStaffIdentifier(userName)) {
            map[userId] = userName;
          }
        }
        return map;
      });
});

bool _patientHasOtherRegisteredCreator(
  Patient p,
  Set<String> currentStaffIds,
  Map<String, String>? legacyUidToName,
  Map<String, String>? activitiesCreators,
  List<Map<String, dynamic>>? allUsers,
) {
  // If activities recorded a creator who is NOT the current staff member
  if (activitiesCreators != null) {
    final actCreator = activitiesCreators[p.patientId] ?? (p.mrNumber.isNotEmpty ? activitiesCreators[p.mrNumber] : null);
    if (actCreator != null && !isGenericStaffIdentifier(actCreator) && !matchesStaffIdentifier(actCreator, currentStaffIds)) {
      return true;
    }
  }

  // If createdBy is set and belongs to someone else
  final created = p.createdBy.trim();
  if (created.isNotEmpty && !isGenericStaffIdentifier(created) && !matchesStaffIdentifier(created, currentStaffIds)) {
    // If it maps via legacyUid to someone else
    if (legacyUidToName != null) {
      final name = legacyUidToName[created.toLowerCase()];
      if (name != null && !isGenericStaffIdentifier(name) && !matchesStaffIdentifier(name, currentStaffIds)) {
        return true;
      }
    }
    // If it is in allUsers as someone else
    if (allUsers != null) {
      for (final u in allUsers) {
        final uId = (u['id'] ?? u['uid'] ?? '').toString().toLowerCase();
        if (created.toLowerCase() == uId) {
          final uName = (u['name'] ?? u['username'] ?? '').toString();
          if (!isGenericStaffIdentifier(uName) && !matchesStaffIdentifier(uName, currentStaffIds)) {
            return true;
          }
        }
      }
    }
  }

  return false;
}

bool matchesStaffPatient(
  Patient p,
  Set<String> staffIdentifiers, {
  List<Invoice>? allInvoices,
  List<Map<String, dynamic>>? allUsers,
  Map<String, String>? activitiesCreators,
  Map<String, String>? legacyUidToName,
}) {
  if (staffIdentifiers.isEmpty) return false;

  // 1. Direct match on createdBy or assignedStaffId
  if (p.createdBy.isNotEmpty && matchesStaffIdentifier(p.createdBy, staffIdentifiers)) {
    return true;
  }
  if (p.assignedStaffId.isNotEmpty && matchesStaffIdentifier(p.assignedStaffId, staffIdentifiers)) {
    return true;
  }

  // 2. Legacy UID mapping (e.g. from activities: 1eXuD0DbdFOKQiZEi5PL7kUCKaN2 -> daniyal)
  if (legacyUidToName != null && p.createdBy.isNotEmpty) {
    final mappedName = legacyUidToName[p.createdBy.trim().toLowerCase()];
    if (mappedName != null && matchesStaffIdentifier(mappedName, staffIdentifiers)) {
      return true;
    }
  }
  if (legacyUidToName != null && p.assignedStaffId.isNotEmpty) {
    final mappedName = legacyUidToName[p.assignedStaffId.trim().toLowerCase()];
    if (mappedName != null && matchesStaffIdentifier(mappedName, staffIdentifiers)) {
      return true;
    }
  }

  // 3. Match from activities audit log (the exact source the admin panel displays)
  if (activitiesCreators != null) {
    final actCreator1 = activitiesCreators[p.patientId];
    if (actCreator1 != null && matchesStaffIdentifier(actCreator1, staffIdentifiers)) {
      return true;
    }
    if (p.mrNumber.isNotEmpty) {
      final actCreator2 = activitiesCreators[p.mrNumber];
      if (actCreator2 != null && matchesStaffIdentifier(actCreator2, staffIdentifiers)) {
        return true;
      }
    }
  }

  // 4. Lookup p.createdBy or p.assignedStaffId in allUsers (maps UUID to username/name)
  if (allUsers != null) {
    for (final u in allUsers) {
      final uId = (u['id'] ?? u['uid'] ?? '').toString().toLowerCase();
      final uUsername = (u['username'] ?? '').toString().toLowerCase();
      final uEmail = (u['email'] ?? '').toString().toLowerCase();
      final uName = (u['name'] ?? '').toString().toLowerCase();

      final pCreated = p.createdBy.trim().toLowerCase();
      final pAssigned = p.assignedStaffId.trim().toLowerCase();

      if ((pCreated.isNotEmpty && (pCreated == uId || pCreated == uUsername || pCreated == uEmail)) ||
          (pAssigned.isNotEmpty && (pAssigned == uId || pAssigned == uUsername || pAssigned == uEmail))) {
        if (matchesStaffIdentifier(uUsername, staffIdentifiers) ||
            matchesStaffIdentifier(uName, staffIdentifiers) ||
            matchesStaffIdentifier(uEmail, staffIdentifiers) ||
            matchesStaffIdentifier(uId, staffIdentifiers)) {
          return true;
        }
      }
    }
  }

  // 5. Match from invoices (check all invoices for this patient, matching by patientId OR mrNumber)
  if (allInvoices != null && allInvoices.isNotEmpty) {
    final patientInvoices = allInvoices
        .where((inv) =>
            !inv.isDeleted &&
            !inv.isDiscontinued &&
            (inv.patientId == p.patientId ||
             (p.mrNumber.isNotEmpty && inv.patientId == p.mrNumber)))
        .toList();
    if (patientInvoices.isNotEmpty) {
      for (final inv in patientInvoices) {
        if (matchesStaffIdentifier(inv.createdByName, staffIdentifiers) ||
            matchesStaffIdentifier(inv.createdBy, staffIdentifiers) ||
            matchesStaffIdentifier(inv.createdByUid, staffIdentifiers) ||
            matchesStaffIdentifier(inv.staffId, staffIdentifiers)) {
          return true;
        }
        if (legacyUidToName != null && inv.createdBy.isNotEmpty) {
          final mapped = legacyUidToName[inv.createdBy.trim().toLowerCase()];
          if (mapped != null && matchesStaffIdentifier(mapped, staffIdentifiers)) {
            return true;
          }
        }
      }
    }
  }

  // 6. Caretaker match (if this staff member is explicitly listed as caretaker)
  final caretaker = p.caretaker.trim();
  if (caretaker.isNotEmpty && !isGenericStaffIdentifier(caretaker) && matchesStaffIdentifier(caretaker, staffIdentifiers)) {
    return true;
  }

  // 7. Clinical Nurse/Doctor assignment (ONLY as fallback if patient has no other registered staff creator)
  // Strict Ownership: If the patient was registered by a specific staff member (like Daniyal),
  // a visiting nurse (like Ayaz) must NOT claim this patient or inflate Ayaz's finances.
  final hasOtherCreator = _patientHasOtherRegisteredCreator(p, staffIdentifiers, legacyUidToName, activitiesCreators, allUsers);
  if (!hasOtherCreator) {
    final nurse = p.nurse.trim();
    if (nurse.isNotEmpty && !isGenericStaffIdentifier(nurse) && matchesStaffIdentifier(nurse, staffIdentifiers)) {
      return true;
    }
    final doctor = p.doctor.trim();
    if (doctor.isNotEmpty && !isGenericStaffIdentifier(doctor) && matchesStaffIdentifier(doctor, staffIdentifiers)) {
      return true;
    }
  }

  return false;
}

final allPatientsProvider = StreamProvider.family<List<Patient>, bool>((ref, includeDeleted) {
  return ref.watch(patientRepositoryProvider).watchAllPatients(includeDeleted: includeDeleted);
});

final staffPatientsProvider = StreamProvider<List<Patient>>((ref) {
  final staffIds = ref.watch(currentStaffIdentifiersProvider);
  final allPatientsAsync = ref.watch(allPatientsProvider(false));
  final allUsersAsync = ref.watch(allUsersProvider);
  final allInvoicesAsync = ref.watch(allInvoicesProvider(false));
  final activitiesCreatorsAsync = ref.watch(patientCreatorsMapProvider);
  final legacyUidMapAsync = ref.watch(legacyUidToNameProvider);

  if (allPatientsAsync.isLoading) {
    return const Stream.empty();
  }

  return allPatientsAsync.when(
    data: (allPatients) {
      if (staffIds.isEmpty) return Stream.value(<Patient>[]);

      final allUsers = allUsersAsync.value;
      final allInvoices = allInvoicesAsync.value;
      final activitiesCreators = activitiesCreatorsAsync.value;
      final legacyUidMap = legacyUidMapAsync.value;

      final list = allPatients.where((p) {
        return matchesStaffPatient(
          p,
          staffIds,
          allInvoices: allInvoices,
          allUsers: allUsers,
          activitiesCreators: activitiesCreators,
          legacyUidToName: legacyUidMap,
        );
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    },
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e, st),
  );
});

class PatientRepository {
  final SupabaseClient _supabase;

  PatientRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Stream<List<Patient>> watchStaffPatients(String staffId, {Set<String>? staffIdentifiers}) {
    final allIds = <String>{
      if (staffId.isNotEmpty) staffId,
      if (staffIdentifiers != null) ...staffIdentifiers,
    };

    return _supabase
        .from('patients')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          final list = rows
              .map((doc) => Patient.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((p) => !p.isDeleted && matchesStaffPatient(p, allIds))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Patient>> watchAllPatients({bool includeDeleted = false}) {
    return _supabase
        .from('patients')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          final list = rows
              .map((doc) => Patient.fromMap(doc, (doc['id'] ?? '').toString()))
              .where((p) => includeDeleted ? true : !p.isDeleted)
              .toList();
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
      'is_discontinued': false,
      'deleted_at': now,
      'deleted_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_deleted': true,
      'is_discontinued': false,
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
      'is_discontinued': false,
      'deleted_at': null,
      'deleted_by': null,
      'updated_at': now,
      'updated_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_deleted': false,
      'is_discontinued': false,
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
      'is_deleted': false,
      'discontinued_at': now,
      'discontinued_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_discontinued': true,
      'is_deleted': false,
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
      'is_deleted': false,
      'discontinued_at': null,
      'discontinued_by': null,
      'reactivated_at': now,
      'reactivated_by': userId,
    }).eq('id', patientId);

    await _supabase.from('invoices').update({
      'is_discontinued': false,
      'is_deleted': false,
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
      int maxNumber = 4000;

      // 1. Fetch latest patients from database to determine the highest existing MR Number
      final patientsRes = await _supabase
          .from('patients')
          .select('mr_number')
          .order('created_at', ascending: false)
          .limit(50);

      for (final item in patientsRes) {
        final mr = item['mr_number']?.toString() ?? '';
        final match = RegExp(r'-(\d+)$').firstMatch(mr);
        if (match != null) {
          final val = int.tryParse(match.group(1)!);
          if (val != null && val > maxNumber) {
            maxNumber = val;
          }
        }
      }

      // 2. Also check system_metrics counter as a cross-reference
      try {
        final metricDoc = await _supabase
            .from('system_metrics')
            .select('total_patients')
            .eq('organization_id', 'mr_counter')
            .maybeSingle();
        if (metricDoc != null && metricDoc['total_patients'] != null) {
          final countVal = (metricDoc['total_patients'] as num).toInt();
          if (countVal > maxNumber) {
            maxNumber = countVal;
          }
        }
      } catch (_) {}

      final nextCount = maxNumber + 1;
      final now = DateTime.now();
      final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      return 'SHHC-$dateStr-$nextCount';
    } catch (_) {
      final now = DateTime.now();
      final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      return 'SHHC-$dateStr-4031';
    }
  }

  /// Atomically / sequentially gets the next MR Number and increments counter
  Future<String> getNextMRNumber() async {
    int nextCount = 4031;
    try {
      int maxNumber = 4000;

      // 1. Fetch latest patients to guarantee exact sequence from actual records
      final patientsRes = await _supabase
          .from('patients')
          .select('mr_number')
          .order('created_at', ascending: false)
          .limit(50);

      for (final item in patientsRes) {
        final mr = item['mr_number']?.toString() ?? '';
        final match = RegExp(r'-(\d+)$').firstMatch(mr);
        if (match != null) {
          final val = int.tryParse(match.group(1)!);
          if (val != null && val > maxNumber) {
            maxNumber = val;
          }
        }
      }

      // 2. Also check system_metrics counter
      try {
        final metricDoc = await _supabase
            .from('system_metrics')
            .select('total_patients')
            .eq('organization_id', 'mr_counter')
            .maybeSingle();
        if (metricDoc != null && metricDoc['total_patients'] != null) {
          final countVal = (metricDoc['total_patients'] as num).toInt();
          if (countVal > maxNumber) {
            maxNumber = countVal;
          }
        }
      } catch (_) {}

      nextCount = maxNumber + 1;

      // 3. Keep system_metrics in sync
      await _supabase.from('system_metrics').upsert({
        'organization_id': 'mr_counter',
        'total_patients': nextCount,
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
