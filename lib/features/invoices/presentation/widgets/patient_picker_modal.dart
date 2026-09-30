import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../patients/data/patient_repository.dart';
import '../../../patients/domain/patient_model.dart';

class PatientPickerModal extends ConsumerStatefulWidget {
  const PatientPickerModal({super.key});

  static Future<Patient?> show(BuildContext context) {
    return showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const PatientPickerModal(),
    );
  }

  @override
  ConsumerState<PatientPickerModal> createState() => _PatientPickerModalState();
}

class _PatientPickerModalState extends ConsumerState<PatientPickerModal> {
  final _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final role = profile?['role'] ?? 'staff';

    final patientsAsync = role == 'admin'
        ? ref.watch(allPatientsProvider(false))
        : ref.watch(staffPatientsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    role == 'admin' ? 'Select Patient' : 'Select My Patient',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Filter by Name, MR#, or CNIC...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: patientsAsync.when(
                  data: (patients) {
                    final activePatients = patients.where((p) {
                      if (p.isDiscontinued) return false;
                      if (_searchFilter.isEmpty) return true;
                      return p.patientName.toLowerCase().contains(_searchFilter) ||
                          p.mrNumber.toLowerCase().contains(_searchFilter) ||
                          p.cnic.toLowerCase().contains(_searchFilter);
                    }).toList();

                    if (activePatients.isEmpty) {
                      return const Center(child: Text('No registered active patients found.'));
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: activePatients.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final p = activePatients[index];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(p.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('MR: ${p.mrNumber} • CNIC: ${p.cnic}'),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: ')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
