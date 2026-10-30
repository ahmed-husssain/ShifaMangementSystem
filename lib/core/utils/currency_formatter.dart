import 'package:intl/intl.dart';

const String kAppCurrency = String.fromEnvironment('APP_CURRENCY', defaultValue: 'QAR');
const String kAppCurrencySymbol = String.fromEnvironment('APP_CURRENCY_SYMBOL', defaultValue: 'QAR ');

extension CurrencyFormatter on num {
  static final NumberFormat _formatter = NumberFormat('#,##0');

  String toCurrency({String symbol = kAppCurrencySymbol}) {
    return '$symbol${_formatter.format(this)}';
  }

  String toFormattedNumber() {
    return _formatter.format(this);
  }
}
