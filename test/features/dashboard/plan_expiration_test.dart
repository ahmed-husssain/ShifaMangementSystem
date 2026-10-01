import 'package:flutter_test/flutter_test.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';
import 'package:shifa_management/features/invoices/domain/invoice_model.dart';
import 'package:shifa_management/features/dashboard/domain/scheduled_notification_model.dart';
import 'package:shifa_management/shared/providers/plan_expiration_provider.dart';

void main() {
  group('Phase 1: Dynamic Plan Expiration & 7-Day Window Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0, 0);

    Patient createTestPatient({
      required String id,
      required String name,
      required int days,
      required DateTime createdAt,
      bool isDiscontinued = false,
      bool isDeleted = false,
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
        selectedServices: [
          {'serviceName': 'Nursing Care', 'price': 5000}
        ],
        monthlyServiceCost: 5000,
        patientAmount: 5000,
        staffPayment: 3000,
        profit: 2000,
        days: days,
        assignedStaffId: 'staff-1',
        organizationId: 'default',
        createdBy: 'admin-1',
        createdAt: createdAt,
        updatedBy: 'admin-1',
        updatedAt: createdAt,
        isDiscontinued: isDiscontinued,
        isDeleted: isDeleted,
      );
    }

    Invoice createTestInvoice({
      required String invoiceId,
      required String patientId,
      required DateTime createdAt,
      required DateTime fromDate,
      required DateTime toDate,
      required int days,
    }) {
      return Invoice(
        invoiceId: invoiceId,
        invoiceNumber: 'INV-$invoiceId',
        patientId: patientId,
        staffId: 'staff-1',
        subtotal: 10000,
        discount: 0,
        grandTotal: 10000,
        items: [
          InvoiceItem(serviceName: 'Home Care', price: 10000, quantity: 1),
        ],
        organizationId: 'default',
        createdBy: 'staff-1',
        createdAt: createdAt,
        updatedBy: 'staff-1',
        updatedAt: createdAt,
        paymentStatus: 'paid',
        fromDate: fromDate,
        toDate: toDate,
        days: days,
      );
    }

    test('30-Day Invoice: Day 10 (20 days remaining) does NOT trigger notification', () {
      final invoiceDate = now.subtract(const Duration(days: 10)); // 10 days into 30-day cycle
      final patient = createTestPatient(
        id: 'p1',
        name: 'Fatima Bibi',
        days: 30,
        createdAt: invoiceDate,
      );
      final invoice = createTestInvoice(
        invoiceId: 'inv1',
        patientId: 'p1',
        createdAt: invoiceDate,
        fromDate: invoiceDate,
        toDate: invoiceDate.add(const Duration(days: 30)),
        days: 30,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans, isEmpty, reason: 'Plan has 20 days remaining, should not notify yet');
    });

    test('30-Day Invoice: Day 23 (7 days remaining) triggers Upcoming notification', () {
      final invoiceDate = now.subtract(const Duration(days: 23)); // 23 days passed -> 7 days remaining
      final patient = createTestPatient(
        id: 'p2',
        name: 'Fatima Bibi',
        days: 30,
        createdAt: invoiceDate,
      );
      final invoice = createTestInvoice(
        invoiceId: 'inv2',
        patientId: 'p2',
        createdAt: invoiceDate,
        fromDate: invoiceDate,
        toDate: invoiceDate.add(const Duration(days: 30)),
        days: 30,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.category, 'upcoming');
      expect(plan.totalPlanDays, 30);
      expect(plan.isFirstInvoice, false);
      expect(plan.notificationMessage, contains('30-day plan expires in 7 days'));
    });

    test('30-Day Invoice: Day 29.5 (12 hours remaining) triggers Today notification', () {
      final toDate = DateTime(now.year, now.month, now.day); // Ends today
      final fromDate = toDate.subtract(const Duration(days: 30));
      final patient = createTestPatient(
        id: 'p3',
        name: 'Zahid Khan',
        days: 30,
        createdAt: fromDate,
      );
      final invoice = createTestInvoice(
        invoiceId: 'inv3',
        patientId: 'p3',
        createdAt: fromDate,
        fromDate: fromDate,
        toDate: toDate,
        days: 30,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.category, 'today');
      expect(plan.isExpired, false);
      expect(plan.notificationMessage, contains('expires today'));
    });

    test('30-Day Invoice: Day 32 (expired 2 days ago) triggers Expired notification', () {
      final toDate = now.subtract(const Duration(days: 2));
      final fromDate = toDate.subtract(const Duration(days: 30));
      final patient = createTestPatient(
        id: 'p4',
        name: 'Rashid Minhas',
        days: 30,
        createdAt: fromDate,
      );
      final invoice = createTestInvoice(
        invoiceId: 'inv4',
        patientId: 'p4',
        createdAt: fromDate,
        fromDate: fromDate,
        toDate: toDate,
        days: 30,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.category, 'expired');
      expect(plan.isExpired, true);
      expect(plan.notificationMessage, contains('expired'));
    });

    test('New Patient registered for 10 days: Day 2 (8 days left) does NOT notify', () {
      final regDate = now.subtract(const Duration(days: 2));
      final patient = createTestPatient(
        id: 'new-p1',
        name: 'Daniyal Ahmed',
        days: 10,
        createdAt: regDate,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [], // No invoices yet
        standaloneScheduled: [],
        now: now,
      );

      expect(plans, isEmpty, reason: '8 days remaining on 10-day registration should not notify yet');
    });

    test('New Patient registered for 10 days: Day 3 (7 days left) triggers Upcoming First Invoice', () {
      final regDate = now.subtract(const Duration(days: 3));
      final patient = createTestPatient(
        id: 'new-p2',
        name: 'Daniyal Ahmed',
        days: 10,
        createdAt: regDate,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.category, 'upcoming');
      expect(plan.totalPlanDays, 10);
      expect(plan.isFirstInvoice, true);
      expect(plan.notificationMessage, contains('initial 10-day registration'));
      expect(plan.notificationMessage, contains('issue their first invoice'));
    });

    test('New Patient registered for 10 days: Day 11 triggers Expired First Invoice', () {
      final regDate = now.subtract(const Duration(days: 11));
      final patient = createTestPatient(
        id: 'new-p3',
        name: 'Daniyal Ahmed',
        days: 10,
        createdAt: regDate,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans.length, 1);
      final plan = plans.first;
      expect(plan.category, 'expired');
      expect(plan.isFirstInvoice, true);
      expect(plan.notificationMessage, contains('initial 10-day registration expired'));
      expect(plan.notificationMessage, contains('issue their first invoice'));
    });

    test('Handover: Once invoice is issued for new patient, invoice dates take precedence', () {
      final regDate = now.subtract(const Duration(days: 15));
      final patient = createTestPatient(
        id: 'p-handover',
        name: 'Usman Ali',
        days: 10,
        createdAt: regDate,
      );

      final invoice = createTestInvoice(
        invoiceId: 'inv-handover',
        patientId: 'p-handover',
        createdAt: now.subtract(const Duration(days: 5)),
        fromDate: now.subtract(const Duration(days: 5)),
        toDate: now.add(const Duration(days: 25)),
        days: 30,
      );

      final plans = calculateExpiringPlans(
        patients: [patient],
        invoices: [invoice],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans, isEmpty);
    });

    test('Discontinued or deleted patients are safely excluded', () {
      final regDate = now.subtract(const Duration(days: 25));
      final discontinuedPatient = createTestPatient(
        id: 'disc-1',
        name: 'Discontinued Person',
        days: 10,
        createdAt: regDate,
        isDiscontinued: true,
      );
      final deletedPatient = createTestPatient(
        id: 'del-1',
        name: 'Deleted Person',
        days: 10,
        createdAt: regDate,
        isDeleted: true,
      );

      final plans = calculateExpiringPlans(
        patients: [discontinuedPatient, deletedPatient],
        invoices: [],
        standaloneScheduled: [],
        now: now,
      );

      expect(plans, isEmpty);
    });
  });
}
