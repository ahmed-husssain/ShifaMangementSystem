import 'package:flutter/material.dart';

class PaymentStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const PaymentStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final clean = status.trim().toLowerCase();
    final bool isPaid = clean == 'paid';
    final bool isPartial = clean == 'partial' || clean == 'partially paid';

    final Color bg = isPaid
        ? const Color(0xFFDCFCE7)
        : (isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));

    final Color text = isPaid
        ? const Color(0xFF15803D)
        : (isPartial ? const Color(0xFFB45309) : const Color(0xFFB91C1C));

    final Color border = isPaid
        ? const Color(0xFF86EFAC)
        : (isPartial ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5));

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        status.trim().toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
