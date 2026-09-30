import 'invoice_model.dart';

/// Single source of truth for standard invoice services and their default daily rates.
class InvoiceConstants {
  InvoiceConstants._();

  static const List<String> standardServices = [
    'Home Nursing Care Services',
    'Home Physiotherapy Services',
    'Home Attendant Service',
    'Home Nurse Visit',
    'Home NG Tube Insertion',
    'Wound & Bed Sore Dressing',
    'Home ICU Nurse',
    'Online Doctor Consultation',
    'Medical Equipment',
    'Custom Service',
  ];

  static const Map<String, double> standardPrices = {
    'Home Nursing Care Services': 3000.0,
    'Home Physiotherapy Services': 3000.0,
    'Home Attendant Service': 2000.0,
    'Home Nurse Visit': 2000.0,
    'Home NG Tube Insertion': 2500.0,
    'Wound & Bed Sore Dressing': 2000.0,
    'Home ICU Nurse': 3500.0,
    'Online Doctor Consultation': 0.0,
    'Medical Equipment': 0.0,
  };

  static const List<String> paymentStatuses = [
    'Unpaid',
    'Paid',
    'Pending',
    'Overdue',
    'Partial',
  ];

  /// Calculates the calendar day difference between [from] and [to].
  /// Guaranteed to return >= 1 (defaults to 1 if [to] <= [from]).
  static int calculateDaysBetween(DateTime from, DateTime to) {
    final fromDateOnly = DateTime(from.year, from.month, from.day);
    final toDateOnly = DateTime(to.year, to.month, to.day);
    final diff = toDateOnly.difference(fromDateOnly).inDays;
    return diff > 0 ? diff : 1;
  }

  /// Calculates the subtotal of an invoice from its items.
  static double calculateSubtotal(List<InvoiceItem> items) {
    return items.fold(0.0, (acc, item) => acc + item.total);
  }

  /// Calculates the grand total after applying discount. Never returns negative.
  static double calculateGrandTotal(double subtotal, double discount) {
    final total = subtotal - discount;
    return total < 0.0 ? 0.0 : total;
  }
}
