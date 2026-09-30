import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/editable_service_item.dart';
import '../../domain/invoice_constants.dart';
import 'components/editable_service_card.dart';

class InvoiceDetailsEditContent extends StatelessWidget {
  static const int _maxServices = 10;

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

  void _selectStandardServiceFor(EditableServiceItem item, String selectedService) {
    item.nameController.text = selectedService == 'Custom Service' ? '' : selectedService;
    if (InvoiceConstants.standardPrices.containsKey(selectedService)) {
      item.priceController.text = InvoiceConstants.standardPrices[selectedService]!.toStringAsFixed(0);
    }
    item.isNewlyAdded = false;
    onStateChanged();
  }

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
    final formatter = NumberFormat('#,###');

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section 1: Patient Details ───
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Patient Information',
          ),
          Container(
            padding: EdgeInsets.all(isNarrow ? 10 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildField(
                  label: 'Patient Name',
                  required: true,
                  child: TextFormField(
                    controller: patientNameController,
                    decoration: _buildInputDecoration(hintText: 'Enter patient name', isNarrow: isNarrow),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Patient name is required' : null,
                  ),
                ),
                const SizedBox(height: 10),
                if (!isNarrow)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          label: 'Phone Number',
                          required: true,
                          child: TextFormField(
                            controller: patientPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(hintText: '0300-1234567'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          label: 'Address',
                          required: true,
                          child: TextFormField(
                            controller: patientAddressController,
                            decoration: _buildInputDecoration(hintText: 'City / Residential area'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildField(
                    label: 'Phone Number',
                    required: true,
                    child: TextFormField(
                      controller: patientPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(hintText: '0300-1234567', isNarrow: isNarrow),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildField(
                    label: 'Address',
                    required: true,
                    child: TextFormField(
                      controller: patientAddressController,
                      decoration: _buildInputDecoration(hintText: 'City / Residential area', isNarrow: isNarrow),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Section 2: Services Rendered ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                icon: Icons.medical_services_outlined,
                title: 'Services Rendered (${editableServices.length}/$_maxServices)',
              ),
              FilledButton.icon(
                onPressed: editableServices.length >= _maxServices ? null : onAddService,
                icon: Icon(Icons.add_rounded, size: isNarrow ? 14 : 16),
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

          // Service Items List using EditableServiceCard
          ...editableServices.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return EditableServiceCard(
              item: item,
              index: idx,
              totalCount: editableServices.length,
              isNarrow: isNarrow,
              formatter: formatter,
              onRemove: () => onRemoveService(idx),
              onSelectStandardService: _selectStandardServiceFor,
            );
          }),

          const SizedBox(height: 16),

          // ─── Section 3: Financial Breakdown & Payment ───
          _buildSectionHeader(
            icon: Icons.payments_outlined,
            title: 'Financial Breakdown & Payment',
          ),
          if (!isNarrow)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Financial metrics across analytics, finance reports, and patient ledger will automatically update upon saving.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                Expanded(
                  flex: 5,
                  child: _buildFinancialSummaryCard(formatter, isNarrow: false),
                ),
              ],
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _buildField(
                label: 'Payment Status',
                child: DropdownButtonFormField<String>(
                  initialValue: paymentStatus,
                  decoration: _buildInputDecoration(isNarrow: true),
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
                'Rs. ',
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
                  'Rs. ',
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
