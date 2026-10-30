import 'package:flutter/material.dart';
import 'package:shifa_management/core/config/bank_details.dart';

class InvoiceBankDetailsSection extends StatelessWidget {
  final BankDetails? bankDetails;

  const InvoiceBankDetailsSection({super.key, this.bankDetails});

  @override
  Widget build(BuildContext context) {
    final details = bankDetails ?? BankDetails.defaultDetails;

    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BANK TRANSFER DETAILS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _bankDetailRow('Bank:', details.bankName),
            _bankDetailRow('Title:', details.accountTitle),
            _bankDetailRow('A/C #:', details.accountNumber),
            _bankDetailRow('IBAN:', details.iban),
          ],
        ),
      ),
    );
  }

  Widget _bankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
