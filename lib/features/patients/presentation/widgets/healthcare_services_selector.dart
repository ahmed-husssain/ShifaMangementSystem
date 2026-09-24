import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HealthcareServicesSelector extends StatefulWidget {
  final List<Map<String, dynamic>> initialSelectedServices;
  final Function(List<Map<String, dynamic>>, double) onChanged;

  const HealthcareServicesSelector({
    super.key,
    required this.initialSelectedServices,
    required this.onChanged,
  });

  @override
  State<HealthcareServicesSelector> createState() => _HealthcareServicesSelectorState();
}

class _HealthcareServicesSelectorState extends State<HealthcareServicesSelector> {
  // Standard available services (Prices are per-day costs)
  final List<Map<String, dynamic>> _availableServices = [
    {'serviceName': 'Online Doctor Consultation', 'dailyPrice': 0.0, 'isCustom': false},
    {'serviceName': 'Home Physiotherapy Services', 'dailyPrice': 3000.0, 'isCustom': false},
    {'serviceName': 'Home Nursing Care Services', 'dailyPrice': 3000.0, 'isCustom': false},
    {'serviceName': 'Home Attendant Service', 'dailyPrice': 2000.0, 'isCustom': false},
    {'serviceName': 'Home Nurse Visit', 'dailyPrice': 2000.0, 'isCustom': false},
    {'serviceName': 'Home NG Tube Insertion', 'dailyPrice': 2500.0, 'isCustom': false},
    {'serviceName': 'Wound & Bed Sore Dressing', 'dailyPrice': 2000.0, 'isCustom': false},
    {'serviceName': 'Home ICU Nurse', 'dailyPrice': 3500.0, 'isCustom': false},
    {'serviceName': 'Medical Equipment', 'dailyPrice': 0.0, 'isCustom': false},
  ];

  late List<Map<String, dynamic>> _selectedServices;

  @override
  void initState() {
    super.initState();
    _selectedServices = List<Map<String, dynamic>>.from(
      widget.initialSelectedServices.map((s) => Map<String, dynamic>.from(s)),
    );

    // If initial selected services contains custom services not in standard list, dynamically add them
    for (final service in _selectedServices) {
      final name = (service['serviceName'] ?? service['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        final exists = _availableServices.any(
          (s) => (s['serviceName'] as String).toLowerCase() == name.toLowerCase(),
        );
        if (!exists) {
          final price = (service['dailyPrice'] ?? service['price'] ?? 0.0) is num
              ? (service['dailyPrice'] ?? service['price'] as num).toDouble()
              : double.tryParse((service['dailyPrice'] ?? service['price'] ?? '0').toString()) ?? 0.0;
          _availableServices.add({
            'serviceName': name,
            'dailyPrice': price,
            'isCustom': true,
          });
        }
      }
    }
  }

  bool _isServiceSelected(String serviceName) {
    return _selectedServices.any((s) => s['serviceName'] == serviceName);
  }

  double _calculate30DayTotal() {
    return _selectedServices.fold(0.0, (sum, item) {
      final price = (item['dailyPrice'] is num) ? (item['dailyPrice'] as num).toDouble() : 0.0;
      return sum + (price * 30);
    });
  }

  void _toggleService(Map<String, dynamic> service, bool selected) {
    setState(() {
      if (selected) {
        _selectedServices.add(Map<String, dynamic>.from(service));
      } else {
        _selectedServices.removeWhere((s) => s['serviceName'] == service['serviceName']);
      }
    });

    widget.onChanged(_selectedServices, _calculate30DayTotal());
  }

  void _removeCustomService(Map<String, dynamic> service) {
    setState(() {
      _availableServices.removeWhere((s) => s['serviceName'] == service['serviceName']);
      _selectedServices.removeWhere((s) => s['serviceName'] == service['serviceName']);
    });

    widget.onChanged(_selectedServices, _calculate30DayTotal());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed custom service: ${service['serviceName']}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddCustomServiceDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_task_rounded, color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Add Custom Service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Name (Letters & Spaces Only)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      // Strictly restrict input to English letters and spaces
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g. Speech Therapy Support',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.medical_information_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null) return 'Please enter a service name';
                      final cleaned = val.trim().replaceAll(RegExp(r'\s+'), ' ');
                      if (cleaned.isEmpty) {
                        return 'Service name is required';
                      }
                      if (cleaned.length < 2) {
                        return 'Service name must be at least 2 letters long';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(cleaned)) {
                        return 'Only alphabetic letters and spaces are allowed';
                      }
                      final alreadyExists = _availableServices.any((s) =>
                          (s['serviceName'] as String).trim().toLowerCase() == cleaned.toLowerCase());
                      if (alreadyExists) {
                        return 'This service name already exists in the list';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Daily Rate / Price (Optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'PKR  ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal < 0) {
                        return 'Please enter a valid positive price';
                      }
                      if (numVal > 10000000) {
                        return 'Price cannot exceed PKR 10,000,000';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final sanitizedName = nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                  final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                  final newService = {
                    'serviceName': sanitizedName,
                    'dailyPrice': price,
                    'isCustom': true,
                  };

                  setState(() {
                    _availableServices.add(newService);
                    _selectedServices.add(Map<String, dynamic>.from(newService));
                  });

                  widget.onChanged(_selectedServices, _calculate30DayTotal());
                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Custom service "$sanitizedName" added and selected'),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Service'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Title and Custom Service Action Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Select Healthcare Services',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showAddCustomServiceDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Custom Service',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 74,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _availableServices.length,
          itemBuilder: (context, index) {
            final service = _availableServices[index];
            final isCustom = service['isCustom'] == true;
            final isSelected = _isServiceSelected(service['serviceName'] as String);
            final dailyPrice = (service['dailyPrice'] is num) ? (service['dailyPrice'] as num).toDouble() : 0.0;

            return InkWell(
              onTap: () => _toggleService(service, !isSelected),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                    width: isSelected ? 2 : 1.2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 8.0,
                          right: isCustom ? 24.0 : 8.0,
                          top: 6.0,
                          bottom: 6.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service['serviceName'] as String,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected ? Colors.blue.shade800 : Colors.grey.shade800,
                              ),
                            ),
                            if (dailyPrice > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'PKR ${dailyPrice.toStringAsFixed(0)}/day',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isCustom)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeCustomService(service),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

