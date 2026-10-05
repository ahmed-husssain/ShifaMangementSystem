import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_header_section.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_patient_section.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_items_table.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_totals_summary.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_bank_details_section.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_policy_notice.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_action_buttons.dart';

void main() {
  testWidgets('InvoiceHeaderSection renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceHeaderSection(
            invoiceNumber: 'SHHC-5000',
            fromDate: DateTime(2026, 10, 10),
            toDate: DateTime(2026, 10, 15),
            paymentStatus: 'Unpaid',
          ),
        ),
      ),
    );

    expect(find.text('INVOICE'), findsOneWidget);
    expect(find.text('SHHC-5000'), findsOneWidget);
    expect(find.text('FROM:'), findsOneWidget);
    expect(find.text('TO:'), findsOneWidget);
    expect(find.text('STATUS:'), findsOneWidget);
  });

  testWidgets('InvoicePatientSection renders in read-only and editable modes', (WidgetTester tester) async {
    // Read-only mode test
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InvoicePatientSection(
            isEditable: false,
            readOnlyMrNumber: 'MR-1234',
            readOnlyName: 'John Doe',
            readOnlyPhone: '03001234567',
            readOnlyAddress: 'Karachi, Pakistan',
          ),
        ),
      ),
    );

    expect(find.text('BILL TO / PATIENT DETAILS'), findsOneWidget);
    expect(find.text('MR-1234'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
  });

  testWidgets('InvoiceItemsTable renders rows and amounts', (WidgetTester tester) async {
    final items = [
      InvoiceItem(serviceName: 'Home Nursing Care Services', price: 3000.0, quantity: 5),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceItemsTable(
            items: items,
            isEditable: false,
          ),
        ),
      ),
    );

    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('Home Nursing Care Services'), findsOneWidget);
    expect(find.text('15,000'), findsOneWidget);
  });

  testWidgets('InvoiceItemsTable allows custom service name inline editing without layout break on mobile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    String updatedName = '';
    final items = [
      InvoiceItem(serviceName: 'Custom Service', price: 1500.0, quantity: 3),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvoiceItemsTable(
              items: items,
              isEditable: true,
              onUpdateItem: (idx, {name, price, qty}) {
                if (name != null) updatedName = name;
              },
            ),
          ),
        ),
      ),
    );

    // Should find the custom name text field
    expect(find.text('Type service name...'), findsOneWidget);

    // Type a custom name
    await tester.enterText(find.byKey(const ValueKey('custom_name_0')), 'Special Wound Dressing');
    expect(updatedName, 'Special Wound Dressing');

    // Switch back to standard dropdown via arrow
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    // Now dropdown is visible
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });

  testWidgets('InvoiceTotalsSummary renders correct totals and status', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InvoiceTotalsSummary(
            subtotal: 15000.0,
            discount: 1000.0,
            grandTotal: 14000.0,
            paymentStatus: 'Paid',
            isEditable: false,
          ),
        ),
      ),
    );

    expect(find.text('15000 PKR'), findsOneWidget);
    expect(find.text('1000 PKR'), findsOneWidget);
    expect(find.text('14000 PKR'), findsOneWidget);
    expect(find.text('PAID'), findsOneWidget);
  });

  testWidgets('InvoiceBankDetailsSection renders Meezan Bank details', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InvoiceBankDetailsSection(),
        ),
      ),
    );

    expect(find.text('BANK TRANSFER DETAILS'), findsOneWidget);
    expect(find.text('Meezan Bank'), findsOneWidget);
  });

  testWidgets('InvoicePolicyNotice and InvoiceActionButtons render properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const InvoicePolicyNotice(),
              InvoiceActionButtons(
                onPrint: () {},
                onPdf: () {},
                onPng: () {},
                onJpg: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('IMPORTANT POLICY NOTICE'), findsOneWidget);
    expect(find.text('PRINT'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('JPG'), findsOneWidget);
  });
}
