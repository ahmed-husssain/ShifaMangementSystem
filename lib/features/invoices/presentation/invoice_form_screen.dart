import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_error.dart';
import 'package:intl/intl.dart';
import '../domain/invoice_model.dart';
import '../data/invoice_repository.dart';
import '../utils/invoice_exporter.dart';
import 'invoice_export_page.dart';
import 'pages/invoices_page.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../patients/domain/patient_model.dart';
import '../../patients/data/patient_repository.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../shared/providers/form_draft_provider.dart';
import 'widgets/components/invoice_header_section.dart';
import 'widgets/components/invoice_patient_section.dart';
import 'widgets/components/invoice_items_table.dart';
import 'widgets/components/invoice_bank_details_section.dart';
import 'widgets/components/invoice_totals_summary.dart';
import 'widgets/components/invoice_policy_notice.dart';
import 'widgets/components/invoice_action_buttons.dart';
import 'widgets/patient_picker_modal.dart';

const Map<String, double> SERVICE_PRICES = {
  "SELECT SERVICE": 0,
"Online Doctor Consultation": 0,
"Home Physiotherapy": 3000,
"Home Physiotherapy Services": 3000,
"Home Nursing Care": 3000,
"Home Nursing Care Services": 3000,
"Home Attendant Care": 2000,
"Home Attendant Service": 2000,
"Home Nurse Visit": 2000,
"Home NG Tube Insertion": 2500,
"Wound & Bedsores Care": 2000,
"Wound & Bed Sore Dressing": 2000,
"Home ICU Nurse": 3500,
  "Home ICU Nurse Setup": 3500,
  "Medical Equipment": 0,
  "Medical Equipment Rental": 0,
  "Custom Service": 0,
};

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final int defaultDays;

  const InvoiceFormScreen({
    super.key,
    this.patientId,
    this.defaultDays = 15,
  });

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final List<InvoiceItem> _items = [];
  double _discount = 0.0;
  bool _isLoading = false;
  Patient? _patient;
  String _paymentStatus = 'Unpaid';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String? _invoiceNumber;

  int _days = 15;
  final List<TextEditingController> _itemDaysControllers = [];

  final TextEditingController _mrNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  bool _isSearchingPatient = false;
  String? _searchStatusMessage;
  bool _draftRestored = false;

  @override
  void initState() {
    super.initState();
    _days = widget.defaultDays > 0 ? widget.defaultDays : 15;
    _toDate = _fromDate.add(Duration(days: _days));

    _nameController.addListener(_autoSaveDraft);
    _phoneController.addListener(_autoSaveDraft);
    _addressController.addListener(_autoSaveDraft);
    _cnicController.addListener(_autoSaveDraft);
    _mrNumberController.addListener(_autoSaveDraft);

    if (widget.patientId != null && widget.patientId!.isNotEmpty) {
      _loadPatient();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndRestoreDraft();
      });
    }
    _generateInvoiceNumber();
  }

  void _checkAndRestoreDraft() {
    if (widget.patientId != null && widget.patientId!.isNotEmpty) return;
    final draft = ref.read(invoiceFormDraftProvider);
    if (draft.hasDraft) {
      setState(() {
        if (draft.mrNumber.isNotEmpty) _mrNumberController.text = draft.mrNumber;
        if (draft.patientName.isNotEmpty) _nameController.text = draft.patientName;
        if (draft.phone.isNotEmpty) _phoneController.text = draft.phone;
        if (draft.address.isNotEmpty) _addressController.text = draft.address;
        if (draft.cnic.isNotEmpty) _cnicController.text = draft.cnic;
        _paymentStatus = draft.paymentStatus;
        _days = draft.days;
        _discount = draft.discount;
        if (draft.fromDateIso.isNotEmpty) {
          _fromDate = DateTime.tryParse(draft.fromDateIso) ?? _fromDate;
        }
        if (draft.toDateIso.isNotEmpty) {
          _toDate = DateTime.tryParse(draft.toDateIso) ?? _toDate;
        }
        if (draft.items.isNotEmpty) {
          _items.clear();
          for (final c in _itemDaysControllers) {
            c.dispose();
          }
          _itemDaysControllers.clear();
          for (final it in draft.items) {
            final parsedItem = InvoiceItem.fromMap(it);
            _items.add(parsedItem);
            _itemDaysControllers.add(TextEditingController(text: parsedItem.quantity.toString()));
          }
        }
        _draftRestored = true;
      });
    }
  }

  void _clearDraftAndReset() {
    ref.read(invoiceFormDraftProvider.notifier).clearDraft();
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _cnicController.clear();
      _mrNumberController.clear();
      _items.clear();
      for (final c in _itemDaysControllers) {
        c.dispose();
      }
      _itemDaysControllers.clear();
      _discount = 0.0;
      _paymentStatus = 'Unpaid';
      _days = widget.defaultDays > 0 ? widget.defaultDays : 15;
      _fromDate = DateTime.now();
      _toDate = _fromDate.add(Duration(days: _days));
      _patient = null;
      _draftRestored = false;
    });
    _generateInvoiceNumber();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice draft cleared.')),
    );
  }

  void _autoSaveDraft() {
    ref.read(invoiceFormDraftProvider.notifier).saveDraft(
      patientId: widget.patientId ?? _patient?.patientId,
      mrNumber: _mrNumberController.text.trim(),
      patientName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      cnic: _cnicController.text.trim(),
      paymentStatus: _paymentStatus,
      days: _days,
      discount: _discount,
      items: _items.map((i) => i.toMap()).toList(),
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  @override
  void dispose() {
    _mrNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    for (final c in _itemDaysControllers) {
      c.dispose();
    }
    _itemDaysControllers.clear();
    super.dispose();
  }

  Future<void> _generateInvoiceNumber() async {
    try {
      final snap = await Supabase.instance.client
          .from('invoices')
          .select('invoice_number');

      int highest = 4999;
      for (final doc in snap) {
        final existingNum = (doc['invoice_number'] ?? doc['invoiceNumber']) as String? ?? '';
        final parsed = int.tryParse(existingNum.replaceAll(RegExp(r'[^0-9]'), ''));
        if (parsed != null && parsed > highest) {
          highest = parsed;
        }
      }

      int nextNumber = highest + 1;
      if (nextNumber < 5000) {
        nextNumber = 5000;
      }

      setState(() {
        _invoiceNumber = 'SHHC-$nextNumber';
      });
    } catch (_) {
      setState(() {
        _invoiceNumber = 'SHHC-5000';
      });
    }
  }

  Future<void> _loadPatient() async {
    if (widget.patientId == null || widget.patientId!.isEmpty) return;
    try {
      final doc = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.patientId!)
          .maybeSingle();
      if (doc != null) {
        final p = Patient.fromMap(doc, (doc['id'] ?? '').toString());
        _populatePatientData(p, defaultDays: widget.defaultDays);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _searchPatientByMRNumber(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearchingPatient = true;
      _searchStatusMessage = null;
    });

    try {
      var snap = await Supabase.instance.client
          .from('patients')
          .select()
          .ilike('mr_number', trimmed);

      if (snap.isEmpty) {
        final docSnap = await Supabase.instance.client
            .from('patients')
            .select()
            .eq('id', trimmed)
            .maybeSingle();
        if (docSnap != null) {
          final p = Patient.fromMap(docSnap, (docSnap['id'] ?? '').toString());
          final profile = ref.read(userProfileProvider).value;
          final role = profile?['role'] ?? 'staff';
          final staffIds = ref.read(currentStaffIdentifiersProvider);

          if (role == 'staff' && !matchesStaffPatient(p, staffIds)) {
            setState(() {
              _isSearchingPatient = false;
              _searchStatusMessage = 'Access Denied: Patient belongs to another staff member.';
            });
            return;
          }

          _populatePatientData(p);
          return;
        }
      }

      if (snap.isNotEmpty) {
        final doc = snap.first;
        final p = Patient.fromMap(doc, (doc['id'] ?? '').toString());
        final profile = ref.read(userProfileProvider).value;
        final role = profile?['role'] ?? 'staff';
        final staffIds = ref.read(currentStaffIdentifiersProvider);

        if (role == 'staff' && !matchesStaffPatient(p, staffIds)) {
          setState(() {
            _isSearchingPatient = false;
            _searchStatusMessage = 'Access Denied: Patient belongs to another staff member.';
          });
          return;
        }

        _populatePatientData(p);
      } else {
        setState(() {
          _isSearchingPatient = false;
          _searchStatusMessage = 'No patient found for MR: "$trimmed". Fill details below.';
        });
      }
    } catch (e) {
      setState(() {
        _isSearchingPatient = false;
        _searchStatusMessage = 'Lookup error: $e';
      });
    }
  }

  Future<void> _selectPatientFromList() async {
    final patient = await PatientPickerModal.show(context);
    if (patient != null && mounted) {
      _populatePatientData(patient);
    }
  }

  int _calculateDaysBetween(DateTime from, DateTime to) {
    final fromDateOnly = DateTime(from.year, from.month, from.day);
    final toDateOnly = DateTime(to.year, to.month, to.day);
    final diff = toDateOnly.difference(fromDateOnly).inDays;
    return diff > 0 ? diff : 1;
  }

  void _populatePatientData(Patient p, {int defaultDays = 15}) {
    final effectiveDays = p.days > 0 ? p.days : defaultDays;
    setState(() {
      _patient = p;
      _mrNumberController.text = p.mrNumber;
      _nameController.text = p.patientName;
      _phoneController.text = p.phone;
      _addressController.text = p.address;
      _cnicController.text = p.cnic;
      _isSearchingPatient = false;

      _days = effectiveDays;
      _toDate = _fromDate.add(Duration(days: effectiveDays));

      // Automatically populate invoice items with patient's registered services
      _items.clear();
      for (final c in _itemDaysControllers) {
        c.dispose();
      }
      _itemDaysControllers.clear();

      if (p.selectedServices.isNotEmpty) {
        for (final s in p.selectedServices) {
          final sName = (s['serviceName'] ?? s['name'] ?? '').toString();
          if (sName.isNotEmpty) {
            double price = 0.0;
            if (s['dailyPrice'] != null) {
              price = (s['dailyPrice'] as num).toDouble();
            } else if (s['price'] != null) {
              price = (s['price'] as num).toDouble();
            }
            if (price <= 0 && SERVICE_PRICES.containsKey(sName)) {
              price = SERVICE_PRICES[sName]!;
            }
            _items.add(InvoiceItem(
              serviceName: sName,
              price: price,
              quantity: effectiveDays,
            ));
            _itemDaysControllers.add(TextEditingController(text: effectiveDays.toString()));
          }
        }
      }

      // If no selectedServices array exists but patientAmount is set, add fallback item
      if (_items.isEmpty && p.patientAmount > 0) {
        final dailyPrice = (p.patientAmount / effectiveDays).roundToDouble();
        _items.add(InvoiceItem(
          serviceName: 'Patient Healthcare Service',
          price: dailyPrice > 0 ? dailyPrice : p.patientAmount,
          quantity: effectiveDays,
        ));
        _itemDaysControllers.add(TextEditingController(text: effectiveDays.toString()));
      }

      // If still empty, add default blank service row
      if (_items.isEmpty) {
        _items.add(InvoiceItem(serviceName: '', price: 0, quantity: effectiveDays));
        _itemDaysControllers.add(TextEditingController(text: effectiveDays.toString()));
      }

      _searchStatusMessage = '✓ Loaded patient ${p.patientName} & calculated for $effectiveDays days (${_items.length} service(s))';
    });
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItem(serviceName: '', price: 0, quantity: _days));
      _itemDaysControllers.add(TextEditingController(text: _days.toString()));
    });
    _autoSaveDraft();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (index < _itemDaysControllers.length) {
        _itemDaysControllers[index].dispose();
        _itemDaysControllers.removeAt(index);
      }
    });
    _autoSaveDraft();
  }

  void _updateItem(int index, {String? name, double? price, int? qty}) {
    setState(() {
      _items[index] = InvoiceItem(
        serviceName: name ?? _items[index].serviceName,
        price: price ?? _items[index].price,
        quantity: qty ?? _items[index].quantity,
      );
      if (qty != null && index < _itemDaysControllers.length) {
        if (_itemDaysControllers[index].text != qty.toString()) {
          _itemDaysControllers[index].text = qty.toString();
        }
      }
    });
    _autoSaveDraft();
  }

  double get _subtotal => _items.fold(0.0, (acc, item) => acc + item.total);
  double get _grandTotal => _subtotal - _discount;

  Future<void> _submit(String format) async {
    if (_isLoading) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final mrNum = _mrNumberController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (mrNum.isEmpty && name.isEmpty && _patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an MR Number or Patient Name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final user = ref.read(authStateProvider).value;

      if (user == null) throw Exception("User not logged in");

      // Auto-create or update Patient in Supabase
      if (_patient == null) {
        final patientId = DateTime.now().millisecondsSinceEpoch.toString();
        final newPatient = Patient(
          patientId: patientId,
          mrNumber: mrNum.isEmpty
              ? 'SHHC-${DateFormat('yyMMdd').format(DateTime.now())}-${(1000 + DateTime.now().millisecond)}'
              : mrNum,
          patientName: name.isEmpty ? 'Patient' : name,
          cnic: _cnicController.text.trim(),
          phone: phone,
          address: address,
          diagnosis: '',
          doctor: '',
          nurse: '',
          caretaker: '',
          selectedServices: [],
          monthlyServiceCost: 0,
          patientAmount: 0,
          staffPayment: 0,
          profit: 0,
          days: 0,
          assignedStaffId: user.id,
          organizationId: 'default',
          createdBy: user.id,
          createdAt: DateTime.now(),
          updatedBy: user.id,
          updatedAt: DateTime.now(),
          isDeleted: false,
        );
        final pMap = newPatient.toSupabaseMap();
        pMap['id'] = patientId;
        await Supabase.instance.client.from('patients').insert(pMap);
        _patient = newPatient;
      } else {
        // Update patient info if edited
        _patient = Patient(
          patientId: _patient!.patientId,
          mrNumber: mrNum.isNotEmpty ? mrNum : _patient!.mrNumber,
          patientName: name.isNotEmpty ? name : _patient!.patientName,
          cnic: _cnicController.text.trim().isNotEmpty ? _cnicController.text.trim() : _patient!.cnic,
          phone: phone.isNotEmpty ? phone : _patient!.phone,
          address: address.isNotEmpty ? address : _patient!.address,
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
          updatedBy: user.uid,
          updatedAt: DateTime.now(),
          isDeleted: _patient!.isDeleted,
        );
      }

      final profile = ref.read(userProfileProvider).value;
      final userName = profile?['name'] ?? profile?['username'] ?? 'Staff User';
      final userRole = profile?['role'] ?? 'staff';

      int invoiceDays = 0;
      if (_items.isNotEmpty && _items.first.quantity > 0) {
        invoiceDays = _items.first.quantity;
      } else {
        final dateDiff = _toDate.difference(_fromDate).inDays;
        if (dateDiff > 0) {
          invoiceDays = dateDiff;
        } else if (_patient != null && _patient!.days > 0) {
          invoiceDays = _patient!.days;
        } else {
          invoiceDays = widget.defaultDays;
        }
      }

      final invoice = Invoice(
        invoiceId: '',
        invoiceNumber: _invoiceNumber ?? 'N/A',
        patientId: _patient!.patientId,
        staffId: user.uid,
        subtotal: _subtotal,
        discount: _discount,
        grandTotal: _grandTotal,
        items: _items,
        organizationId: 'default',
        createdBy: user.uid,
        createdByUid: user.uid,
        createdByName: userName,
        createdByRole: userRole,
        createdAt: DateTime.now(),
        updatedBy: user.uid,
        updatedAt: DateTime.now(),
        isDeleted: false,
        paymentStatus: _paymentStatus,
        fromDate: _fromDate,
        toDate: _toDate,
        days: invoiceDays,
      );

      final newDocId = await repo.createInvoice(invoice, userName: userName);
      ref.read(invoiceFormDraftProvider.notifier).clearDraft();
      ref.invalidate(allInvoicesProvider(false));
      ref.invalidate(allInvoicesProvider(true));
      ref.invalidate(staffInvoicesProvider);
      ref.invalidate(staffMetricsProvider);

      final savedInvoice = Invoice(
        invoiceId: newDocId,
        invoiceNumber: _invoiceNumber ?? (invoice.invoiceNumber != 'N/A' ? invoice.invoiceNumber : 'SHHC-5000'),
        patientId: _patient!.patientId,
        staffId: user.uid,
        subtotal: _subtotal,
        discount: _discount,
        grandTotal: _grandTotal,
        items: _items,
        organizationId: 'default',
        createdBy: user.uid,
        createdByUid: user.uid,
        createdByName: userName,
        createdByRole: userRole,
        createdAt: invoice.createdAt,
        updatedBy: user.uid,
        updatedAt: invoice.updatedAt,
        isDeleted: false,
        paymentStatus: _paymentStatus,
        fromDate: _fromDate,
        toDate: _toDate,
        days: invoiceDays,
      );

      if (mounted) {
        // Highlight the newly created invoice on the Invoices page
        ref.read(recentInvoiceHighlightProvider.notifier).setHighlight(newDocId);

        // Perform export and transition smoothly to InvoiceExportPage
        await _exportAndNavigate(savedInvoice, format);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = AppError.map(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAndNavigate(Invoice savedInvoice, String format) async {
    final cleanInvoiceNum = (savedInvoice.invoiceNumber.isNotEmpty && savedInvoice.invoiceNumber != 'N/A')
        ? savedInvoice.invoiceNumber
        : (savedInvoice.invoiceId.length > 8 ? savedInvoice.invoiceId.substring(0, 8) : savedInvoice.invoiceId);
    final fileName = 'invoice_$cleanInvoiceNum';

    String? successMessage;
    String? errorMessage;

    if (format.toUpperCase() == 'PRINT') {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => InvoiceExportPage(
              invoice: savedInvoice,
              patient: _patient,
            ),
          ),
        );
      }
      return;
    }

    try {
      Uint8List bytes;
      String extension;

      if (format.toUpperCase() == 'PDF') {
        bytes = await InvoiceExporter.generatePdf(
          savedInvoice,
          patient: _patient,
          invoiceNumber: cleanInvoiceNum,
        );
        extension = 'pdf';
      } else if (format.toUpperCase() == 'PNG') {
        bytes = await InvoiceExporter.generateImage(
          savedInvoice,
          patient: _patient,
          invoiceNumber: cleanInvoiceNum,
          isPng: true,
        );
        extension = 'png';
      } else if (format.toUpperCase() == 'JPG' || format.toUpperCase() == 'JPEG') {
        bytes = await InvoiceExporter.generateImage(
          savedInvoice,
          patient: _patient,
          invoiceNumber: cleanInvoiceNum,
          isPng: false,
        );
        extension = 'jpg';
      } else {
        bytes = await InvoiceExporter.generatePdf(
          savedInvoice,
          patient: _patient,
          invoiceNumber: cleanInvoiceNum,
        );
        extension = 'pdf';
      }

      final fullFileName = '$fileName.$extension';

      final result = await InvoiceExporter.saveInvoiceToDevice(
        bytes: bytes,
        fullFileName: fullFileName,
        format: extension,
      );

      if (result.success) {
        successMessage = result.message;
      } else {
        errorMessage = result.message;
      }
    } catch (e) {
      errorMessage = 'Export failed: $e';
    }

    if (mounted) {
      // Transition smoothly from creation form to the InvoiceExportPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceExportPage(
            invoice: savedInvoice,
            patient: _patient,
          ),
        ),
      );

      // Display the feedback SnackBar on the preview screen
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate.add(Duration(days: _days > 0 ? _days : 1));
          }
        } else {
          _toDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _fromDate = _toDate;
          }
        }

        final calculatedDays = _calculateDaysBetween(_fromDate, _toDate);
        _days = calculatedDays;

        for (int i = 0; i < _items.length; i++) {
          _items[i] = InvoiceItem(
            serviceName: _items[i].serviceName,
            price: _items[i].price,
            quantity: calculatedDays,
          );
        }
        for (final c in _itemDaysControllers) {
          c.text = calculatedDays.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Generate Invoice'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_draftRestored) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 18, color: Color(0xFFB45309)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Unsaved invoice draft restored from previous session.',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearDraftAndReset,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Clear Draft', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ─── Invoice Header Card ───
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        InvoiceHeaderSection(
                          invoiceNumber: _invoiceNumber ?? '...',
                          fromDate: _fromDate,
                          toDate: _toDate,
                          paymentStatus: _paymentStatus,
                          onPickDate: _pickDate,
                          onStatusChanged: (status) => setState(() => _paymentStatus = status),
                        ),
                        const SizedBox(height: 20),
                        InvoicePatientSection(
                          mrNumberController: _mrNumberController,
                          nameController: _nameController,
                          phoneController: _phoneController,
                          addressController: _addressController,
                          cnicController: _cnicController,
                          isSearchingPatient: _isSearchingPatient,
                          searchStatusMessage: _searchStatusMessage,
                          onSelectPatientFromDatabase: _selectPatientFromList,
                          onSearchMRNumber: _searchPatientByMRNumber,
                        ),
                        const SizedBox(height: 24),
                        InvoiceItemsTable(
                          items: _items,
                          daysControllers: _itemDaysControllers,
                          onAddItem: _addItem,
                          onRemoveItem: _removeItem,
                          onUpdateItem: _updateItem,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            const InvoiceBankDetailsSection(),
                            InvoiceTotalsSummary(
                              subtotal: _subtotal,
                              discount: _discount,
                              grandTotal: _grandTotal,
                              paymentStatus: _paymentStatus,
                              onDiscountChanged: (val) => setState(() => _discount = val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const InvoicePolicyNotice(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InvoiceActionButtons(
                    onPrint: () => _submit('PRINT'),
                    onPdf: () => _submit('PDF'),
                    onPng: () => _submit('PNG'),
                    onJpg: () => _submit('JPG'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
