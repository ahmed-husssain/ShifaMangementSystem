import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shifa_management/core/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  test('Test Supabase auth initialized', () async {
    final client = Supabase.instance.client;
    try {
      final res = await client.auth.signUp(
        email: 'redacted@example.com',
        password: 'REDACTED_PASSWORD',
      );
      print('SignUp success: user=${res.user?.id}, session=${res.session != null}');
    } catch (e) {
      print('SignUp response: $e');
    }
  });
}
