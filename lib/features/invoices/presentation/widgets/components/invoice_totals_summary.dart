import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InvoiceTotalsSummary extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double grandTotal;
  final String paymentStatus;
  final bool isEditable;
  final ValueChanged<double>? onDiscountChanged;

  const InvoiceTotalsSummary({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.grandTotal,
    required this.paymentStatus,
    this.isEditable = true,
    this.onDiscountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        children: [
          _totalRow('SUBTOTAL:', '${subtotal.toStringAsFixed(0)} PKR'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISCOUNT:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (isEditable)
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val.trim()) ?? 0.0;
                      onDiscountChanged?.call(parsed);
                    },
                  ),
                )
              else
                Text(
                  '${discount.toStringAsFixed(0)} PKR',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${grandTotal.toStringAsFixed(0)} PKR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: paymentStatus == 'Paid'
                  ? const Color(0xFF16A34A)
                  : (paymentStatus == 'Partial'
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                paymentStatus.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
