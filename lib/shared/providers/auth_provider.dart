import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

extension SupabaseUserExtension on User {
  String get uid => id;
  String? get displayName => userMetadata?['name'] as String? ?? email;
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class SplashCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setCompleted(bool value) {
    state = value;
  }
}

final splashCompletedProvider = NotifierProvider<SplashCompletedNotifier, bool>(() {
  return SplashCompletedNotifier();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final initialUser = supabase.auth.currentUser;
  final authStream = supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  return Stream<User?>.multi((controller) {
    controller.add(initialUser);
    final sub = authStream.listen(
      (user) => controller.add(user),
      onError: (err, st) => controller.addError(err, st),
      onDone: () => controller.close(),
    );
    controller.onCancel = () => sub.cancel();
  });
});

class LoginErrorMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? message) => state = message;
}

final loginErrorMessageProvider = NotifierProvider<LoginErrorMessageNotifier, String?>(
  LoginErrorMessageNotifier.new,
);

/// Returns true if the status string represents a deactivated/disabled account.
bool _isDeactivatedStatus(String status) {
  return status == 'deactivated' || status == 'disabled' || status == 'inactive';
}

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(null);
  }

  // Resilient fallback profile from Auth token metadata
  final fallbackProfile = <String, dynamic>{
    'id': user.id,
    'uid': user.id,
    'email': user.email ?? '',
    'name': user.userMetadata?['name'] ?? user.email ?? 'User',
    'username': user.userMetadata?['username'] ?? 'USER',
    'role': user.userMetadata?['role'] ?? 'staff',
    'status': 'active',
    'organization_id': 'default',
  };

  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) {
        if (rows.isEmpty) return fallbackProfile;
        final data = rows.first;
        if (data['is_deleted'] == true) return null;
        return {
          ...data,
          'uid': data['id'],
          'role': data['role'] ?? fallbackProfile['role'],
        };
      })
      .handleError((_) => fallbackProfile);
});

/// Returns true if a string is a generic placeholder that must never be used for identity matching.
bool isGenericStaffIdentifier(String val) {
  final lower = val.trim().toLowerCase();
  return lower == 'user' ||
      lower == 'staff' ||
      lower == 'admin' ||
      lower == 'staff user' ||
      lower == 'admin user' ||
      lower == 'user user' ||
      lower == 'default' ||
      lower == 'system' ||
      lower == 'n/a' ||
      lower == 'na' ||
      lower == 'none' ||
      lower == 'null' ||
      lower == 'caretaker' ||
      lower.isEmpty;
}

/// Provider that extracts all genuine identifiers (UUID, specific username, specific name, email, email prefix) for the currently authenticated user.
final currentStaffIdentifiersProvider = Provider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final profile = ref.watch(userProfileProvider).value;

  final ids = <String>{};
  if (user != null) {
    if (user.id.isNotEmpty) ids.add(user.id.trim().toLowerCase());
    if (user.email != null && user.email!.isNotEmpty) {
      final cleanEmail = user.email!.trim().toLowerCase();
      ids.add(cleanEmail);
      final emailPrefix = cleanEmail.split('@').first.trim();
      if (emailPrefix.isNotEmpty && !isGenericStaffIdentifier(emailPrefix)) {
        ids.add(emailPrefix);
      }
    }
    final metaUsername = (user.userMetadata?['username'] ?? '').toString().trim().toLowerCase();
    final metaName = (user.userMetadata?['name'] ?? '').toString().trim().toLowerCase();
    if (metaUsername.isNotEmpty && !isGenericStaffIdentifier(metaUsername)) ids.add(metaUsername);
    if (metaName.isNotEmpty && !isGenericStaffIdentifier(metaName)) ids.add(metaName);
  }
  if (profile != null) {
    final uid = (profile['uid'] ?? profile['id'] ?? '').toString().trim().toLowerCase();
    final username = (profile['username'] ?? '').toString().trim().toLowerCase();
    final name = (profile['name'] ?? '').toString().trim().toLowerCase();
    final email = (profile['email'] ?? '').toString().trim().toLowerCase();

    if (uid.isNotEmpty) ids.add(uid);
    if (username.isNotEmpty && !isGenericStaffIdentifier(username)) ids.add(username);
    if (name.isNotEmpty && !isGenericStaffIdentifier(name)) ids.add(name);
    if (email.isNotEmpty && !isGenericStaffIdentifier(email)) ids.add(email);
  }
  return ids;
});

/// Resilient exact match (case-insensitive & trimmed) against the staff's known identifiers.
bool matchesStaffIdentifier(String? value, Set<String> staffIdentifiers) {
  if (value == null || staffIdentifiers.isEmpty) return false;
  final cleanVal = value.trim().toLowerCase();
  if (cleanVal.isEmpty || isGenericStaffIdentifier(cleanVal)) return false;

  // Direct exact match (case-insensitive)
  if (staffIdentifiers.contains(cleanVal)) return true;
  for (final id in staffIdentifiers) {
    if (id.trim().toLowerCase() == cleanVal) return true;
  }

  // If cleanVal is an email (e.g. "ali@internal.shifa.app"), check its prefix ("ali")
  if (cleanVal.contains('@')) {
    final prefix = cleanVal.split('@').first.trim();
    if (prefix.isNotEmpty && !isGenericStaffIdentifier(prefix) && staffIdentifiers.contains(prefix)) {
      return true;
    }
  }

  // If any staffIdentifier is an email, check if its prefix matches cleanVal
  for (final id in staffIdentifiers) {
    if (id.contains('@')) {
      final idPrefix = id.split('@').first.trim();
      if (idPrefix.isNotEmpty && idPrefix == cleanVal) return true;
    }
  }

  // Word/token match: check if cleanVal contains any staff identifier as a distinct word
  final words = cleanVal.split(RegExp(r'[\s,._\-/]+'));
  for (final word in words) {
    if (word.length >= 3 && !isGenericStaffIdentifier(word) && staffIdentifiers.contains(word)) {
      return true;
    }
  }

  return false;
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    supabase: ref.watch(supabaseClientProvider),
    ref: ref,
  );
});

class AuthController {
  final SupabaseClient supabase;
  final Ref? ref;

  AuthController({
    required this.supabase,
    this.ref,
  });

  Future<void> login(String username, String password) async {
    final clean = username.trim();
    String email = clean;

    if (!clean.contains('@')) {
      try {
        final resolved = await supabase.rpc('resolve_username_to_email', params: {'p_username': clean});
        if (resolved != null && resolved.toString().isNotEmpty) {
          email = resolved.toString();
        } else {
          email = '${clean.toLowerCase()}@internal.shifa.app';
        }
      } catch (_) {
        email = '${clean.toLowerCase()}@internal.shifa.app';
      }
    }

    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      if (res.user != null) {
        try {
          final profile = await supabase.from('users').select().eq('id', res.user!.id).maybeSingle();
          if (profile != null) {
            final isDeleted = profile['is_deleted'] == true;
            final status = (profile['status'] ?? 'active').toString().toLowerCase();

            if (isDeleted || _isDeactivatedStatus(status)) {
              ref?.read(loginErrorMessageProvider.notifier).setMessage(
                'Your account has been deactivated. Please contact an administrator.',
              );
              await supabase.auth.signOut();
              throw Exception('Your account has been deactivated. Please contact an administrator.');
            }
          }
        } catch (e) {
          if (e.toString().contains('deactivated')) rethrow;
        }
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('banned') || e.message.toLowerCase().contains('disabled')) {
        ref?.read(loginErrorMessageProvider.notifier).setMessage(
          'Your account has been deactivated. Please contact an administrator.',
        );
        throw Exception('Your account has been deactivated. Please contact an administrator.');
      }
      throw Exception('Incorrect username or password. Please try again.');
    }
  }

  /// Creates a staff user account cleanly via PostgreSQL SECURITY DEFINER RPC.
  /// Generates the auth.users record, auth.identities, and public.users profile without secret keys.
  Future<void> createUserAccount({
    required String username,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    final clean = username.trim().toUpperCase();
    final email = '${clean.toLowerCase()}@internal.shifa.app';

    final res = await supabase.rpc('create_staff_user', params: {
      'p_email': email,
      'p_password': password,
      'p_username': clean,
      'p_name': name,
      'p_role': role,
      'p_phone': phone,
      'p_organization_id': 'default',
    });

    if (res is Map && res['error'] != null) {
      throw Exception(res['error']);
    }
  }

  /// Updates a user's password cleanly via PostgreSQL SECURITY DEFINER RPC.
  Future<void> adminUpdateUserPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    await supabase.rpc('admin_update_user_password', params: {
      'p_target_uid': targetUid,
      'p_new_password': newPassword,
    });
  }

  /// Deactivates a user account cleanly via PostgreSQL SECURITY DEFINER RPC.
  /// Immediately marks status = 'deactivated' and bans the user in auth.users.
  Future<void> deactivateUser({required String targetUid}) async {
    await supabase.rpc('toggle_user_status', params: {
      'p_target_uid': targetUid,
      'p_status': 'deactivated',
    });
  }

  /// Reactivates a user account cleanly via PostgreSQL SECURITY DEFINER RPC.
  /// Immediately restores status = 'active' and unbans the user in auth.users.
  Future<void> reactivateUser({required String targetUid}) async {
    await supabase.rpc('toggle_user_status', params: {
      'p_target_uid': targetUid,
      'p_status': 'active',
    });
  }

  /// Permanently deletes a user account cleanly via PostgreSQL SECURITY DEFINER RPC.
  Future<void> deleteUserAccount({required String targetUid}) async {
    await supabase.rpc('delete_user_account', params: {
      'p_target_uid': targetUid,
    });
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
