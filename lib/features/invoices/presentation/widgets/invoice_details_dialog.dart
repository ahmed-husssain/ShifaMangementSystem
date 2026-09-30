import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_error.dart';
import '../../domain/invoice_model.dart';
import '../../domain/editable_service_item.dart';
import '../../data/invoice_repository.dart';
import '../../../patients/domain/patient_model.dart';
import '../../../../shared/providers/auth_provider.dart';
import 'invoice_details_view_content.dart';
import 'invoice_details_edit_content.dart';
import '../../utils/staff_info_resolver.dart';

class InvoiceDetailsDialog extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  @override
  ConsumerState<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends ConsumerState<InvoiceDetailsDialog> {
    static const int _maxServices = 10;

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

  late List<EditableServiceItem> _editableServices;

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
      return EditableServiceItem(
        serviceName: item.serviceName,
        price: item.price,
        days: item.quantity > 0 ? item.quantity : (widget.invoice.days > 0 ? widget.invoice.days : 1),
        onChanged: () => setState(() {}),
      );
    }).toList();

    if (_editableServices.isEmpty) {
      _editableServices.add(EditableServiceItem(
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
      _editableServices.add(EditableServiceItem(
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

  Future<void> _loadCreatorInfo() async {
    final info = await StaffInfoResolver.resolve(
      invoice: widget.invoice,
      patient: _patient,
    );
    if (mounted) {
      setState(() {
        _creatorName = info.name;
        _creatorRole = info.role;
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
    if (_isSaving) return;
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
    final dialogWidth = screenWidth > 780 ? 760.0 : (screenWidth - (isNarrow ? 16.0 : 24.0));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 16,
        vertical: isNarrow ? 12 : 24,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.94,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Top Header
            _buildHeader(role, isNarrow),

            // Scrollable Content Body with Scrollbar
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 10 : 20,
                    vertical: isNarrow ? 10 : 14,
                  ),
                  child: _isEditing
                      ? InvoiceDetailsEditContent(
                          formKey: _formKey,
                          invoiceNumberController: _invoiceNumberController,
                          patientNameController: _patientNameController,
                          patientPhoneController: _patientPhoneController,
                          patientAddressController: _patientAddressController,
                          discountController: _discountController,
                          paymentStatus: _paymentStatus,
                          onPaymentStatusChanged: (status) => setState(() => _paymentStatus = status),
                          editableServices: _editableServices,
                          onAddService: _addServiceRow,
                          onRemoveService: _removeServiceRow,
                          subtotal: _subtotal,
                          grandTotal: _grandTotal,
                          isNarrow: isNarrow,
                          onStateChanged: () => setState(() {}),
                        )
                      : InvoiceDetailsViewContent(
                          invoice: widget.invoice,
                          patient: _patient,
                          creatorName: _creatorName,
                          creatorRole: _creatorRole,
                        ),
                ),
              ),
            ),

            // Fixed Bottom Action Bar
            _buildFooter(isNarrow),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String role, bool isNarrow) {
    final isPaid = widget.invoice.paymentStatus.trim().toLowerCase() == 'paid';
    final isPartial = widget.invoice.paymentStatus.trim().toLowerCase() == 'partial';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 18,
        vertical: isNarrow ? 10 : 14,
      ),
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
              size: isNarrow ? 18 : 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  _isEditing ? 'Edit Invoice' : 'Invoice Details',
                  style: TextStyle(
                    fontSize: isNarrow ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    widget.invoice.invoiceNumber,
                    style: TextStyle(
                      fontSize: isNarrow ? 10.5 : 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFDCFCE7)
                        : (isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.invoice.paymentStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: isNarrow ? 10 : 10.5,
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
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isNarrow) {
    final formatter = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 18,
        vertical: isNarrow ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_isEditing)
            Expanded(
              child: Text(
                isNarrow
                    ? '${_editableServices.length} ${_editableServices.length == 1 ? 'Svc' : 'Svcs'} • Rs. ${formatter.format(_grandTotal.toInt())}'
                    : '${_editableServices.length} ${_editableServices.length == 1 ? 'Service' : 'Services'}  •  Total: Rs. ${formatter.format(_grandTotal.toInt())}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isNarrow ? 11.5 : 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 16,
                  vertical: isNarrow ? 8 : 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                  fontSize: isNarrow ? 12 : 13,
                ),
              ),
            ),
            SizedBox(width: isNarrow ? 6 : 10),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: Icon(Icons.check_rounded, size: isNarrow ? 15 : 16),
              label: Text(
                isNarrow ? 'Save' : 'Save Changes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isNarrow ? 12 : 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 18,
                  vertical: isNarrow ? 8 : 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 16,
                  vertical: isNarrow ? 8 : 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: isNarrow ? 12 : 13,
                ),
              ),
            ),
            SizedBox(width: isNarrow ? 6 : 10),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: Icon(Icons.edit_rounded, size: isNarrow ? 15 : 16),
              label: Text(
                isNarrow ? 'Edit' : 'Edit Invoice',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isNarrow ? 12 : 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 12 : 18,
                  vertical: isNarrow ? 8 : 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  }
