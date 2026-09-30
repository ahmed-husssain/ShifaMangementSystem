import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/editable_service_item.dart';
import '../../domain/invoice_constants.dart';

class InvoiceDetailsEditContent extends StatelessWidget {
  static const int _maxServices = 10;

  void _selectStandardServiceFor(EditableServiceItem item, String selectedService) {
    item.nameController.text = selectedService == 'Custom Service' ? '' : selectedService;
    if (InvoiceConstants.standardPrices.containsKey(selectedService)) {
      item.priceController.text = InvoiceConstants.standardPrices[selectedService]!.toStringAsFixed(0);
    }
    item.isNewlyAdded = false;
    onStateChanged();
  }

  final GlobalKey<FormState> formKey;
  final TextEditingController invoiceNumberController;
  final TextEditingController patientNameController;
  final TextEditingController patientPhoneController;
  final TextEditingController patientAddressController;
  final TextEditingController discountController;
  final String paymentStatus;
  final ValueChanged<String> onPaymentStatusChanged;
  final List<EditableServiceItem> editableServices;
  final VoidCallback onAddService;
  final void Function(int index) onRemoveService;
  final double subtotal;
  final double grandTotal;
  final bool isNarrow;
  final VoidCallback onStateChanged;

  const InvoiceDetailsEditContent({
    super.key,
    required this.formKey,
    required this.invoiceNumberController,
    required this.patientNameController,
    required this.patientPhoneController,
    required this.patientAddressController,
    required this.discountController,
    required this.paymentStatus,
    required this.onPaymentStatusChanged,
    required this.editableServices,
    required this.onAddService,
    required this.onRemoveService,
    required this.subtotal,
    required this.grandTotal,
    required this.isNarrow,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _buildEditForm(isNarrow);
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
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
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    String? prefixText,
    Widget? suffixIcon,
    bool readOnly = false,
    bool isNarrow = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: isNarrow ? 12 : 13),
      prefixText: prefixText,
      prefixStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: isNarrow ? 12 : 13,
        color: const Color(0xFF1E293B),
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 9 : 12,
        vertical: isNarrow ? 9 : 11,
      ),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
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
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _buildEditForm(bool isNarrow) {
    final formatter = NumberFormat('#,###');

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section 1: Patient Information ───
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Patient Information',
          ),
          Container(
            padding: EdgeInsets.all(isNarrow ? 11 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isNarrow) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildField(
                          label: 'Patient Name',
                          required: true,
                          child: TextFormField(
                            controller: patientNameController,
                            decoration: _buildInputDecoration(hintText: 'Enter patient full name'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildField(
                          label: 'Phone Number',
                          required: true,
                          child: TextFormField(
                            controller: patientPhoneController,
                            decoration: _buildInputDecoration(hintText: '03001234567'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildField(
                          label: 'Invoice Number',
                          child: TextFormField(
                            controller: invoiceNumberController,
                            readOnly: true,
                            decoration: _buildInputDecoration(readOnly: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildField(
                    label: 'Patient Name',
                    required: true,
                    child: TextFormField(
                      controller: patientNameController,
                      decoration: _buildInputDecoration(hintText: 'Enter patient full name', isNarrow: isNarrow),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildField(
                          label: 'Phone Number',
                          required: true,
                          child: TextFormField(
                            controller: patientPhoneController,
                            decoration: _buildInputDecoration(hintText: '03001234567', isNarrow: isNarrow),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildField(
                          label: 'Invoice #',
                          child: TextFormField(
                            controller: invoiceNumberController,
                            readOnly: true,
                            decoration: _buildInputDecoration(readOnly: true, isNarrow: isNarrow),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildField(
                  label: 'Address',
                  required: true,
                  child: TextFormField(
                    controller: patientAddressController,
                    maxLines: 2,
                    decoration: _buildInputDecoration(hintText: 'Enter complete home address', isNarrow: isNarrow),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Section 2: Services & Care Plan ───
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 17, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isNarrow ? 'Services' : 'Services & Care Plan',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${editableServices.length}/$_maxServices',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: editableServices.length < _maxServices ? onAddService : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                label: Text(
                  isNarrow ? 'Add' : 'Add Service',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 8 : 12,
                    vertical: isNarrow ? 6 : 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Service Items List
          ...editableServices.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return _buildServiceItemCard(
              item: item,
              index: idx,
              isNarrow: isNarrow,
              formatter: formatter,
            );
          }),

          const SizedBox(height: 16),

          // ─── Section 3: Financial Breakdown & Payment ───
          _buildSectionHeader(
            icon: Icons.payments_outlined,
            title: 'Financial Breakdown & Payment',
          ),
          if (!isNarrow) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Payment Status & Note
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(
                          label: 'Payment Status',
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentStatus,
                            decoration: _buildInputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                value: 'Paid',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                    SizedBox(width: 6),
                                    Text('Paid (Completed)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Unpaid',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 6),
                                    Text('Unpaid (Pending)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Partial',
                                child: Row(
                                  children: [
                                    Icon(Icons.pending_rounded, size: 16, color: Color(0xFFD97706)),
                                    SizedBox(width: 6),
                                    Text('Partial Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) onPaymentStatusChanged(val);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Saving automatically recalculates and syncs Total Revenue & Net Profit across Dashboard and Finances.',
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Right column: Financial Totals Card
                Expanded(
                  flex: 5,
                  child: _buildFinancialSummaryCard(formatter, isNarrow: isNarrow),
                ),
              ],
            ),
          ] else ...[
            // Narrow mobile layout: Stacked Payment & Totals
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _buildField(
                label: 'Payment Status',
                child: DropdownButtonFormField<String>(
                  initialValue: paymentStatus,
                  decoration: _buildInputDecoration(isNarrow: isNarrow),
                  items: const [
                    DropdownMenuItem(
                      value: 'Paid',
                      child: Text('Paid (Completed)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ),
                    DropdownMenuItem(
                      value: 'Unpaid',
                      child: Text('Unpaid (Pending)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    ),
                    DropdownMenuItem(
                      value: 'Partial',
                      child: Text('Partial Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) onPaymentStatusChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFinancialSummaryCard(formatter, isNarrow: isNarrow),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceItemCard({
    required EditableServiceItem item,
    required int index,
    required bool isNarrow,
    required NumberFormat formatter,
  }) {
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
              if (editableServices.length > 1)
                InkWell(
                  onTap: () => onRemoveService(index),
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
              onSelected: (selected) {
                _selectStandardServiceFor(item, selected);
              },
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
                    label: 'Days / Qty',
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
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) return '> 0';
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Line Total:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                  ),
                  Text(
                    'Rs. ${formatter.format(item.total.toInt())}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
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

  Widget _buildFinancialSummaryCard(NumberFormat formatter, {bool isNarrow = false}) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculated Subtotal:',
                style: TextStyle(
                  fontSize: isNarrow ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'Rs. ${formatter.format(subtotal.toInt())}',
                style: TextStyle(
                  fontSize: isNarrow ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            label: isNarrow ? 'Discount (PKR)' : 'Discount Amount (PKR)',
            child: TextFormField(
              controller: discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: _buildInputDecoration(
                hintText: '0',
                prefixText: 'Rs. ',
                isNarrow: isNarrow,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Must be a valid number';
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          // Grand Total Banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 10 : 14,
              vertical: isNarrow ? 9 : 11,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x261E40AF),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEW GRAND TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isNarrow ? 11 : 12.5,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Rs. ${formatter.format(grandTotal.toInt())}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isNarrow ? 14.5 : 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}
