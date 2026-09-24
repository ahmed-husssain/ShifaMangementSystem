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
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
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
