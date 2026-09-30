import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/features/invoices/data/invoice_repository.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/invoices_table_view.dart';

void main() {
  group('Admin vs Staff RBAC Scoping & Data Isolation Tests', () {
    late Invoice invStaffAPatient;
    late Invoice invStaffAWalkIn;
    late Invoice invStaffBPatient;
    late Invoice invAdminForStaffB;
    late Invoice invAdminGeneral;
    late Invoice invDeleted;
    late List<Invoice> allSystemInvoices;

    setUp(() {
      final now = DateTime.now();

      invStaffAPatient = Invoice(
        invoiceId: 'inv-1',
        invoiceNumber: 'SHHC-5001',
        patientId: 'patient-A1',
        staffId: 'staff-A',
        subtotal: 3000,
        discount: 0,
        grandTotal: 3000,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-A',
        createdByUid: 'staff-A',
        createdByName: 'Staff Alice',
        createdByRole: 'Nurse',
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedBy: 'staff-A',
        updatedAt: now.subtract(const Duration(hours: 5)),
        isDeleted: false,
        paymentStatus: 'Paid',
      );

      invStaffAWalkIn = Invoice(
        invoiceId: 'inv-2',
        invoiceNumber: 'SHHC-5002',
        patientId: '',
        staffId: 'staff-A',
        subtotal: 1500,
        discount: 0,
        grandTotal: 1500,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-A',
        createdByUid: 'staff-A',
        createdByName: 'Staff Alice',
        createdByRole: 'Nurse',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedBy: 'staff-A',
        updatedAt: now.subtract(const Duration(hours: 4)),
        isDeleted: false,
        paymentStatus: 'Unpaid',
      );

      invStaffBPatient = Invoice(
        invoiceId: 'inv-3',
        invoiceNumber: 'SHHC-5003',
        patientId: 'patient-B1',
        staffId: 'staff-B',
        subtotal: 4000,
        discount: 500,
        grandTotal: 3500,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-B',
        createdByUid: 'staff-B',
        createdByName: 'Staff Bob',
        createdByRole: 'Physiotherapist',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedBy: 'staff-B',
        updatedAt: now.subtract(const Duration(hours: 3)),
        isDeleted: false,
        paymentStatus: 'Paid',
      );

      invAdminForStaffB = Invoice(
        invoiceId: 'inv-4',
        invoiceNumber: 'SHHC-5004',
        patientId: 'patient-B1',
        staffId: 'admin-super',
        subtotal: 2000,
        discount: 0,
        grandTotal: 2000,
        items: [],
        organizationId: 'default',
        createdBy: 'admin-super',
        createdByUid: 'admin-super',
        createdByName: 'Admin User',
        createdByRole: 'admin',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedBy: 'admin-super',
        updatedAt: now.subtract(const Duration(hours: 2)),
        isDeleted: false,
        paymentStatus: 'Partial',
      );

      invAdminGeneral = Invoice(
        invoiceId: 'inv-5',
        invoiceNumber: 'SHHC-5005',
        patientId: 'patient-general',
        staffId: 'admin-super',
        subtotal: 5000,
        discount: 1000,
        grandTotal: 4000,
        items: [],
        organizationId: 'default',
        createdBy: 'admin-super',
        createdByUid: 'admin-super',
        createdByName: 'Admin User',
        createdByRole: 'admin',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedBy: 'admin-super',
        updatedAt: now.subtract(const Duration(hours: 1)),
        isDeleted: false,
        paymentStatus: 'Unpaid',
      );

      invDeleted = Invoice(
        invoiceId: 'inv-6',
        invoiceNumber: 'SHHC-5006',
        patientId: 'patient-A1',
        staffId: 'staff-A',
        subtotal: 1000,
        discount: 0,
        grandTotal: 1000,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-A',
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedBy: 'staff-A',
        updatedAt: now.subtract(const Duration(hours: 6)),
        isDeleted: true,
        paymentStatus: 'Unpaid',
      );

      allSystemInvoices = [
        invStaffAPatient,
        invStaffAWalkIn,
        invStaffBPatient,
        invAdminForStaffB,
        invAdminGeneral,
        invDeleted,
      ];
    });

    test('Admin Panel sees ALL active invoices across every staff and general patients', () {
      final adminVisibleInvoices = allSystemInvoices.where((inv) => !inv.isDeleted).toList();

      expect(adminVisibleInvoices.length, 5);
      expect(adminVisibleInvoices.map((i) => i.invoiceId).toSet(), {
        'inv-1',
        'inv-2',
        'inv-3',
        'inv-4',
        'inv-5',
      });
    });

    test('Staff Alice ONLY sees her own invoices and her assigned patient invoices', () {
      final alicePatientIds = {'patient-A1'};
      final aliceIdentifiers = {'staff-a', 'staff alice', 'staff-A', 'Staff Alice'};

      final aliceInvoices = allSystemInvoices.where((inv) {
        if (inv.isDeleted || inv.isDiscontinued) return false;
        return matchesStaffInvoice(inv, alicePatientIds, staffIdentifiers: aliceIdentifiers);
      }).toList();

      // Alice must see inv-1 and inv-2
      expect(aliceInvoices.length, 2);
      expect(aliceInvoices.map((i) => i.invoiceId).toSet(), {'inv-1', 'inv-2'});

      // Alice MUST NOT see Bob's or Admin's invoices
      expect(aliceInvoices.any((i) => i.invoiceId == 'inv-3'), isFalse);
      expect(aliceInvoices.any((i) => i.invoiceId == 'inv-4'), isFalse);
      expect(aliceInvoices.any((i) => i.invoiceId == 'inv-5'), isFalse);
    });

    test('Staff Bob ONLY sees his own invoices and invoices for his assigned patients', () {
      final bobPatientIds = {'patient-B1'};
      final bobIdentifiers = {'staff-b', 'staff bob', 'staff-B', 'Staff Bob'};

      final bobInvoices = allSystemInvoices.where((inv) {
        if (inv.isDeleted || inv.isDiscontinued) return false;
        return matchesStaffInvoice(inv, bobPatientIds, staffIdentifiers: bobIdentifiers);
      }).toList();

      // Bob sees inv-3 (created by Bob) and inv-4 (created by admin for Bob's patient)
      expect(bobInvoices.length, 2);
      expect(bobInvoices.map((i) => i.invoiceId).toSet(), {'inv-3', 'inv-4'});

      // Bob MUST NOT see Alice's invoices or general unassigned invoices
      expect(bobInvoices.any((i) => i.invoiceId == 'inv-1'), isFalse);
      expect(bobInvoices.any((i) => i.invoiceId == 'inv-2'), isFalse);
      expect(bobInvoices.any((i) => i.invoiceId == 'inv-5'), isFalse);
    });
  });

  group('Invoice Data Deduplication Tests', () {
    test('Deduplication filter removes duplicate invoice entries by ID or invoice number', () {
      final duplicateList = [
        Invoice(
          invoiceId: 'inv-dup-1',
          invoiceNumber: 'SHHC-9001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 1000,
          discount: 0,
          grandTotal: 1000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
        Invoice(
          invoiceId: 'inv-dup-1', // Exact same ID
          invoiceNumber: 'SHHC-9001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 1000,
          discount: 0,
          grandTotal: 1000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
        Invoice(
          invoiceId: 'inv-dup-2',
          invoiceNumber: 'SHHC-9002',
          patientId: 'pat-2',
          staffId: 'staff-1',
          subtotal: 2000,
          discount: 0,
          grandTotal: 2000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
      ];

      final seenIds = <String>{};
      final unique = <Invoice>[];
      for (final inv in duplicateList) {
        final key = inv.invoiceId.isNotEmpty ? inv.invoiceId : inv.invoiceNumber;
        if (seenIds.add(key)) {
          unique.add(inv);
        }
      }

      expect(unique.length, 2);
      expect(unique[0].invoiceId, 'inv-dup-1');
      expect(unique[1].invoiceId, 'inv-dup-2');
    });

    testWidgets('InvoicesTableView deduplicates rows before rendering to prevent visual duplication', (tester) async {
      final duplicateInvoices = [
        Invoice(
          invoiceId: 'table-inv-1',
          invoiceNumber: 'SHHC-7001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 1000,
          discount: 0,
          grandTotal: 1000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
        Invoice(
          invoiceId: 'table-inv-1', // Duplicate row
          invoiceNumber: 'SHHC-7001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 1000,
          discount: 0,
          grandTotal: 1000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
        Invoice(
          invoiceId: 'table-inv-2',
          invoiceNumber: 'SHHC-7002',
          patientId: 'pat-2',
          staffId: 'staff-1',
          subtotal: 2000,
          discount: 0,
          grandTotal: 2000,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Paid',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoicesTableView(
              invoices: duplicateInvoices,
              onInvoiceTap: (_) {},
              onExportTap: (_) {},
            ),
          ),
        ),
      );

      // Verify SHHC-7001 appears exactly once, NOT twice
      expect(find.text('SHHC-7001'), findsOneWidget);
      expect(find.text('SHHC-7002'), findsOneWidget);
    });

    test('toSupabaseMap never includes updated_by (prevents PGRST204 error)', () {
      final invoice = Invoice(
        invoiceId: 'inv-schema-test',
        invoiceNumber: 'SHHC-8001',
        patientId: 'pat-1',
        staffId: 'staff-1',
        subtotal: 1000,
        discount: 0,
        grandTotal: 1000,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-1',
        createdAt: DateTime.now(),
        updatedBy: 'staff-1',
        updatedAt: DateTime.now(),
        isDeleted: false,
        paymentStatus: 'Paid',
      );

      final map = invoice.toSupabaseMap();

      expect(map.containsKey('updated_by'), isFalse,
          reason: 'updated_by must not be sent to Supabase because the column does not exist in the invoices schema');
      expect(map['invoice_number'], 'SHHC-8001');
      expect(map['payment_status'], 'Paid');
      expect(map['is_deleted'], false);
    });
  });
}
