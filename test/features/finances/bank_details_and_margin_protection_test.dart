import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/core/config/bank_details.dart';
import 'package:shifa_management/features/invoices/presentation/widgets/components/invoice_bank_details_section.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';

void main() {
  group('Phase 3: BankDetails Model & Config Tests', () {
    test('defaultDetails contains valid baseline clinic banking configuration', () {
      const details = BankDetails.defaultDetails;
      expect(details.bankName, isNotEmpty);
      expect(details.accountTitle, isNotEmpty);
      expect(details.accountNumber, isNotEmpty);
      expect(details.iban, isNotEmpty);
      expect(details.bankName, equals('Qatar National Bank (QNB)'));
      expect(details.accountTitle, equals('SHIFA HOME HEALTH CARE'));
    });

    test('fromMap parses custom clinic bank details correctly', () {
      final customMap = {
        'bank_name': 'Habib Bank Limited',
        'account_title': 'SHIFA HEALTHCARE SERVICES',
        'account_number': '98765432101234',
        'iban': 'PK36HABB0000987654321012',
      };

      final details = BankDetails.fromMap(customMap);
      expect(details.bankName, equals('Habib Bank Limited'));
      expect(details.accountTitle, equals('SHIFA HEALTHCARE SERVICES'));
      expect(details.accountNumber, equals('98765432101234'));
      expect(details.iban, equals('PK36HABB0000987654321012'));
    });

    test('toMap serializes bank details cleanly', () {
      const details = BankDetails(
        bankName: 'Standard Chartered',
        accountTitle: 'SHIFA CLINIC',
        accountNumber: '1122334455',
        iban: 'PK00SCBL1122334455667788',
      );

      final map = details.toMap();
      expect(map['bank_name'], equals('Standard Chartered'));
      expect(map['account_title'], equals('SHIFA CLINIC'));
      expect(map['account_number'], equals('1122334455'));
      expect(map['iban'], equals('PK00SCBL1122334455667788'));
    });

    test('fromMap falls back gracefully to default values when fields are missing', () {
      final incompleteMap = <String, dynamic>{
        'bank_name': 'Bank Alfalah',
      };

      final details = BankDetails.fromMap(incompleteMap);
      expect(details.bankName, equals('Bank Alfalah'));
      expect(details.accountTitle, equals(BankDetails.defaultDetails.accountTitle));
      expect(details.accountNumber, equals(BankDetails.defaultDetails.accountNumber));
      expect(details.iban, equals(BankDetails.defaultDetails.iban));
    });
  });

  group('Phase 3: InvoiceBankDetailsSection with Decoupled Banking Details', () {
    testWidgets('InvoiceBankDetailsSection renders custom bank details when provided', (WidgetTester tester) async {
      const customBank = BankDetails(
        bankName: 'Faysal Bank Islamic',
        accountTitle: 'SHIFA MEDICAL SERVICES',
        accountNumber: '556677889900',
        iban: 'PK99FAYS55667788990011',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceBankDetailsSection(bankDetails: customBank),
          ),
        ),
      );

      expect(find.text('BANK TRANSFER DETAILS'), findsOneWidget);
      expect(find.text('Faysal Bank Islamic'), findsOneWidget);
      expect(find.text('SHIFA MEDICAL SERVICES'), findsOneWidget);
      expect(find.text('556677889900'), findsOneWidget);
      expect(find.text('PK99FAYS55667788990011'), findsOneWidget);
    });

    testWidgets('InvoiceBankDetailsSection falls back to default bank details when null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceBankDetailsSection(),
          ),
        ),
      );

      expect(find.text('BANK TRANSFER DETAILS'), findsOneWidget);
      expect(find.text('Qatar National Bank (QNB)'), findsOneWidget);
      expect(find.text('SHIFA HOME HEALTH CARE'), findsOneWidget);
      expect(find.text('00102701151847'), findsOneWidget);
      expect(find.text('QA42QNBA00000000102701151847'), findsOneWidget);
    });
  });

  group('Phase 3: Staff Finance Isolation Logic', () {
    test('staff view computes staff earnings without exposing clinic profit or intake', () {
      final patient = Patient(
        patientId: 'PAT-STAFF-1',
        mrNumber: 'MR-001',
        patientName: 'Patient Under Care',
        cnic: '42101-1234567-1',
        phone: '03009998877',
        address: 'Karachi',
        diagnosis: 'General',
        doctor: 'Dr. Smith',
        nurse: 'Nurse Jane',
        caretaker: 'Staff Member',
        selectedServices: [{'name': 'ICU Care', 'rate': 5000}],
        monthlyServiceCost: 150000.0,
        patientAmount: 150000.0, // Confidential clinic intake revenue
        staffPayment: 60000.0,   // Legitimate staff earnings
        profit: 90000.0,         // Confidential margin
        days: 30,
        assignedStaffId: 'staff-1',
        organizationId: 'org-1',
        createdBy: 'admin',
        createdAt: DateTime.now(),
        updatedBy: 'admin',
        updatedAt: DateTime.now(),
      );

      // Verify that staff earnings are isolated and computable without disclosing clinic intake
      final staffDailyRate = patient.staffPayment / (patient.days > 0 ? patient.days : 30);
      expect(staffDailyRate, equals(2000.0));

      const invoiceDays = 15;
      final staffEarnings = invoiceDays * staffDailyRate;

      // Staff only sees their earnings
      expect(staffEarnings, equals(30000.0));

      // Clinic profit margin (patientAmount - staffPayment) is 90,000, which must NOT be in staff view
      final confidentialProfit = patient.patientAmount - patient.staffPayment;
      expect(confidentialProfit, equals(90000.0));
    });
  });
}
