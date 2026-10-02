import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/plan_expiration_provider.dart';
import '../../../users/presentation/pages/users_page.dart';

const Set<String> _rolePrefixes = {
  'dr',
  'doc',
  'doctor',
  'nurse',
  'care',
  'caretaker',
  'mr',
  'mrs',
  'ms',
  'staff',
};

/// Returns true if a string is a raw database UUID or Supabase/Firebase Auth UID.
bool isGuidOrUid(String val) {
  final clean = val.trim();
  if (clean.isEmpty) return false;
  // Standard UUID (e.g. 123e4567-e89b-12d3-a456-426614174000)
  if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(clean)) {
    return true;
  }
  // Alphanumeric auth UID (e.g. 1sXu30D6dHCkOlZEisPL7KUCKsN2)
  if (clean.length >= 20 && !clean.contains(' ') && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(clean)) {
    return true;
  }
  return false;
}

/// Helper map from staff UID to human display name.
final staffUidToNameMapProvider = Provider<Map<String, String>>((ref) {
  final allUsers = ref.watch(allUsersProvider).value ?? [];
  final map = <String, String>{};
  for (final u in allUsers) {
    final uid = (u['id'] ?? u['uid'] ?? '').toString().trim();
    final name = (u['name'] ?? u['username'] ?? '').toString().trim();
    if (uid.isNotEmpty && name.isNotEmpty && !isGenericStaffIdentifier(name)) {
      map[uid] = name;
    }
  }
  return map;
});

/// Currently selected staff filter for notifications (null means 'All Staff').
class SelectedStaffFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? staffName) => state = staffName;
  void clear() => state = null;
}

final selectedStaffFilterProvider = NotifierProvider<SelectedStaffFilterNotifier, String?>(
  SelectedStaffFilterNotifier.new,
);

/// Extracts unique, non-generic, human-readable staff names across all active expiring plans.
final availableStaffListProvider = Provider<List<String>>((ref) {
  final plans = ref.watch(expiringPlansProvider).value ?? [];
  final uidToNameMap = ref.watch(staffUidToNameMapProvider);
  final staffSet = <String>{};

  for (final plan in plans) {
    final p = plan.patient;

    // 1. Doctor (only human names, never raw GUIDs)
    if (p.doctor.trim().isNotEmpty &&
        !isGenericStaffIdentifier(p.doctor) &&
        !isGuidOrUid(p.doctor)) {
      staffSet.add(p.doctor.trim());
    }

    // 2. Nurse (only human names, never raw GUIDs)
    if (p.nurse.trim().isNotEmpty &&
        !isGenericStaffIdentifier(p.nurse) &&
        !isGuidOrUid(p.nurse)) {
      staffSet.add(p.nurse.trim());
    }

    // 3. Caretaker (only human names, never raw GUIDs)
    if (p.caretaker.trim().isNotEmpty &&
        !isGenericStaffIdentifier(p.caretaker) &&
        !isGuidOrUid(p.caretaker)) {
      staffSet.add(p.caretaker.trim());
    }

    // 4. Assigned Staff ID: Resolve raw GUID to human name
    if (p.assignedStaffId.trim().isNotEmpty) {
      final rawId = p.assignedStaffId.trim();
      if (uidToNameMap.containsKey(rawId)) {
        staffSet.add(uidToNameMap[rawId]!);
      } else if (!isGuidOrUid(rawId) && !isGenericStaffIdentifier(rawId)) {
        staffSet.add(rawId);
      }
    }
  }

  final list = staffSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
});

/// Returns whether the plan is assigned to the given staff name.
bool planMatchesStaff(
  ExpiringPatientPlan plan,
  String staffName, {
  Map<String, String>? uidToNameMap,
}) {
  final target = staffName.trim().toLowerCase();
  final p = plan.patient;

  // Direct exact matches
  if (p.doctor.trim().toLowerCase() == target) return true;
  if (p.nurse.trim().toLowerCase() == target) return true;
  if (p.caretaker.trim().toLowerCase() == target) return true;

  // Check resolved assignedStaffId
  final rawAssigned = p.assignedStaffId.trim();
  if (rawAssigned.toLowerCase() == target) return true;
  if (uidToNameMap != null && uidToNameMap.containsKey(rawAssigned)) {
    if (uidToNameMap[rawAssigned]!.trim().toLowerCase() == target) return true;
  }

  // Extract meaningful name tokens (excluding prefixes like 'dr', 'nurse', etc.)
  final meaningfulWords = target
      .split(RegExp(r'[\s,._\-/]+'))
      .map((w) => w.trim().toLowerCase())
      .where((w) => w.length >= 3 && !_rolePrefixes.contains(w) && !isGenericStaffIdentifier(w));

  for (final w in meaningfulWords) {
    if (p.doctor.toLowerCase().contains(w)) return true;
    if (p.nurse.toLowerCase().contains(w)) return true;
    if (p.caretaker.toLowerCase().contains(w)) return true;
    if (uidToNameMap != null && uidToNameMap.containsKey(rawAssigned)) {
      if (uidToNameMap[rawAssigned]!.toLowerCase().contains(w)) return true;
    }
  }
  return false;
}

/// Computes the number of expiring plans assigned to a specific staff member.
final staffPlanCountProvider = Provider.family<int, String>((ref, staffName) {
  final plans = ref.watch(expiringPlansProvider).value ?? [];
  final uidToNameMap = ref.watch(staffUidToNameMapProvider);
  return plans.where((plan) => planMatchesStaff(plan, staffName, uidToNameMap: uidToNameMap)).length;
});

/// Filtered expiring plans incorporating both the Admin Staff Queue filter and current user role.
final staffFilteredExpiringPlansProvider = Provider<List<ExpiringPatientPlan>>((ref) {
  final plans = ref.watch(expiringPlansProvider).value ?? [];
  final profile = ref.watch(userProfileProvider).value;
  final role = profile?['role'] ?? 'staff';
  final selectedStaff = ref.watch(selectedStaffFilterProvider);

  // If user is not admin or no staff filter is selected, show all available plans
  if (role != 'admin' || selectedStaff == null || selectedStaff.isEmpty) {
    return plans;
  }

  final uidToNameMap = ref.watch(staffUidToNameMapProvider);
  return plans.where((plan) => planMatchesStaff(plan, selectedStaff, uidToNameMap: uidToNameMap)).toList();
});
