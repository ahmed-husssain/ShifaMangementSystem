import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceHeaderSection extends StatelessWidget {
  final String invoiceNumber;
  final DateTime fromDate;
  final DateTime toDate;
  final String paymentStatus;
  final bool isEditable;
  final ValueChanged<bool>? onPickDate;
  final ValueChanged<String>? onStatusChanged;

  const InvoiceHeaderSection({
    super.key,
    required this.invoiceNumber,
    required this.fromDate,
    required this.toDate,
    required this.paymentStatus,
    this.isEditable = true,
    this.onPickDate,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Side: Logo & Tagline
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/ShifaLogo.jpeg',
                      width: 145,
                      height: 50,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, _, _) => const Text(
                        'SHIFA HOME HEALTH CARE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your Health, Our Mission',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Side: INVOICE, Invoice #, Dates, Payment Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Invoice #: ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      invoiceNumber.isEmpty ? '...' : invoiceNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // FROM Date Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FROM:',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: isEditable ? () => onPickDate?.call(true) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MM / dd / yyyy').format(fromDate),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isEditable) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: Colors.grey.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // TO Date Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TO:',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: isEditable ? () => onPickDate?.call(false) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MM / dd / yyyy').format(toDate),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isEditable) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: Colors.grey.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Payment Status Selector / Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STATUS:',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isEditable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: paymentStatus,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            items: ['Unpaid', 'Paid']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) onStatusChanged?.call(val);
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: paymentStatus == 'Paid'
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paymentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: paymentStatus == 'Paid'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: const Color(0xFFDBEAFE)),
      ],
    );
  }
}
