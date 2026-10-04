import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shifa_management/core/config/supabase_config.dart';

void main() {
  test('Anonymous caller is rejected by create_invoice_atomic', () async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
    );

    try {
      await client.rpc('create_invoice_atomic', params: {
        'invoice_payload': {
          'patient_id': 'pat-1',
          'subtotal': 1000,
          'grand_total': 1000,
        }
      });
      fail('Expected exception for unauthenticated caller');
    } catch (e) {
      print('Anon rejection verified successfully: $e');
      expect(e.toString().toLowerCase(), anyOf(contains('unauthorized'), contains('42501'), contains('permission denied')));
    }
  });
}
