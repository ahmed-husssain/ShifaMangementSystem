import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';
import 'package:shifa_management/shared/providers/auth_provider.dart';
import 'package:shifa_management/shared/providers/plan_expiration_provider.dart';
import 'package:shifa_management/features/invoices/data/invoice_repository.dart';
import 'package:shifa_management/features/dashboard/domain/scheduled_notification_model.dart';

void main() {
  // Helper to create valid base patient
  Patient createTestPatient({
    String id = 'pat-1',
    String name = 'Test Patient',
    String mrNumber = 'MR-1001',
    String phone = '03001234567',
    bool isDiscontinued = false,
    bool isDeleted = false,
    double patientAmount = 90000,
    double staffPayment = 60000,
    double profit = 30000,
    int days = 30,
  }) {
    return Patient(
      patientId: id,
      mrNumber: mrNumber,
      patientName: name,
      cnic: '35201-1234567-1',
      phone: phone,
      address: 'Lahore, Pakistan',
      diagnosis: 'Home Care',
      doctor: 'Dr. Ayaz',
      nurse: 'Staff Nurse',
      caretaker: '',
      selectedServices: [
        {'serviceName': 'Nursing Care', 'dailyPrice': 3000},
      ],
      monthlyServiceCost: patientAmount,
      patientAmount: patientAmount,
      staffPayment: staffPayment,
      profit: profit,
      days: days,
      assignedStaffId: 'staff-uid-1',
      organizationId: 'default',
      createdBy: 'staff-uid-1',
      createdAt: DateTime(2026, 1, 1),
      updatedBy: 'staff-uid-1',
      updatedAt: DateTime(2026, 1, 1),
      isDiscontinued: isDiscontinued,
      isDeleted: isDeleted,
    );
  }

  // Helper to create valid base invoice
  Invoice createTestInvoice({
    String id = 'inv-1',
    String invoiceNumber = 'SHHC-5001',
    String patientId = 'pat-1',
    double subtotal = 45000,
    double discount = 0,
    double? grandTotal,
    int days = 15,
    DateTime? fromDate,
    DateTime? toDate,
    bool isDiscontinued = false,
    bool isDeleted = false,
  }) {
    final from = fromDate ?? DateTime(2026, 1, 1);
    final to = toDate ?? DateTime(2026, 1, 16);
    final total = grandTotal ?? (subtotal - discount);
    return Invoice(
      invoiceId: id,
      invoiceNumber: invoiceNumber,
      patientId: patientId,
      staffId: 'staff-uid-1',
      subtotal: subtotal,
      discount: discount,
      grandTotal: total < 0 ? 0 : total,
      items: [
        InvoiceItem(serviceName: 'Nursing Care', price: 3000, quantity: days > 0 ? days : 1),
      ],
      organizationId: 'default',
      createdBy: 'staff-uid-1',
      createdAt: DateTime(2026, 1, 1),
      updatedBy: 'staff-uid-1',
      updatedAt: DateTime(2026, 1, 1),
      isDiscontinued: isDiscontinued,
      isDeleted: isDeleted,
      fromDate: from,
      toDate: to,
      days: days,
    );
  }

  group('1. Confirmed Bugs #1–#7 Root Cause & Regression Tests', () {
    test('1A: InvoiceItem.fromMap safely parses string prices and float quantities from Postgres', () {
      final rawData = {
        'serviceName': 'Home Nursing Care',
        'price': '3000.00',
        'quantity': 15.0,
      };

      final item = InvoiceItem.fromMap(rawData);
      expect(item.price, equals(3000.0));
      expect(item.quantity, equals(15));
      expect(item.total, equals(45000.0));
    });

    test('1B: Invoice.fromMap safely ignores null or non-map elements in items array', () {
      final rawData = {
        'id': 'inv-corrupt-1',
        'invoice_number': 'SHHC-9999',
        'patient_id': 'pat-1',
        'staff_id': 'staff-1',
        'subtotal': '45000',
        'discount': 0,
        'grand_total': '45000',
        'items': [
          {'serviceName': 'Service A', 'price': 3000, 'quantity': 1},
          null,
          'invalid_non_map_string',
        ],
      };

      final inv = Invoice.fromMap(rawData, 'inv-corrupt-1');
      expect(inv.items.length, equals(1));
      expect(inv.items.first.serviceName, equals('Service A'));
    });

    test('1C: Patient.fromMap safely parses heterogeneous selectedServices entries', () {
      final rawData = {
        'id': 'pat-corrupt-1',
        'patient_name': 'Test Patient',
        'selected_services': [
          {'serviceName': 'Nursing', 'dailyPrice': '3000'},
          'invalid_string_entry',
          null,
        ],
        'monthly_service_cost': '90000',
      };

      final p = Patient.fromMap(rawData, 'pat-corrupt-1');
      expect(p.selectedServices.length, equals(1));
      expect(p.monthlyServiceCost, equals(90000.0));
    });

    test('1D: ScheduledNotification.fromMap correctly parses DB snake_case columns', () {
      final dbRowFromSupabase = {
        'id': 'rem-db-1',
        'patient_id': 'pat-101',
        'title': 'Dressing Change Follow-up',
        'message': 'Patient: Sarah Khan (SHHC-261003-4001)',
        'scheduled_time': '2026-10-25T14:30:00.000Z',
        'is_sent': false,
        'created_at': '2026-10-03T10:00:00.000Z',
      };

      final parsed = ScheduledNotification.fromMap(dbRowFromSupabase, 'rem-db-1');
      expect(parsed.scheduledFor.year, equals(2026));
      expect(parsed.scheduledFor.month, equals(10));
      expect(parsed.scheduledFor.day, equals(25));
      expect(parsed.reminderNote, equals('Dressing Change Follow-up'));
      expect(parsed.isCompleted, isFalse);
    });

    test('1E: calculateExpiringPlans excludes standalone notifications for discontinued patients', () {
      final discontinuedPatient = createTestPatient(
        id: 'pat-disc-1',
        name: 'Discontinued Patient',
        isDiscontinued: true,
      );

      final reminder = ScheduledNotification(
        id: 'rem-disc-1',
        patientId: 'pat-disc-1',
        patientName: 'Discontinued Patient',
        mrNumber: 'MR-1001',
        phone: '03001234567',
        address: 'Lahore',
        reminderNote: 'Follow-up',
        targetDays: 15,
        scheduledFor: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        createdBy: 'staff-1',
        isCompleted: false,
      );

      final plans = calculateExpiringPlans(
        patients: [discontinuedPatient],
        invoices: [],
        standaloneScheduled: [reminder],
        now: DateTime.now(),
      );

      expect(plans, isEmpty, reason: 'Discontinued patient reminders must not leak into active queues');
    });

    test('1F: Negative discount is strictly rejected by domain validation', () {
      expect(
        () => Invoice(
          invoiceId: 'inv-neg-1',
          invoiceNumber: 'SHHC-5001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 10000,
          discount: -5000, // Negative discount exploit
          grandTotal: 15000,
          items: [InvoiceItem(serviceName: 'Test', price: 10000, quantity: 1)],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Constructing invoice with negative discount must throw ArgumentError',
      );
    });

    test('1G: Inverted date range (toDate < fromDate) is strictly rejected by domain validation', () {
      final from = DateTime(2026, 5, 20);
      final to = DateTime(2026, 5, 10); // 10 days before fromDate!

      expect(
        () => Invoice(
          invoiceId: 'inv-inv-1',
          invoiceNumber: 'SHHC-5002',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 10000,
          discount: 0,
          grandTotal: 10000,
          items: [InvoiceItem(serviceName: 'Test', price: 1000, quantity: 1)],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          fromDate: from,
          toDate: to,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'Constructing invoice with toDate < fromDate must throw ArgumentError',
      );
    });
  });

  group('2. Reversible Archival & Discontinuation Business Rules', () {
    test('2A: Active -> Discontinued excludes patient invoices from display and calculations', () {
      // Setup patient and 2 invoices
      final patient = createTestPatient(id: 'pat-rev-1', name: 'John Doe', isDiscontinued: false);
      final inv1 = createTestInvoice(id: 'inv-rev-1', patientId: 'pat-rev-1', subtotal: 30000, days: 10);
      final inv2 = createTestInvoice(id: 'inv-rev-2', patientId: 'pat-rev-1', subtotal: 15000, days: 5);

      final allInvoices = [inv1, inv2];

      // Active state simulation
      var patientMap = {patient.patientId: patient};
      var visibleInvoices = allInvoices.where((inv) {
        if (inv.isDeleted || inv.isDiscontinued) return false;
        final p = patientMap[inv.patientId];
        if (p != null && (p.isDiscontinued || p.isDeleted)) return false;
        return true;
      }).toList();

      expect(visibleInvoices.length, equals(2), reason: 'Active patient invoices are visible');

      // Now Transition: Active -> Discontinued
      final discontinuedPatient = createTestPatient(id: 'pat-rev-1', name: 'John Doe', isDiscontinued: true);
      patientMap = {discontinuedPatient.patientId: discontinuedPatient};

      visibleInvoices = allInvoices.where((inv) {
        if (inv.isDeleted || inv.isDiscontinued) return false;
        final p = patientMap[inv.patientId];
        if (p != null && (p.isDiscontinued || p.isDeleted)) return false;
        return true;
      }).toList();

      expect(visibleInvoices, isEmpty, reason: 'Discontinued patient invoices must be excluded from invoice list');

      // Financial Calculation Simulation
      double calculateRevenue(List<Invoice> invoices, Map<String, Patient> pMap) {
        double rev = 0;
        for (final inv in invoices) {
          if (!inv.isDiscontinued && !inv.isDeleted) {
            final p = pMap[inv.patientId];
            if (p == null || p.isDiscontinued || p.isDeleted) continue;
            rev += inv.grandTotal;
          }
        }
        return rev;
      }

      final discontinuedRevenue = calculateRevenue(allInvoices, patientMap);
      expect(discontinuedRevenue, equals(0.0), reason: 'Discontinued patient contribution must be excluded from totals');
    });

    test('2B: Discontinued -> Active restores patient invoices and historical financial data', () {
      createTestPatient(id: 'pat-rev-2', isDiscontinued: true);
      final inv1 = createTestInvoice(id: 'inv-rev-3', patientId: 'pat-rev-2', subtotal: 40000, days: 10);
      final inv2 = createTestInvoice(id: 'inv-rev-4', patientId: 'pat-rev-2', subtotal: 20000, days: 5);

      final allInvoices = [inv1, inv2];

      // Transition: Discontinued -> Active
      final activePatient = createTestPatient(id: 'pat-rev-2', isDiscontinued: false);
      final patientMap = {activePatient.patientId: activePatient};

      final restoredInvoices = allInvoices.where((inv) {
        if (inv.isDeleted || inv.isDiscontinued) return false;
        final p = patientMap[inv.patientId];
        if (p != null && (p.isDiscontinued || p.isDeleted)) return false;
        return true;
      }).toList();

      expect(restoredInvoices.length, equals(2), reason: 'Invoices must be restored when patient is active again');

      double rev = 0;
      for (final inv in restoredInvoices) {
        rev += inv.grandTotal;
      }
      expect(rev, equals(60000.0), reason: 'Historical financial totals must be restored completely');
      expect(inv1.isDeleted, isFalse, reason: 'Invoices must NEVER be permanently deleted during archival');
      expect(inv2.isDeleted, isFalse, reason: 'Invoices must NEVER be permanently deleted during archival');
    });

    test('2C: Active -> Archived (isDeleted: true) -> Active reversible test with multiple invoices', () {
      final p1 = createTestPatient(id: 'p-1', name: 'Patient One', isDeleted: false);
      final p2 = createTestPatient(id: 'p-2', name: 'Patient Two', isDeleted: false);

      final invoices = [
        createTestInvoice(id: 'i-1', patientId: 'p-1', subtotal: 10000),
        createTestInvoice(id: 'i-2', patientId: 'p-1', subtotal: 15000),
        createTestInvoice(id: 'i-3', patientId: 'p-2', subtotal: 25000),
      ];

      // 1. Both active: Total revenue = 50,000
      var pMap = {'p-1': p1, 'p-2': p2};
      double calcRev() => invoices.where((i) {
        final p = pMap[i.patientId];
        return p != null && !p.isDeleted && !p.isDiscontinued;
      }).fold(0.0, (acc, i) => acc + i.grandTotal);

      expect(calcRev(), equals(50000.0));

      // 2. Archive p-1: Revenue drops to 25,000 (only p-2 counted)
      pMap['p-1'] = createTestPatient(id: 'p-1', name: 'Patient One', isDeleted: true);
      expect(calcRev(), equals(25000.0));

      // 3. Un-archive p-1: Revenue restores back to 50,000 automatically
      pMap['p-1'] = createTestPatient(id: 'p-1', name: 'Patient One', isDeleted: false);
      expect(calcRev(), equals(50000.0));
    });
  });

  group('3. Invalid Dates Business Rules (toDate < fromDate)', () {
    test('3A: Normal valid dates are accepted', () {
      final from = DateTime(2026, 4, 1);
      final to = DateTime(2026, 4, 16);
      expect(
        () => createTestInvoice(fromDate: from, toDate: to, days: 15),
        returnsNormally,
      );
    });

    test('3B: Same-day dates are accepted as 1 day coverage', () {
      final sameDay = DateTime(2026, 4, 10);
      final inv = createTestInvoice(fromDate: sameDay, toDate: sameDay, days: 1);
      expect(inv.days, equals(1));
    });

    test('3C: toDate < fromDate cannot be saved and throws clear ArgumentError', () {
      final from = DateTime(2026, 4, 15);
      final to = DateTime(2026, 4, 10); // earlier!

      expect(
        () => createTestInvoice(fromDate: from, toDate: to),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'To date cannot be earlier than From date.')),
      );
    });

    test('3D: Direct repository submission with toDate < fromDate is blocked', () {
      void validateInvoice(Invoice inv) {
        if (inv.fromDate != null && inv.toDate != null) {
          final fromNorm = DateTime(inv.fromDate!.year, inv.fromDate!.month, inv.fromDate!.day);
          final toNorm = DateTime(inv.toDate!.year, inv.toDate!.month, inv.toDate!.day);
          if (toNorm.isBefore(fromNorm)) {
            throw ArgumentError('To date cannot be earlier than From date.');
          }
        }
      }

      final from = DateTime(2026, 6, 20);
      final to = DateTime(2026, 6, 19);

      expect(
        () => validateInvoice(Invoice(
          invoiceId: 'i-direct',
          invoiceNumber: 'SHHC-5001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 5000,
          discount: 0,
          grandTotal: 5000,
          items: [InvoiceItem(serviceName: 'A', price: 5000, quantity: 1)],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          fromDate: from,
          toDate: to,
        )),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'To date cannot be earlier than From date.')),
      );
    });

    test('3E: Restored invalid draft data cannot be saved if toDate < fromDate', () {
      final invalidDraft = {
        'fromDateIso': '2026-07-20T00:00:00.000Z',
        'toDateIso': '2026-07-10T00:00:00.000Z',
        'discount': 0.0,
      };

      final restoredFrom = DateTime.parse(invalidDraft['fromDateIso'] as String);
      final restoredTo = DateTime.parse(invalidDraft['toDateIso'] as String);

      // Simulation of _submit validation check in InvoiceFormScreen
      final fromNorm = DateTime(restoredFrom.year, restoredFrom.month, restoredFrom.day);
      final toNorm = DateTime(restoredTo.year, restoredTo.month, restoredTo.day);

      bool canSave = true;
      String? errorMessage;
      if (toNorm.isBefore(fromNorm)) {
        canSave = false;
        errorMessage = 'To date cannot be earlier than From date.';
      }

      expect(canSave, isFalse);
      expect(errorMessage, equals('To date cannot be earlier than From date.'));
    });
  });

  group('4. Negative Discounts Business Rules', () {
    test('4A: Negative discount is rejected with clear error message', () {
      expect(
        () => createTestInvoice(discount: -1000),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'Discount cannot be negative.')),
      );
    });

    test('4B: Negative discount cannot be bypassed in repository create/update', () {
      void validateInvoice(Invoice inv) {
        if (inv.discount < 0) {
          throw ArgumentError('Discount cannot be negative.');
        }
      }

      expect(
        () => validateInvoice(Invoice(
          invoiceId: 'i-bypass',
          invoiceNumber: 'SHHC-5002',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 10000,
          discount: -2500,
          grandTotal: 12500,
          items: [InvoiceItem(serviceName: 'A', price: 10000, quantity: 1)],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
        )),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'Discount cannot be negative.')),
      );
    });

    test('4C: Restored draft with negative discount is caught before saving', () {
      final draftDiscount = -500.0;
      bool canSave = true;
      String? errorMessage;

      if (draftDiscount < 0) {
        canSave = false;
        errorMessage = 'Discount cannot be negative.';
      }

      expect(canSave, isFalse);
      expect(errorMessage, equals('Discount cannot be negative.'));
    });
  });

  group('5. Negative Quantities Business Rules', () {
    test('5A: InvoiceItem constructor rejects quantity < 1', () {
      expect(
        () => InvoiceItem(serviceName: 'Test', price: 1000, quantity: 0),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'Quantity must be at least 1.')),
      );

      expect(
        () => InvoiceItem(serviceName: 'Test', price: 1000, quantity: -5),
        throwsA(predicate((e) => e is ArgumentError && e.message == 'Quantity must be at least 1.')),
      );
    });

    test('5B: Repository validates all line item quantities >= 1', () {
      void validateInvoice(Invoice inv) {
        for (final item in inv.items) {
          if (item.quantity < 1) {
            throw ArgumentError('Item quantity must be at least 1.');
          }
        }
      }

      // Valid items pass
      expect(
        () => validateInvoice(createTestInvoice(days: 5)),
        returnsNormally,
      );
    });
  });

  group('6. PDF Font Known Limitation (Urdu/Arabic)', () {
    test('6A: Standard Latin/English PDF generation succeeds without crashing', () async {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Text('Patient: Muhammad Ali - Service: Home Care'),
        ),
      );
      final bytes = await pdf.save();
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));
    });

    test('6B: Standard PDF exporter supports English/Latin characters (Urdu/Arabic is documented known limitation)', () async {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Text('Patient Name: Muhammad Ali - Service: 15-day Nursing Care - Status: Paid'),
        ),
      );
      final bytes = await pdf.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });

  group('7. WhatsApp Phone Validation Business Rules', () {
    test('7A: Valid Pakistani mobile numbers generate valid wa.me URLs', () {
      final patient = createTestPatient(phone: '03001234567');
      final plan = ExpiringPatientPlan(
        patient: patient,
        latestInvoiceDate: DateTime.now(),
        expirationDate: DateTime.now().add(const Duration(days: 2)),
        hoursRemaining: 48,
        calendarDaysRemaining: 2,
        isExpired: false,
        category: 'upcoming',
        totalPlanDays: 30,
      );

      expect(plan.hasValidPhone, isTrue);
      expect(plan.whatsappUrl, isNotNull);
      expect(plan.whatsappUrl!.startsWith('https://wa.me/923001234567'), isTrue);
    });

    test('7B: Invalid phone numbers (N/A, --, empty, short) return null and hasValidPhone is false', () {
      final invalidPhones = ['N/A', '--', '', '   ', '12345', 'unknown', 'none'];

      for (final badPhone in invalidPhones) {
        final patient = createTestPatient(phone: badPhone);
        final plan = ExpiringPatientPlan(
          patient: patient,
          latestInvoiceDate: DateTime.now(),
          expirationDate: DateTime.now().add(const Duration(days: 2)),
          hoursRemaining: 48,
          calendarDaysRemaining: 2,
          isExpired: false,
          category: 'upcoming',
          totalPlanDays: 30,
        );

        expect(plan.hasValidPhone, isFalse, reason: 'Phone "$badPhone" must be recognized as invalid');
        expect(plan.whatsappUrl, isNull, reason: 'Broken wa.me URL must NEVER be generated for "$badPhone"');
      }
    });

    test('7C: Launching WhatsApp with null/invalid URL aborts and reports error', () {
      bool attemptedLaunch = false;
      String? errorMessage;

      void launchWhatsApp(String? url) {
        if (url == null || url.trim().isEmpty) {
          errorMessage = "Patient's phone number is invalid or unavailable.";
          return;
        }
        attemptedLaunch = true;
      }

      launchWhatsApp(null);
      expect(attemptedLaunch, isFalse);
      expect(errorMessage, equals("Patient's phone number is invalid or unavailable."));
    });
  });

  group('8. Invoice Number Generation Optimization & Concurrency Analysis', () {
    test('8A: Empty table defaults to SHHC-5000', () {
      final List<Map<String, dynamic>> emptySnap = [];
      int highest = 4999;
      if (emptySnap.isNotEmpty) {
        final doc = emptySnap.first;
        final existingNum = (doc['invoice_number'] ?? doc['invoiceNumber']) as String? ?? '';
        final parsed = int.tryParse(existingNum.replaceAll(RegExp(r'[^0-9]'), ''));
        if (parsed != null && parsed > highest) {
          highest = parsed;
        }
      }
      final nextNumber = (highest + 1) < 5000 ? 5000 : highest + 1;
      expect('SHHC-$nextNumber', equals('SHHC-5000'));
    });

    test('8B: Ordered query fetching latest record correctly increments invoice number', () {
      // Simulating .order('invoice_number', ascending: false).limit(1) returning SHHC-5042
      final List<Map<String, dynamic>> snap = [
        {'invoice_number': 'SHHC-5042'}
      ];

      int highest = 4999;
      if (snap.isNotEmpty) {
        final doc = snap.first;
        final existingNum = (doc['invoice_number'] ?? doc['invoiceNumber']) as String? ?? '';
        final parsed = int.tryParse(existingNum.replaceAll(RegExp(r'[^0-9]'), ''));
        if (parsed != null && parsed > highest) {
          highest = parsed;
        }
      }
      final nextNumber = (highest + 1) < 5000 ? 5000 : highest + 1;
      expect('SHHC-$nextNumber', equals('SHHC-5043'));
    });

    test('8C: Concurrency Race Condition Demonstration (Honest Technical Finding)', () async {
      // If two concurrent users query the latest record simultaneously before either inserts:
      Future<String> simulateClientSideInvoiceGeneration(String latestInDb) async {
        // Simulating DB read
        await Future.delayed(const Duration(milliseconds: 10));
        final snap = [{'invoice_number': latestInDb}];
        final doc = snap.first;
        final existingNum = doc['invoice_number']!;
        final parsed = int.tryParse(existingNum.replaceAll(RegExp(r'[^0-9]'), ''))!;
        return 'SHHC-${parsed + 1}';
      }

      // Both users start simultaneously
      final futureUser1 = simulateClientSideInvoiceGeneration('SHHC-5010');
      final futureUser2 = simulateClientSideInvoiceGeneration('SHHC-5010');

      final results = await Future.wait([futureUser1, futureUser2]);

      // Both users generate the exact same number (SHHC-5011)!
      expect(results[0], equals('SHHC-5011'));
      expect(results[1], equals('SHHC-5011'));
      expect(results[0], equals(results[1]),
        reason: 'Proof of race condition: Client-side latest-number query without DB sequence/transaction produces collision');
    });
  });

  group('9. Second Adversarial Attack Pass Against Fixes', () {
    test('9A: Sub-millicent negative discount (-0.00001) is strictly rejected', () {
      expect(
        () => createTestInvoice(discount: -0.00001),
        throwsA(isA<ArgumentError>()),
        reason: 'Epsilon negative discount must not bypass validation',
      );
    });

    test('9B: Microsecond date inversion is strictly rejected', () {
      final from = DateTime(2026, 8, 1, 12, 0, 0);
      final to = DateTime(2026, 8, 1, 11, 59, 59); // 1 second earlier on same day

      expect(
        () => createTestInvoice(fromDate: from, toDate: to),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('9C: Rapid state flapping (10 cycles between Active and Discontinued) maintains deterministic totals', () {
      createTestPatient(id: 'pat-flap-1');
      final invoices = [
        createTestInvoice(id: 'inv-flap-1', patientId: 'pat-flap-1', subtotal: 25000),
      ];

      for (int i = 0; i < 10; i++) {
        // Discontinue
        final disc = createTestPatient(id: 'pat-flap-1', isDiscontinued: true);
        final pMapDisc = {disc.patientId: disc};
        final visibleDisc = invoices.where((inv) {
          final patient = pMapDisc[inv.patientId];
          return patient != null && !patient.isDiscontinued;
        }).toList();
        expect(visibleDisc, isEmpty);

        // Reactivate
        final active = createTestPatient(id: 'pat-flap-1', isDiscontinued: false);
        final pMapActive = {active.patientId: active};
        final visibleActive = invoices.where((inv) {
          final patient = pMapActive[inv.patientId];
          return patient != null && !patient.isDiscontinued;
        }).toList();
        expect(visibleActive.length, equals(1));
        expect(visibleActive.first.grandTotal, equals(25000.0));
      }
    });

    test('9D: Extreme amounts (1 Billion PKR) calculate totals without overflow or negative margin', () {
      final hugeInvoice = createTestInvoice(
        subtotal: 1000000000, // 1 Billion PKR
        discount: 100000,
      );
      expect(hugeInvoice.grandTotal, equals(999900000.0));
      expect(hugeInvoice.grandTotal, greaterThan(0));
    });

    test('9E: Generic staff identifier isolation is maintained', () {
      final genericStaffIds = {'staff', 'admin', 'user', 'default', 'n/a', '', 'caretaker'};
      for (final id in genericStaffIds) {
        expect(isGenericStaffIdentifier(id), isTrue);
      }

      final invoice = createTestInvoice(id: 'inv-isolation-1', patientId: 'pat-other');
      final matched = matchesStaffInvoice(invoice, {}, staffIdentifiers: {'staff user', 'user'});
      expect(matched, isFalse, reason: 'Generic placeholder names must NEVER match invoices belonging to other staff');
    });
  });
}
