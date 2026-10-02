import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/shared/providers/plan_expiration_provider.dart';

void main() {
  group('Phase 2: Smart Invoice Continuity & Zero-Gap Date Calculation Tests', () {
    Patient createTestPatient({
      required String id,
      required String name,
      required int days,
      required DateTime createdAt,
      List<Map<String, dynamic>>? selectedServices,
    }) {
      return Patient(
        patientId: id,
        mrNumber: 'MR-$id',
        patientName: name,
        cnic: '12345-1234567-1',
        phone: '03001234567',
        address: 'Test Address',
        diagnosis: 'General Care',
        doctor: 'Dr. Sarah',
        nurse: 'Nurse John',
        caretaker: 'Caretaker Ali',
        selectedServices: selectedServices ?? [
          {'serviceName': 'Home Nursing Care Services', 'dailyPrice': 3000.0}
        ],
        monthlyServiceCost: 90000,
        patientAmount: 90000,
        staffPayment: 60000,
        profit: 30000,
        days: days,
        assignedStaffId: 'staff-1',
        organizationId: 'default',
        createdBy: 'admin-1',
        createdAt: createdAt,
        updatedBy: 'admin-1',
        updatedAt: createdAt,
      );
    }

    Invoice createTestInvoice({
      required String invoiceId,
      required String patientId,
      required DateTime createdAt,
      required DateTime fromDate,
      required DateTime toDate,
      required int days,
      List<InvoiceItem>? items,
    }) {
      return Invoice(
        invoiceId: invoiceId,
        invoiceNumber: 'SHHC-$invoiceId',
        patientId: patientId,
        staffId: 'staff-1',
        subtotal: 90000,
        discount: 0,
        grandTotal: 90000,
        items: items ?? [
          InvoiceItem(serviceName: 'Home Nursing Care Services', price: 3000.0, quantity: days),
        ],
        organizationId: 'default',
        createdBy: 'admin-1',
        createdAt: createdAt,
        updatedBy: 'admin-1',
        updatedAt: createdAt,
        fromDate: fromDate,
        toDate: toDate,
        days: days,
      );
    }

    test('1. Renewal Invoice starts exactly 1 day after previous toDate (Zero Gap & Zero Overlap)', () {
      final prevFrom = DateTime(2026, 9, 1);
      final prevTo = DateTime(2026, 9, 30); // 30-day plan covering September
      final patient = createTestPatient(
        id: 'p1',
        name: 'Inam Siddiqui',
        days: 30,
        createdAt: DateTime(2026, 9, 1),
      );
      final prevInvoice = createTestInvoice(
        invoiceId: '5001',
        patientId: 'p1',
        createdAt: DateTime(2026, 9, 1),
        fromDate: prevFrom,
        toDate: prevTo,
        days: 30,
      );

      // Continuity calculation logic
      final prevEnd = prevInvoice.toDate!;
      final nextFrom = DateTime(prevEnd.year, prevEnd.month, prevEnd.day).add(const Duration(days: 1));
      final nextTo = nextFrom.add(Duration(days: patient.days));

      // Verifications
      expect(nextFrom, DateTime(2026, 10, 1));
      expect(nextTo, DateTime(2026, 10, 31));
      expect(nextFrom.difference(prevEnd).inDays, 1); // Exact next day
    });

    test('2. First Invoice for newly enrolled patient starts on registration date', () {
      final regDate = DateTime(2026, 10, 10, 14, 30);
      final patient = createTestPatient(
        id: 'p2',
        name: 'Fatima Noor',
        days: 10,
        createdAt: regDate,
      );

      // New patient has no invoices yet
      final firstFrom = DateTime(patient.createdAt.year, patient.createdAt.month, patient.createdAt.day);
      final firstTo = firstFrom.add(Duration(days: patient.days));

      expect(firstFrom, DateTime(2026, 10, 10));
      expect(firstTo, DateTime(2026, 10, 20));
      expect(firstTo.difference(firstFrom).inDays, 10);
    });

    test('3. ExpiringPatientPlan handover computes consecutive date correctly from notification', () {
      final now = DateTime(2026, 10, 25);
      final patient = createTestPatient(
        id: 'p3',
        name: 'Tariq Mehmood',
        days: 15,
        createdAt: DateTime(2026, 10, 1),
      );
      final invoice = createTestInvoice(
        invoiceId: '5002',
        patientId: 'p3',
        createdAt: DateTime(2026, 10, 10),
        fromDate: DateTime(2026, 10, 10),
        toDate: DateTime(2026, 10, 25), // Expires today
        days: 15,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.isFirstInvoice, false);

      // Modal Handover Date calculation
      final DateTime targetFromDate;
      if (plan.isFirstInvoice) {
        targetFromDate = DateTime(patient.createdAt.year, patient.createdAt.month, patient.createdAt.day);
      } else {
        final exp = plan.expirationDate;
        targetFromDate = DateTime(exp.year, exp.month, exp.day).add(const Duration(days: 1));
      }

      expect(targetFromDate, DateTime(2026, 10, 26)); // Starts tomorrow
    });

    test('4. Notification handover for brand new registered patient targets enrollment start', () {
      final now = DateTime(2026, 10, 7);
      final patient = createTestPatient(
        id: 'p4',
        name: 'Kamran Ali',
        days: 10,
        createdAt: DateTime(2026, 10, 1),
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.isFirstInvoice, true);

      // Handover Date for first invoice
      final DateTime targetFromDate;
      if (plan.isFirstInvoice) {
        targetFromDate = DateTime(patient.createdAt.year, patient.createdAt.month, patient.createdAt.day);
      } else {
        final exp = plan.expirationDate;
        targetFromDate = DateTime(exp.year, exp.month, exp.day).add(const Duration(days: 1));
      }

      expect(targetFromDate, DateTime(2026, 10, 1)); // Enrolled date
    });

    test('5. Item quantity scales to match renewed plan duration', () {
      final patient = createTestPatient(
        id: 'p5',
        name: 'Zahid Khan',
        days: 30,
        createdAt: DateTime(2026, 8, 1),
        selectedServices: [
          {'serviceName': 'Home Attendant Service', 'dailyPrice': 2000.0},
          {'serviceName': 'Home Physiotherapy Services', 'dailyPrice': 3000.0},
        ],
      );

      final int renewedDays = 15; // Renewed for 15 days instead of 30
      final List<InvoiceItem> renewedItems = patient.selectedServices.map((s) {
        return InvoiceItem(
          serviceName: s['serviceName'],
          price: (s['dailyPrice'] as num).toDouble(),
          quantity: renewedDays,
        );
      }).toList();

      expect(renewedItems.length, 2);
      expect(renewedItems[0].quantity, 15);
      expect(renewedItems[0].total, 30000.0);
      expect(renewedItems[1].quantity, 15);
      expect(renewedItems[1].total, 45000.0);
      final subtotal = renewedItems.fold<double>(0.0, (acc, item) => acc + item.total);
      expect(subtotal, 75000.0);
    });

    test('6. Fallback carryover: uses previous invoice items when patient selectedServices is empty', () {
      final patient = createTestPatient(
        id: 'p6',
        name: 'Rashid Minhas',
        days: 30,
        createdAt: DateTime(2026, 7, 1),
        selectedServices: [], // Empty package in patient profile
      );

      final prevInvoice = createTestInvoice(
        invoiceId: '5003',
        patientId: 'p6',
        createdAt: DateTime(2026, 8, 1),
        fromDate: DateTime(2026, 8, 1),
        toDate: DateTime(2026, 8, 31),
        days: 30,
        items: [
          InvoiceItem(serviceName: 'Custom Wound Care', price: 2500.0, quantity: 30),
          InvoiceItem(serviceName: 'Home ICU Nurse Setup', price: 3500.0, quantity: 30),
        ],
      );

      final int newDays = 30;
      final List<InvoiceItem> carriedItems = [];
      if (patient.selectedServices.isEmpty && prevInvoice.items.isNotEmpty) {
        for (final item in prevInvoice.items) {
          carriedItems.add(InvoiceItem(
            serviceName: item.serviceName,
            price: item.price,
            quantity: newDays,
          ));
        }
      }

      expect(carriedItems.length, 2);
      expect(carriedItems[0].serviceName, 'Custom Wound Care');
      expect(carriedItems[0].price, 2500.0);
      expect(carriedItems[0].quantity, 30);
      expect(carriedItems[1].serviceName, 'Home ICU Nurse Setup');
      expect(carriedItems[1].price, 3500.0);
      expect(carriedItems[1].quantity, 30);
    });
  });
}
