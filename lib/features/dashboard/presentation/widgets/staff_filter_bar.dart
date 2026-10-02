import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/plan_expiration_provider.dart';
import '../providers/staff_filter_provider.dart';

class StaffFilterBar extends ConsumerWidget {
  const StaffFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final role = profile?['role'] ?? 'staff';

    // Only administrators have access to clinic-wide multi-staff queue filtering
    if (role != 'admin') {
      return const SizedBox.shrink();
    }

    final staffList = ref.watch(availableStaffListProvider);
    if (staffList.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedStaff = ref.watch(selectedStaffFilterProvider);
    final allPlans = ref.watch(expiringPlansProvider).value ?? [];
    final totalCount = allPlans.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 13, color: Colors.blueGrey.shade600),
              const SizedBox(width: 4),
              Text(
                'STAFF QUEUE FILTER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (selectedStaff != null)
                InkWell(
                  onTap: () => ref.read(selectedStaffFilterProvider.notifier).clear(),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      'Clear Filter',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "All Staff" Chip
                _FilterChip(
                  label: 'All Staff',
                  count: totalCount,
                  isSelected: selectedStaff == null,
                  onTap: () => ref.read(selectedStaffFilterProvider.notifier).clear(),
                ),
                const SizedBox(width: 6),
                // Individual Staff Chips
                ...staffList.map((staff) {
                  final count = ref.watch(staffPlanCountProvider(staff));
                  final isSelected = selectedStaff?.toLowerCase() == staff.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: staff,
                      count: count,
                      isSelected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          ref.read(selectedStaffFilterProvider.notifier).clear();
                        } else {
                          ref.read(selectedStaffFilterProvider.notifier).select(staff);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = const Color(0xFF1565C0);
    final inactiveBg = Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeBg : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBg.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
