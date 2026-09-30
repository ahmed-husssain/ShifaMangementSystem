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
