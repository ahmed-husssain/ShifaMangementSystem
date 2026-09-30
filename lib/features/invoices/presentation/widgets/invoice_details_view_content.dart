import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/invoice_model.dart';
import '../../../patients/domain/patient_model.dart';

class InvoiceDetailsViewContent extends StatelessWidget {
  final Invoice invoice;
  final Patient? patient;
  final String creatorName;
  final String creatorRole;

  const InvoiceDetailsViewContent({
    super.key,
    required this.invoice,
    this.patient,
    required this.creatorName,
    required this.creatorRole,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(invoice.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Metadata ---
        _buildSectionTitle('Invoice Metadata'),
        _buildInfoRow(context, 'Grand Total', 'Rs. ${NumberFormat('#,###').format(invoice.grandTotal.toInt())}'),
        _buildInfoRow(context, 'Date & Time', dateStr),
        if (invoice.fromDate != null)
          _buildInfoRow(context, 'Service From', DateFormat('dd/MM/yyyy').format(invoice.fromDate!)),
        if (invoice.toDate != null)
          _buildInfoRow(context, 'Service To', DateFormat('dd/MM/yyyy').format(invoice.toDate!)),
        if (invoice.days > 0)
          _buildInfoRow(context, 'Service Days', '${invoice.days} Days'),
        _buildInfoRow(
          context,
          'Payment Status',
          invoice.paymentStatus.toUpperCase(),
          valueColor: invoice.paymentStatus.trim().toLowerCase() == 'paid' ? Colors.green.shade700 : Colors.red.shade700,
        ),
        _buildInfoRow(context, 'Created By', creatorName),
        if (creatorRole.isNotEmpty && creatorRole != 'N/A')
          _buildInfoRow(context, 'Role', creatorRole.toUpperCase()),
        const SizedBox(height: 16),

        // --- Patient ---
        _buildSectionTitle('Patient Information'),
        _buildInfoRow(context, 'Patient Name', patient?.patientName ?? 'N/A'),
        _buildInfoRow(context, 'MR Number', patient?.mrNumber ?? 'N/A'),
        _buildInfoRow(context, 'Phone Number', patient?.phone ?? 'N/A'),
        _buildInfoRow(context, 'Address', patient?.address ?? 'N/A'),
        const SizedBox(height: 16),

        // --- Service Details ---
        _buildSectionTitle('Service Details'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Service',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Rate',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Qty',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // Service Items
              ...invoice.items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isEven = idx % 2 == 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.serviceName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Rs. ${NumberFormat('#,###').format(item.price.toInt())}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Rs. ${NumberFormat('#,###').format(item.total.toInt())}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E40AF),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Summary Breakdown Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text(
                    'Rs. ${NumberFormat('#,###').format(invoice.subtotal.toInt())}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              if (invoice.discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      '- Rs. ${NumberFormat('#,###').format(invoice.discount.toInt())}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Divider(height: 1, color: Color(0xFFCBD5E1)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(
                    'Rs. ${NumberFormat('#,###').format(invoice.grandTotal.toInt())}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0)),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final displayValue = value.isEmpty ? 'N/A' : value;
    final isCopyable = (label.contains('MR') ||
        label.contains('Name') ||
        label.contains('Phone') ||
        label.contains('Address') ||
        label.contains('Invoice'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCopyable ? FontWeight.bold : FontWeight.normal,
                color: isCopyable ? const Color(0xFF1565C0) : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () {
                if (isCopyable && displayValue != 'N/A') {
                  Clipboard.setData(ClipboardData(text: displayValue));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Copied $label: $displayValue'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF004B93),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: SelectableText(
                        displayValue,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: displayValue == 'N/A' ? Colors.grey : valueColor,
                        ),
                      ),
                    ),
                    if (isCopyable && displayValue != 'N/A') ...[
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 13, color: Colors.blue.shade700),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
