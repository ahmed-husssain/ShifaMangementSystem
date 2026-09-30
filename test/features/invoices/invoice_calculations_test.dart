import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/features/invoices/domain/invoice_constants.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';

void main() {
  group('InvoiceConstants - Day Calculation', () {
    test('10 Oct to 15 Oct correctly calculates 5 days', () {
      final from = DateTime(2026, 10, 10);
      final to = DateTime(2026, 10, 15);
      expect(InvoiceConstants.calculateDaysBetween(from, to), equals(5));
    });

    test('Same date defaults to 1 day', () {
      final from = DateTime(2026, 10, 10);
      final to = DateTime(2026, 10, 10);
      expect(InvoiceConstants.calculateDaysBetween(from, to), equals(1));
    });

    test('To before From defaults safely to 1 day', () {
      final from = DateTime(2026, 10, 15);
      final to = DateTime(2026, 10, 10);
      expect(InvoiceConstants.calculateDaysBetween(from, to), equals(1));
    });

    test('Month crossover 30 Sep to 5 Oct calculates 5 days', () {
      final from = DateTime(2026, 9, 30);
      final to = DateTime(2026, 10, 5);
      expect(InvoiceConstants.calculateDaysBetween(from, to), equals(5));
    });
  });

  group('InvoiceConstants - Totals Calculation', () {
    test('calculateSubtotal sums up item totals accurately', () {
      final items = [
        InvoiceItem(serviceName: 'Home Nursing Care Services', price: 3000.0, quantity: 5),
        InvoiceItem(serviceName: 'Home Physiotherapy Services', price: 2000.0, quantity: 3),
      ];
      // 3000 * 5 = 15000, 2000 * 3 = 6000 => 21000
      expect(InvoiceConstants.calculateSubtotal(items), equals(21000.0));
    });

    test('calculateGrandTotal subtracts discount accurately', () {
      expect(InvoiceConstants.calculateGrandTotal(21000.0, 1000.0), equals(20000.0));
    });

    test('calculateGrandTotal clamps at 0.0 if discount exceeds subtotal', () {
      expect(InvoiceConstants.calculateGrandTotal(500.0, 1000.0), equals(0.0));
    });
  });
}
