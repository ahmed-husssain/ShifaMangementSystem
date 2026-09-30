import 'package:flutter/material.dart';

class InvoicePolicyNotice extends StatelessWidget {
  const InvoicePolicyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            color: Colors.orange.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IMPORTANT POLICY NOTICE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please be advised that the payments for medical equipment rentals and purchases are non-refundable. Upon agreement, the full payment is required in advance or upon receipt of the equipment. Direct the company responsibility beyond damage caused due to mishandling or willful negligence.',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'THIS IS A COMPUTERIZED GENERATED INVOICE. NO SIGNATURE REQUIRED.',
            style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
