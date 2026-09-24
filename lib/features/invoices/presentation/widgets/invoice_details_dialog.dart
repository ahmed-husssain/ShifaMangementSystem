import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../domain/invoice_model.dart';
import '../../data/invoice_repository.dart';
import '../../../patients/domain/patient_model.dart';
import '../../../../shared/providers/auth_provider.dart';

class _EditableServiceItem {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController daysController;
  bool isNewlyAdded;

  _EditableServiceItem({
    required String serviceName,
    required double price,
    required int days,
    this.isNewlyAdded = false,
    VoidCallback? onChanged,
  })  : nameController = TextEditingController(text: serviceName),
        priceController = TextEditingController(text: price > 0 ? price.toStringAsFixed(0) : '0'),
        daysController = TextEditingController(text: days > 0 ? days.toString() : '1') {
    if (onChanged != null) {
      nameController.addListener(onChanged);
      priceController.addListener(onChanged);
      daysController.addListener(onChanged);
    }
  }

  double get price => double.tryParse(priceController.text.trim()) ?? 0.0;
  int get days => int.tryParse(daysController.text.trim()) ?? 0;
  double get total => price * days;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    daysController.dispose();
  }
}

class InvoiceDetailsDialog extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  @override
  ConsumerState<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends ConsumerState<InvoiceDetailsDialog> {
  static const int _maxServices = 10;

  static const List<String> _standardServices = [
    'Home Nursing Care Services',
    'Home Physiotherapy Services',
    'Home Attendant Service',
    'Home Nurse Visit',
    'Home NG Tube Insertion',
    'Wound & Bed Sore Dressing',
    'Home ICU Nurse',
    'Online Doctor Consultation',
    'Medical Equipment',
    'Custom Service',
  ];

  static const Map<String, double> _standardPrices = {
    'Home Nursing Care Services': 3000.0,
    'Home Physiotherapy Services': 3000.0,
    'Home Attendant Service': 2000.0,
    'Home Nurse Visit': 2000.0,
    'Home NG Tube Insertion': 2500.0,
    'Wound & Bed Sore Dressing': 2000.0,
    'Home ICU Nurse': 3500.0,
    'Online Doctor Consultation': 0.0,
    'Medical Equipment': 0.0,
  };

  bool _isEditing = false;
  bool _isLoadingPatient = true;
  bool _isSaving = false;
  Patient? _patient;

  // Controllers
  late TextEditingController _invoiceNumberController;
  late TextEditingController _discountController;
  late TextEditingController _patientNameController;
  late TextEditingController _patientPhoneController;
  late TextEditingController _patientAddressController;
  late final ScrollController _scrollController;
  late String _paymentStatus;
  String _creatorName = 'Loading...';
  String _creatorRole = '';

  late List<_EditableServiceItem> _editableServices;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _invoiceNumberController = TextEditingController(text: widget.invoice.invoiceNumber);
    _discountController = TextEditingController(text: widget.invoice.discount.toStringAsFixed(0));
    _discountController.addListener(() => setState(() {}));
    _paymentStatus = widget.invoice.paymentStatus;
    
    _patientNameController = TextEditingController();
    _patientPhoneController = TextEditingController();
    _patientAddressController = TextEditingController();

    _initEditableServices();
    _loadPatientData();
    _loadCreatorInfo();
  }

  void _initEditableServices() {
    _editableServices = widget.invoice.items.map((item) {
      return _EditableServiceItem(
        serviceName: item.serviceName,
        price: item.price,
        days: item.quantity > 0 ? item.quantity : (widget.invoice.days > 0 ? widget.invoice.days : 1),
        onChanged: () => setState(() {}),
      );
    }).toList();

    if (_editableServices.isEmpty) {
      _editableServices.add(_EditableServiceItem(
        serviceName: '',
        price: 0.0,
        days: widget.invoice.days > 0 ? widget.invoice.days : 1,
        onChanged: () => setState(() {}),
      ));
    }
  }

  double get _subtotal {
    return _editableServices.fold(0.0, (acc, item) => acc + item.total);
  }

  double get _discount {
    return double.tryParse(_discountController.text.trim()) ?? 0.0;
  }

  double get _grandTotal {
    final total = _subtotal - _discount;
    return total < 0 ? 0.0 : total;
  }

  void _addServiceRow() {
    if (_editableServices.length >= _maxServices) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 10 services allowed per invoice.'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final defaultDays = _editableServices.isNotEmpty && _editableServices.first.days > 0
          ? _editableServices.first.days
          : (widget.invoice.days > 0 ? widget.invoice.days : 1);
      _editableServices.add(_EditableServiceItem(
        serviceName: '',
        price: 0.0,
        days: defaultDays,
        isNewlyAdded: true,
        onChanged: () => setState(() {}),
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removeServiceRow(int index) {
    if (_editableServices.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An invoice must contain at least one service.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      final removed = _editableServices.removeAt(index);
      removed.dispose();
    });
  }

  void _selectStandardServiceFor(_EditableServiceItem item, String selectedService) {
    item.nameController.text = selectedService == 'Custom Service' ? '' : selectedService;
    if (_standardPrices.containsKey(selectedService)) {
      item.priceController.text = _standardPrices[selectedService]!.toStringAsFixed(0);
    }
    item.isNewlyAdded = false;
    setState(() {});
  }

  Future<void> _loadCreatorInfo() async {
    if (widget.invoice.createdByName != null && widget.invoice.createdByName!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _creatorName = widget.invoice.createdByName!;
          _creatorRole = widget.invoice.createdByRole ?? 'Staff';
        });
      }
      return;
    }

    final creatorUid = widget.invoice.createdByUid ?? 
                       (widget.invoice.createdBy.isNotEmpty ? widget.invoice.createdBy : widget.invoice.staffId);

    if (creatorUid.isNotEmpty) {
      try {
        final doc = await Supabase.instance.client.from('users').select().eq('id', creatorUid).maybeSingle();
        if (doc != null && mounted) {
          setState(() {
            _creatorName = doc['name'] ?? doc['username'] ?? doc['email'] ?? 'Unknown';
            _creatorRole = doc['role'] ?? 'Staff';
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _creatorName = 'Unknown';
        _creatorRole = 'N/A';
      });
    }
  }

  Future<void> _loadPatientData() async {
    try {
      final doc = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.invoice.patientId)
          .maybeSingle();
      if (doc != null && mounted) {
        final p = Patient.fromMap(doc, (doc['id'] ?? '').toString());
        setState(() {
          _patient = p;
          _patientNameController.text = p.patientName;
          _patientPhoneController.text = p.phone;
          _patientAddressController.text = p.address;
          _isLoadingPatient = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPatient = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _invoiceNumberController.dispose();
    _discountController.dispose();
    _patientNameController.dispose();
    _patientPhoneController.dispose();
    _patientAddressController.dispose();
    for (final item in _editableServices) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_editableServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one service.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      
      // 1. Update Patient details in Firestore if loaded
      if (_patient != null) {
        final updatedPatient = Patient(
          patientId: _patient!.patientId,
          mrNumber: _patient!.mrNumber,
          patientName: _patientNameController.text.trim(),
          cnic: _patient!.cnic,
          phone: _patientPhoneController.text.trim(),
          address: _patientAddressController.text.trim(),
          diagnosis: _patient!.diagnosis,
          doctor: _patient!.doctor,
          nurse: _patient!.nurse,
          caretaker: _patient!.caretaker,
          selectedServices: _patient!.selectedServices,
          monthlyServiceCost: _patient!.monthlyServiceCost,
          patientAmount: _patient!.patientAmount,
          staffPayment: _patient!.staffPayment,
          profit: _patient!.profit,
          days: _patient!.days,
          assignedStaffId: _patient!.assignedStaffId,
          organizationId: _patient!.organizationId,
          createdBy: _patient!.createdBy,
          createdAt: _patient!.createdAt,
          updatedBy: _patient!.updatedBy,
          updatedAt: DateTime.now(),
          isDeleted: _patient!.isDeleted,
          deletedAt: _patient!.deletedAt,
          deletedBy: _patient!.deletedBy,
        );
        await Supabase.instance.client
            .from('patients')
            .update(updatedPatient.toSupabaseMap())
            .eq('id', _patient!.patientId);
      }

      // 2. Build updated InvoiceItems and calculate totals
      final updatedItems = _editableServices.map((e) {
        return InvoiceItem(
          serviceName: e.nameController.text.trim(),
          price: e.price,
          quantity: e.days,
        );
      }).toList();

      final newSubtotal = _subtotal;
      final newDiscount = _discount;
      final newGrandTotal = _grandTotal;

      int invoiceDays = widget.invoice.days;
      if (updatedItems.isNotEmpty) {
        invoiceDays = updatedItems.map((i) => i.quantity).reduce((a, b) => a > b ? a : b);
      }

      // 3. Update Invoice in Firestore
      final updatedInvoice = Invoice(
        invoiceId: widget.invoice.invoiceId,
        invoiceNumber: _invoiceNumberController.text.trim(),
        patientId: widget.invoice.patientId,
        staffId: widget.invoice.staffId,
        subtotal: newSubtotal,
        discount: newDiscount,
        grandTotal: newGrandTotal,
        items: updatedItems,
        organizationId: widget.invoice.organizationId,
        createdBy: widget.invoice.createdBy,
        createdAt: widget.invoice.createdAt,
        updatedBy: ref.read(authStateProvider).value?.uid ?? widget.invoice.updatedBy,
        updatedAt: DateTime.now(),
        isDeleted: widget.invoice.isDeleted,
        deletedAt: widget.invoice.deletedAt,
        deletedBy: widget.invoice.deletedBy,
        paymentStatus: _paymentStatus,
        fromDate: widget.invoice.fromDate,
        toDate: widget.invoice.toDate,
        days: invoiceDays,
        createdByName: widget.invoice.createdByName,
        createdByRole: widget.invoice.createdByRole,
        createdByUid: widget.invoice.createdByUid,
      );

      await repo.updateInvoice(updatedInvoice, previousPaymentStatus: widget.invoice.paymentStatus);

      // Invalidate providers to refresh Invoices List page, Dashboard, and Finances
      ref.invalidate(staffInvoicesProvider);
      ref.invalidate(allInvoicesProvider(false));
      ref.invalidate(allInvoicesProvider(true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Invoice ${updatedInvoice.invoiceNumber} and services updated successfully'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = AppError.map(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteInvoice() async {
    final profile = ref.read(userProfileProvider).value;
    final role = profile?['role'] ?? 'staff';
    if (role != 'admin') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final repo = ref.read(invoiceRepositoryProvider);
        await repo.deleteInvoice(widget.invoice.invoiceId);

        // Invalidate providers to refresh Invoices List page
        ref.invalidate(staffInvoicesProvider);
        ref.invalidate(allInvoicesProvider(false));
        ref.invalidate(allInvoicesProvider(true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted successfully')),
          );
          Navigator.of(context).pop(); // Close details modal
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPatient) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading invoice details...', style: TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    final profile = ref.watch(userProfileProvider).value;
    final role = profile?['role'] ?? 'staff';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 680;
    final dialogWidth = screenWidth > 780 ? 760.0 : (screenWidth - 24.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Top Header
            _buildHeader(role),

            // Scrollable Content Body with Scrollbar
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 14 : 20,
                    vertical: 14,
                  ),
                  child: _isEditing ? _buildEditForm(isNarrow) : _buildDetailsView(),
                ),
              ),
            ),

            // Fixed Bottom Action Bar
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView() {
    final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(widget.invoice.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Metadata ---
        _buildSectionTitle('Invoice Metadata'),
        _buildInfoRow('Grand Total', 'Rs. ${NumberFormat('#,###').format(widget.invoice.grandTotal.toInt())}'),
        _buildInfoRow('Date & Time', dateStr),
        if (widget.invoice.fromDate != null)
          _buildInfoRow('Service From', DateFormat('dd/MM/yyyy').format(widget.invoice.fromDate!)),
        if (widget.invoice.toDate != null)
          _buildInfoRow('Service To', DateFormat('dd/MM/yyyy').format(widget.invoice.toDate!)),
        if (widget.invoice.days > 0)
          _buildInfoRow('Service Days', '${widget.invoice.days} Days'),
        _buildInfoRow('Payment Status', widget.invoice.paymentStatus.toUpperCase(), 
          valueColor: widget.invoice.paymentStatus.trim().toLowerCase() == 'paid' ? Colors.green.shade700 : Colors.red.shade700),
        _buildInfoRow('Created By', _creatorName),
        if (_creatorRole.isNotEmpty && _creatorRole != 'N/A')
          _buildInfoRow('Role', _creatorRole.toUpperCase()),
        const SizedBox(height: 16),

        // --- Patient ---
        _buildSectionTitle('Patient Information'),
        _buildInfoRow('Patient Name', _patient?.patientName ?? 'N/A'),
        _buildInfoRow('MR Number', _patient?.mrNumber ?? 'N/A'),
        _buildInfoRow('Phone Number', _patient?.phone ?? 'N/A'),
        _buildInfoRow('Address', _patient?.address ?? 'N/A'),
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
              ...widget.invoice.items.asMap().entries.map((entry) {
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
                    'Rs. ${NumberFormat('#,###').format(widget.invoice.subtotal.toInt())}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              if (widget.invoice.discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discount', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      '- Rs. ${NumberFormat('#,###').format(widget.invoice.discount.toInt())}',
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
                    'Rs. ${NumberFormat('#,###').format(widget.invoice.grandTotal.toInt())}',
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

  Widget _buildHeader(String role) {
    final isPaid = widget.invoice.paymentStatus.trim().toLowerCase() == 'paid';
    final isPartial = widget.invoice.paymentStatus.trim().toLowerCase() == 'partial';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditing ? Icons.edit_document : Icons.receipt_long_rounded,
              color: const Color(0xFF1565C0),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _isEditing ? 'Edit Invoice Details' : 'Invoice Details',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    widget.invoice.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFDCFCE7)
                        : (isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.invoice.paymentStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? const Color(0xFF15803D)
                          : (isPartial ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isEditing && role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              tooltip: 'Delete Invoice',
              onPressed: _deleteInvoice,
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_isEditing)
            Expanded(
              child: Text(
                '${_editableServices.length} ${_editableServices.length == 1 ? 'Service' : 'Services'}  •  Total: Rs. ${formatter.format(_grandTotal.toInt())}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            )
          else
            const Spacer(),
          if (_isSaving)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (_isEditing) ...[
            OutlinedButton(
              onPressed: () {
                for (final item in _editableServices) {
                  item.dispose();
                }
                _initEditableServices();
                setState(() => _isEditing = false);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close', style: TextStyle(color: Color(0xFF475569))),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF1565C0),
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
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                if (required)
                  const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            ?trailing,
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
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section 1: Patient Information ───
          _buildSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Patient Information',
          ),
          Container(
            padding: const EdgeInsets.all(14),
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
                            controller: _patientNameController,
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
                            controller: _patientPhoneController,
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
                            controller: _invoiceNumberController,
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
                      controller: _patientNameController,
                      decoration: _buildInputDecoration(hintText: 'Enter patient full name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          label: 'Phone Number',
                          required: true,
                          child: TextFormField(
                            controller: _patientPhoneController,
                            decoration: _buildInputDecoration(hintText: '03001234567'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          label: 'Invoice Number',
                          child: TextFormField(
                            controller: _invoiceNumberController,
                            readOnly: true,
                            decoration: _buildInputDecoration(readOnly: true),
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
                    controller: _patientAddressController,
                    maxLines: 2,
                    decoration: _buildInputDecoration(hintText: 'Enter complete home address'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── Section 2: Services & Care Plan ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSectionHeader(
                    icon: Icons.medical_services_outlined,
                    title: 'Services & Care Plan',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '${_editableServices.length}/$_maxServices',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _editableServices.length < _maxServices ? _addServiceRow : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('Add Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Service Items List
          ..._editableServices.asMap().entries.map((entry) {
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
                            initialValue: _paymentStatus,
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
                              if (val != null) setState(() => _paymentStatus = val);
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
                  child: _buildFinancialSummaryCard(formatter),
                ),
              ],
            ),
          ] else ...[
            // Narrow mobile layout: Stacked Payment & Totals
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
                  initialValue: _paymentStatus,
                  decoration: _buildInputDecoration(),
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
                    if (val != null) setState(() => _paymentStatus = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFinancialSummaryCard(formatter),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceItemCard({
    required _EditableServiceItem item,
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
      padding: const EdgeInsets.all(12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      'Service #${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  if (item.isNewlyAdded) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ],
              ),
              if (_editableServices.length > 1)
                InkWell(
                  onTap: () => _removeServiceRow(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 11.5,
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
                  'Primary Service (Required)',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Service Name field with Quick Select Standard dropdown
          _buildField(
            label: 'Service Name / Care Description',
            required: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Choose standard service',
              onSelected: (selected) {
                _selectStandardServiceFor(item, selected);
              },
              itemBuilder: (context) => _standardServices.map((serviceName) {
                final price = _standardPrices[serviceName];
                final priceStr = (price != null && price > 0)
                    ? ' (Rs. ${formatter.format(price.toInt())})'
                    : '';
                return PopupMenuItem<String>(
                  value: serviceName,
                  child: Text('$serviceName$priceStr', style: const TextStyle(fontSize: 12.5)),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt_rounded, size: 13, color: Color(0xFF1565C0)),
                    SizedBox(width: 4),
                    Text(
                      'Standard List ▾',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ),
            ),
            child: TextFormField(
              controller: item.nameController,
              decoration: _buildInputDecoration(
                hintText: 'e.g. Home Nursing Care Services',
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
                const SizedBox(width: 8),
                Expanded(
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
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                  ),
                  Text(
                    'Rs. ${formatter.format(item.total.toInt())}',
                    style: const TextStyle(
                      fontSize: 13.5,
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

  Widget _buildFinancialSummaryCard(NumberFormat formatter) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Text(
                'Calculated Subtotal:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              Text(
                'Rs. ${formatter.format(_subtotal.toInt())}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            label: 'Discount Amount (PKR)',
            child: TextFormField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: _buildInputDecoration(
                hintText: '0',
                prefixText: 'Rs. ',
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                const Text(
                  'NEW GRAND TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Rs. ${formatter.format(_grandTotal.toInt())}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
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
