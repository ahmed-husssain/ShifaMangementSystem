import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shifa_management/core/services/device_notification_service.dart';
import 'package:shifa_management/features/patients/domain/patient_model.dart';
import 'package:shifa_management/features/dashboard/presentation/providers/staff_filter_provider.dart';
import 'package:shifa_management/shared/providers/plan_expiration_provider.dart';

void main() {
  group('Phase 3: Staff Filter & Queue Isolation Unit Tests', () {
    final now = DateTime(2026, 10, 15, 12, 0, 0);

    Patient createTestPatient({
      required String id,
      required String name,
      required String doctor,
      required String nurse,
      required String caretaker,
      required String assignedStaffId,
    }) {
      return Patient(
        patientId: id,
        mrNumber: 'MR-$id',
        patientName: name,
        cnic: '12345-1234567-1',
        phone: '03001234567',
        address: 'Test Address',
        diagnosis: 'Test Diagnosis',
        doctor: doctor,
        nurse: nurse,
        caretaker: caretaker,
        selectedServices: [],
        monthlyServiceCost: 30000,
        patientAmount: 30000,
        staffPayment: 20000,
        profit: 10000,
        days: 30,
        assignedStaffId: assignedStaffId,
        organizationId: 'default',
        createdBy: 'admin',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedBy: 'admin',
        updatedAt: now,
      );
    }

    final p1 = createTestPatient(
      id: 'p1',
      name: 'Patient One',
      doctor: 'Dr. Tariq',
      nurse: 'Nurse Fatima',
      caretaker: 'Ali',
      assignedStaffId: 'staff-1',
    );

    final p2 = createTestPatient(
      id: 'p2',
      name: 'Patient Two',
      doctor: 'Dr. Sarah',
      nurse: 'Nurse Bilal',
      caretaker: '',
      assignedStaffId: '1sXu30D6dHCkOlZEisPL7KUCKsN2',
    );

    final plan1 = ExpiringPatientPlan(
      patient: p1,
      latestInvoiceDate: now.subtract(const Duration(days: 30)),
      expirationDate: now.subtract(const Duration(days: 1)),
      hoursRemaining: -24,
      calendarDaysRemaining: -1,
      isExpired: true,
      category: 'expired',
      totalPlanDays: 30,
    );

    final plan2 = ExpiringPatientPlan(
      patient: p2,
      latestInvoiceDate: now.subtract(const Duration(days: 30)),
      expirationDate: now,
      hoursRemaining: 6,
      calendarDaysRemaining: 0,
      isExpired: false,
      category: 'today',
      totalPlanDays: 30,
    );

    test('isGuidOrUid accurately distinguishes raw database UIDs from staff human names', () {
      // Raw UIDs/GUIDs should return true
      expect(isGuidOrUid('1sXu30D6dHCkOlZEisPL7KUCKsN2'), isTrue);
      expect(isGuidOrUid('c56a4180-65aa-42ec-a945-5fd21dec0538'), isTrue);

      // Human names should return false
      expect(isGuidOrUid('Dr. Tariq'), isFalse);
      expect(isGuidOrUid('Albert'), isFalse);
      expect(isGuidOrUid('Nurse Fatima'), isFalse);
      expect(isGuidOrUid('Ali'), isFalse);
      expect(isGuidOrUid(''), isFalse);
    });

    test('planMatchesStaff correctly identifies doctors, nurses, caretakers, and resolved staff UIDs', () {
      // Matches Doctor
      expect(planMatchesStaff(plan1, 'Dr. Tariq'), isTrue);
      expect(planMatchesStaff(plan1, 'Tariq'), isTrue);

      // Matches Nurse
      expect(planMatchesStaff(plan1, 'Nurse Fatima'), isTrue);
      expect(planMatchesStaff(plan1, 'Fatima'), isTrue);

      // Matches Caretaker
      expect(planMatchesStaff(plan1, 'Ali'), isTrue);

      // Matches Assigned Staff ID
      expect(planMatchesStaff(plan1, 'staff-1'), isTrue);

      // Does not match unrelated staff
      expect(planMatchesStaff(plan1, 'Dr. Sarah'), isFalse);
      expect(planMatchesStaff(plan1, 'Nurse Bilal'), isFalse);

      // Matches plan2 with resolved UID map
      final uidMap = {'1sXu30D6dHCkOlZEisPL7KUCKsN2': 'Nurse Albert'};
      expect(planMatchesStaff(plan2, 'Dr. Sarah', uidToNameMap: uidMap), isTrue);
      expect(planMatchesStaff(plan2, 'Nurse Albert', uidToNameMap: uidMap), isTrue);
      expect(planMatchesStaff(plan2, 'Albert', uidToNameMap: uidMap), isTrue);
      expect(planMatchesStaff(plan2, 'Dr. Tariq', uidToNameMap: uidMap), isFalse);
    });

    test('SelectedStaffFilterNotifier updates state properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedStaffFilterProvider), isNull);

      container.read(selectedStaffFilterProvider.notifier).select('Nurse Fatima');
      expect(container.read(selectedStaffFilterProvider), equals('Nurse Fatima'));

      container.read(selectedStaffFilterProvider.notifier).clear();
      expect(container.read(selectedStaffFilterProvider), isNull);
    });
  });

  group('Phase 3: DeviceNotificationService Unit Tests', () {
    test('DeviceNotificationService configuration constants are valid', () {
      expect(DeviceNotificationService.channelId, equals('shifa_plan_expirations'));
      expect(DeviceNotificationService.channelName, equals('Care Plan Expirations'));
      expect(DeviceNotificationService.channelDescription.isNotEmpty, isTrue);
    });

    test('DeviceNotificationService singleton instance is maintained', () {
      final instance1 = DeviceNotificationService.instance;
      final instance2 = DeviceNotificationService.instance;
      expect(identical(instance1, instance2), isTrue);
    });
  });
}
