import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clinic bank account configuration for invoicing & payments.
class BankDetails {
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String iban;

  const BankDetails({
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.iban,
  });

  /// Default bank details with dynamic compile-time environment overrides
  static const defaultDetails = BankDetails(
    bankName: String.fromEnvironment('CLINIC_BANK_NAME', defaultValue: 'Qatar National Bank (QNB)'),
    accountTitle: String.fromEnvironment('CLINIC_ACCOUNT_TITLE', defaultValue: 'AL-SHIFA HOME NURSING SERVICES WLL'),
    accountNumber: String.fromEnvironment('CLINIC_ACCOUNT_NO', defaultValue: '00102701151847'),
    iban: String.fromEnvironment('CLINIC_IBAN', defaultValue: 'QA42QNBA00000000102701151847'),
  );

  factory BankDetails.fromMap(Map<String, dynamic> map) {
    return BankDetails(
      bankName: map['bank_name']?.toString() ?? defaultDetails.bankName,
      accountTitle: map['account_title']?.toString() ?? defaultDetails.accountTitle,
      accountNumber: map['account_number']?.toString() ?? defaultDetails.accountNumber,
      iban: map['iban']?.toString() ?? defaultDetails.iban,
    );
  }

  Map<String, String> toMap() {
    return {
      'bank_name': bankName,
      'account_title': accountTitle,
      'account_number': accountNumber,
      'iban': iban,
    };
  }
}

/// Provider for dynamic clinic bank details
final clinicBankDetailsProvider = Provider<BankDetails>((ref) {
  return BankDetails.defaultDetails;
});
