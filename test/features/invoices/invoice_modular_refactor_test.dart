import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/features/invoices/domain/editable_service_item.dart';
import 'package:shifa_management/features/invoices/data/invoice_repository.dart';
import 'package:shifa_management/features/invoices/utils/staff_info_resolver.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/invoices_search_bar.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/invoices_table_view.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/editable_service_card.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';

void main() {
  group('StaffInfoResolver Tests', () {
    test('formatStaffName handles empty and alphanumeric IDs safely', () {
      expect(StaffInfoResolver.formatStaffName(''), 'Staff');
      expect(StaffInfoResolver.formatStaffName('   '), 'Staff');
      // 20+ char random ID
      expect(StaffInfoResolver.formatStaffName('a1b2c3d4e5f6g7h8i9j0k1'), 'Staff');
      // Regular name
      expect(StaffInfoResolver.formatStaffName('ali khan'), 'Ali Khan');
      expect(StaffInfoResolver.formatStaffName('dr. ahmad'), 'Dr. Ahmad');
    });

    test('StaffInfoResolver resolves direct creator name and role', () async {
      final invoice = Invoice(
        invoiceId: 'inv-1',
        invoiceNumber: 'SHHC-1001',
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
        createdByName: 'Zeeshan Ali',
        createdByRole: 'Nurse',
      );

      final result = await StaffInfoResolver.resolve(invoice: invoice);
      expect(result.name, 'Zeeshan Ali');
      expect(result.role, 'Nurse');
    });

    test('StaffInfoResolver falls back to patient clinical fields when creator is generic', () async {
      final invoice = Invoice(
        invoiceId: 'inv-2',
        invoiceNumber: 'SHHC-1002',
        patientId: 'pat-2',
        staffId: 'staff-2',
        subtotal: 500,
        discount: 0,
        grandTotal: 500,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-2',
        createdAt: DateTime.now(),
        updatedBy: 'staff-2',
        updatedAt: DateTime.now(),
        isDeleted: false,
        paymentStatus: 'Unpaid',
        createdByName: 'Staff User',
      );

      final patient = Patient(
        patientId: 'pat-2',
        mrNumber: 'MR-002',
        patientName: 'John Doe',
        cnic: '12345',
        phone: '03001234567',
        address: 'Test City',
        diagnosis: 'Checkup',
        doctor: 'Dr. Tariq',
        nurse: 'Nurse Fatima',
        caretaker: '',
        selectedServices: [],
        monthlyServiceCost: 0,
        patientAmount: 0,
        staffPayment: 0,
        profit: 0,
        days: 15,
        assignedStaffId: 'staff-2',
        organizationId: 'default',
        createdBy: 'staff-2',
        createdAt: DateTime.now(),
        updatedBy: 'staff-2',
        updatedAt: DateTime.now(),
      );

      final result = await StaffInfoResolver.resolve(invoice: invoice, patient: patient);
      expect(result.name, 'Nurse Fatima');
      expect(result.role, 'Staff');
    });
  });

  group('Invoice RBAC & Access Scoping Tests', () {
    test('matchesStaffInvoice matches patient ownership correctly for staff', () {
      final invoice = Invoice(
        invoiceId: 'inv-3',
        invoiceNumber: 'SHHC-1003',
        patientId: 'patient-abc',
        staffId: 'staff-99',
        subtotal: 2000,
        discount: 0,
        grandTotal: 2000,
        items: [],
        organizationId: 'default',
        createdBy: 'user-other',
        createdAt: DateTime.now(),
        updatedBy: 'user-other',
        updatedAt: DateTime.now(),
        isDeleted: false,
        paymentStatus: 'Paid',
      );

      final staffPatients = {'patient-abc', 'patient-xyz'};
      expect(matchesStaffInvoice(invoice, staffPatients), isTrue);

      final otherStaffPatients = {'patient-def'};
      expect(matchesStaffInvoice(invoice, otherStaffPatients), isFalse);
    });

    test('matchesStaffInvoice matches direct staff assignment or creation', () {
      final invoice = Invoice(
        invoiceId: 'inv-4',
        invoiceNumber: 'SHHC-1004',
        patientId: '',
        staffId: 'staff-123',
        subtotal: 1500,
        discount: 0,
        grandTotal: 1500,
        items: [],
        organizationId: 'default',
        createdBy: 'staff-123',
        createdAt: DateTime.now(),
        updatedBy: 'staff-123',
        updatedAt: DateTime.now(),
        isDeleted: false,
        paymentStatus: 'Partial',
      );

      final emptyPatientSet = <String>{};
      final staffIds = {'staff-123'};
      expect(matchesStaffInvoice(invoice, emptyPatientSet, staffIdentifiers: staffIds), isTrue);

      final otherStaffIds = {'staff-456'};
      expect(matchesStaffInvoice(invoice, emptyPatientSet, staffIdentifiers: otherStaffIds), isFalse);
    });
  });

  group('InvoicesSearchBar Widget Tests', () {
    testWidgets('InvoicesSearchBar renders and dispatches text changes and clear', (tester) async {
      final controller = TextEditingController(text: 'SHHC');
      String changedValue = '';
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoicesSearchBar(
              controller: controller,
              query: 'SHHC',
              onChanged: (val) => changedValue = val,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('SHHC'), findsOneWidget);

      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      expect(cleared, isTrue);

      await tester.enterText(find.byType(TextField), 'Testing 123');
      expect(changedValue, 'Testing 123');
    });
  });

  group('InvoicesTableView Widget Tests', () {
    testWidgets('InvoicesTableView renders table headers and invoice rows with badges', (tester) async {
      final testInvoices = [
        Invoice(
          invoiceId: 'inv-101',
          invoiceNumber: 'SHHC-5001',
          patientId: 'pat-1',
          staffId: 'staff-1',
          subtotal: 5000,
          discount: 0,
          grandTotal: 5000,
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
          invoiceId: 'inv-102',
          invoiceNumber: 'SHHC-5002',
          patientId: 'pat-2',
          staffId: 'staff-1',
          subtotal: 3000,
          discount: 500,
          grandTotal: 2500,
          items: [],
          organizationId: 'default',
          createdBy: 'staff-1',
          createdAt: DateTime.now(),
          updatedBy: 'staff-1',
          updatedAt: DateTime.now(),
          isDeleted: false,
          paymentStatus: 'Partial',
        ),
      ];

      Invoice? tappedInvoice;
      Invoice? exportedInvoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvoicesTableView(
              invoices: testInvoices,
              onInvoiceTap: (inv) => tappedInvoice = inv,
              onExportTap: (inv) => exportedInvoice = inv,
            ),
          ),
        ),
      );

      expect(find.text('INVOICE #'), findsOneWidget);
      expect(find.text('MR NUMBER'), findsOneWidget);
      expect(find.text('GRAND TOTAL'), findsOneWidget);
      expect(find.text('VIEW'), findsOneWidget);

      expect(find.text('SHHC-5001'), findsOneWidget);
      expect(find.text('SHHC-5002'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('PARTIAL'), findsOneWidget);

      await tester.tap(find.text('SHHC-5001'));
      expect(tappedInvoice?.invoiceNumber, 'SHHC-5001');

      final viewIcons = find.byIcon(Icons.visibility_outlined);
      expect(viewIcons, findsNWidgets(2));
      await tester.tap(viewIcons.first);
      expect(exportedInvoice?.invoiceNumber, 'SHHC-5001');
    });
  });

  group('EditableServiceCard Widget Tests', () {
    testWidgets('EditableServiceCard renders inputs and computes line totals', (tester) async {
      final item = EditableServiceItem(
        serviceName: 'Special Nursing Care',
        price: 3000,
        days: 5,
        onChanged: () {},
      );

      bool removed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditableServiceCard(
                item: item,
                index: 0,
                totalCount: 2,
                isNarrow: false,
                formatter: NumberFormat('#,###'),
                onRemove: () => removed = true,
                onSelectStandardService: (_, _) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Service #1'), findsOneWidget);
      expect(find.text('Special Nursing Care'), findsOneWidget);
      expect(find.text('Rs. 15,000'), findsOneWidget);

      final removeButton = find.text('Remove');
      expect(removeButton, findsOneWidget);
      await tester.tap(removeButton);
      expect(removed, isTrue);
    });
  });
}
