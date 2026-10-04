import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Staff Phone Field Numeric Restriction Tests', () {
    test('FilteringTextInputFormatter.digitsOnly strips all alphabetic characters', () {
      final formatter = FilteringTextInputFormatter.digitsOnly;

      const oldValue = TextEditingValue.empty;
      const newValueWithLetters = TextEditingValue(
        text: 'abc123def456!@#',
        selection: TextSelection.collapsed(offset: 15),
      );

      final result = formatter.formatEditUpdate(oldValue, newValueWithLetters);
      expect(result.text, equals('123456'));
    });

    test('Staff phone validator accepts valid numeric strings', () {
      String? validateStaffPhone(String? v) {
        final trimmed = v?.trim() ?? '';
        if (trimmed.isNotEmpty && !RegExp(r'^\d{1,15}$').hasMatch(trimmed)) {
          return 'Staff phone must contain digits only';
        }
        return null;
      }

      expect(validateStaffPhone(''), isNull);
      expect(validateStaffPhone(null), isNull);
      expect(validateStaffPhone('03001234567'), isNull);
      expect(validateStaffPhone('923001234567'), isNull);
      expect(validateStaffPhone('12345'), isNull);
    });

    test('Staff phone validator rejects alphabetic or special characters', () {
      String? validateStaffPhone(String? v) {
        final trimmed = v?.trim() ?? '';
        if (trimmed.isNotEmpty && !RegExp(r'^\d{1,15}$').hasMatch(trimmed)) {
          return 'Staff phone must contain digits only';
        }
        return null;
      }

      expect(validateStaffPhone('abc'), equals('Staff phone must contain digits only'));
      expect(validateStaffPhone('0300-1234567'), equals('Staff phone must contain digits only'));
      expect(validateStaffPhone('+923001234567'), equals('Staff phone must contain digits only'));
      expect(validateStaffPhone('phone123'), equals('Staff phone must contain digits only'));
      expect(validateStaffPhone('0300 1234567'), equals('Staff phone must contain digits only'));
    });

    testWidgets('TextFormField with digitsOnly rejects typing alphabets in UI', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
          ),
        ),
      );

      final finder = find.byType(TextFormField);
      await tester.enterText(finder, '0300abcXYZ12345');
      await tester.pump();

      expect(controller.text, equals('030012345'));
    });
  });
}
