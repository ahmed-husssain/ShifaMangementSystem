import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../domain/invoice_model.dart';
import '../../patients/domain/patient_model.dart';

class StaffInfoResult {
  final String name;
  final String role;

  const StaffInfoResult({required this.name, required this.role});
}

class StaffInfoResolver {
  static String formatStaffName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Staff';
    final isAlnumId = RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed);
    if (isAlnumId) return 'Staff';
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  static Future<StaffInfoResult> resolve({
    required Invoice invoice,
    Patient? patient,
    SupabaseClient? client,
  }) async {
    // 1. Direct createdByName from invoice
    if (invoice.createdByName != null && invoice.createdByName!.trim().isNotEmpty) {
      final name = invoice.createdByName!.trim();
      final isAlnumId = RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(name);
      if (!isAlnumId && !isGenericStaffIdentifier(name)) {
        return StaffInfoResult(
          name: formatStaffName(name),
          role: invoice.createdByRole ?? 'Staff',
        );
      }
    }

    SupabaseClient? supabase = client;
    if (supabase == null) {
      try {
        supabase = Supabase.instance.client;
      } catch (_) {}
    }

    final creatorUid = invoice.createdByUid ??
        (invoice.createdBy.isNotEmpty ? invoice.createdBy : invoice.staffId);

    // 2. Query users table if creatorUid is present
    if (creatorUid.isNotEmpty && supabase != null) {
      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(creatorUid);
      if (isUuid) {
        try {
          final doc = await supabase.from('users').select().eq('id', creatorUid).maybeSingle();
          if (doc != null) {
            final name = doc['name'] ?? doc['username'] ?? doc['email']?.toString().split('@').first;
            if (name != null && name.toString().trim().isNotEmpty && !isGenericStaffIdentifier(name.toString())) {
              return StaffInfoResult(
                name: formatStaffName(name.toString().trim()),
                role: (doc['role'] ?? 'Staff').toString(),
              );
            }
          }
        } catch (_) {}
      } else {
        try {
          final doc = await supabase
              .from('users')
              .select()
              .or('username.ilike.$creatorUid,email.ilike.$creatorUid')
              .limit(1)
              .maybeSingle();
          if (doc != null) {
            final name = doc['name'] ?? doc['username'] ?? doc['email']?.toString().split('@').first;
            if (name != null && name.toString().trim().isNotEmpty && !isGenericStaffIdentifier(name.toString())) {
              return StaffInfoResult(
                name: formatStaffName(name.toString().trim()),
                role: (doc['role'] ?? 'Staff').toString(),
              );
            }
          }
        } catch (_) {}
      }
    }

    // 3. Query activities table
    if (supabase != null) {
      try {
        final act = await supabase
            .from('activities')
            .select('user_name')
            .eq('entity_id', invoice.invoiceId)
            .not('user_name', 'is', null)
            .order('timestamp', ascending: false)
            .limit(1)
            .maybeSingle();
        if (act != null && act['user_name'] != null) {
          final actName = act['user_name'].toString().trim();
          if (actName.isNotEmpty && !isGenericStaffIdentifier(actName)) {
            return StaffInfoResult(
              name: formatStaffName(actName),
              role: 'Staff',
            );
          }
        }
      } catch (_) {}
    }

    // 4. Clinical fields from patient if available
    if (patient != null) {
      if (patient.nurse.trim().isNotEmpty &&
          patient.nurse.trim().toUpperCase() != 'N/A' &&
          patient.nurse.trim().toLowerCase() != 'none') {
        return StaffInfoResult(
          name: formatStaffName(patient.nurse),
          role: 'Staff',
        );
      }
      if (patient.doctor.trim().isNotEmpty &&
          patient.doctor.trim().toUpperCase() != 'N/A' &&
          patient.doctor.trim().toLowerCase() != 'none') {
        return StaffInfoResult(
          name: formatStaffName(patient.doctor),
          role: 'Doctor',
        );
      }
    }

    return const StaffInfoResult(name: 'Staff', role: 'Staff');
  }
}
