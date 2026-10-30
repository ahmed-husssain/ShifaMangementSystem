import 'package:intl/intl.dart';

extension CurrencyFormatter on num {
  static final NumberFormat _formatter = NumberFormat('#,##0');

  String toCurrency({String symbol = 'Rs. '}) {
    return '$symbol${_formatter.format(this)}';
  }

  String toFormattedNumber() {
    return _formatter.format(this);
  }
}
