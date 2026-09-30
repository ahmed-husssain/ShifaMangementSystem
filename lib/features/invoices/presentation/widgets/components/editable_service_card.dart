import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../domain/editable_service_item.dart';
import '../../../domain/invoice_constants.dart';

class EditableServiceCard extends StatelessWidget {
  final EditableServiceItem item;
  final int index;
  final int totalCount;
  final bool isNarrow;
  final NumberFormat formatter;
  final VoidCallback onRemove;
  final void Function(EditableServiceItem item, String selectedService) onSelectStandardService;

  const EditableServiceCard({
    super.key,
    required this.item,
    required this.index,
    required this.totalCount,
    required this.isNarrow,
    required this.formatter,
    required this.onRemove,
    required this.onSelectStandardService,
  });

  InputDecoration _buildInputDecoration({
    String? hintText,
    String? prefixText,
    bool isNarrow = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 12,
        vertical: isNarrow ? 8 : 10,
      ),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      errorStyle: const TextStyle(fontSize: 10.5, height: 1.1),
    );
  }

  Widget _buildField({
    required String label,
    required Widget child,
    bool required = false,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  children: [
                    if (required)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isNewlyAdded ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
          width: item.isNewlyAdded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: item.isNewlyAdded ? const Color(0x1A3B82F6) : const Color(0x06000000),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isNarrow ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Badge & Delete Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'Service #${index + 1}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  if (item.isNewlyAdded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ],
              ),
              if (totalCount > 1)
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  isNarrow ? 'Primary (Req)' : 'Primary Service (Required)',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Service Name field with Quick Select Standard dropdown
          _buildField(
            label: isNarrow ? 'Service Name' : 'Service Name / Care Description',
            required: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Choose standard service',
              onSelected: (selected) => onSelectStandardService(item, selected),
              itemBuilder: (context) => InvoiceConstants.standardServices.map((serviceName) {
                final price = InvoiceConstants.standardPrices[serviceName];
                final priceStr = (price != null && price > 0)
                    ? ' (Rs. ${formatter.format(price.toInt())})'
                    : '';
                return PopupMenuItem<String>(
                  value: serviceName,
                  child: Text('$serviceName$priceStr', style: const TextStyle(fontSize: 12.5)),
                );
              }).toList(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 6 : 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list_alt_rounded, size: 13, color: Color(0xFF1565C0)),
                    const SizedBox(width: 3),
                    Text(
                      isNarrow ? 'Standard ▾' : 'Standard List ▾',
                      style: TextStyle(
                        fontSize: isNarrow ? 10.5 : 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: TextFormField(
              controller: item.nameController,
              decoration: _buildInputDecoration(
                hintText: 'e.g. Home Nursing Care Services',
                isNarrow: isNarrow,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Service name is required' : null,
            ),
          ),
          const SizedBox(height: 10),

          // Pricing, Days, and Line Total
          if (!isNarrow) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rate
                Expanded(
                  flex: 4,
                  child: _buildField(
                    label: 'Rate / Day (PKR)',
                    required: true,
                    child: TextFormField(
                      controller: item.priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: _buildInputDecoration(
                        hintText: '0',
                        prefixText: 'Rs. ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Days
                Expanded(
                  flex: 3,
                  child: _buildField(
                    label: 'Days / Qty',
                    required: true,
                    child: TextFormField(
                      controller: item.daysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _buildInputDecoration(
                        hintText: '1',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return '> 0';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Line Total
                Expanded(
                  flex: 4,
                  child: _buildField(
                    label: 'Line Total',
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Rs. ${formatter.format(item.total.toInt())}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Narrow mobile layout: Rate & Days side-by-side, followed by Line Total card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildField(
                    label: 'Rate / Day',
                    required: true,
                    child: TextFormField(
                      controller: item.priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      decoration: _buildInputDecoration(
                        hintText: '0',
                        prefixText: 'Rs. ',
                        isNarrow: isNarrow,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildField(
                    label: 'Days',
                    required: true,
                    child: TextFormField(
                      controller: item.daysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _buildInputDecoration(
                        hintText: '1',
                        isNarrow: isNarrow,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Req';
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return '>0';
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Line Total:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    'Rs. ${formatter.format(item.total.toInt())}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
