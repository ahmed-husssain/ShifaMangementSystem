import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InvoicePatientSection extends StatelessWidget {
  final TextEditingController? mrNumberController;
  final TextEditingController? nameController;
  final TextEditingController? phoneController;
  final TextEditingController? addressController;
  final bool isSearchingPatient;
  final String? searchStatusMessage;
  final VoidCallback? onSelectPatientFromDatabase;
  final ValueChanged<String>? onSearchMRNumber;
  final bool isEditable;

  // Read-only values (if not editable)
  final String? readOnlyMrNumber;
  final String? readOnlyName;
  final String? readOnlyPhone;
  final String? readOnlyAddress;

  const InvoicePatientSection({
    super.key,
    this.mrNumberController,
    this.nameController,
    this.phoneController,
    this.addressController,
    this.isSearchingPatient = false,
    this.searchStatusMessage,
    this.onSelectPatientFromDatabase,
    this.onSearchMRNumber,
    this.isEditable = true,
    this.readOnlyMrNumber,
    this.readOnlyName,
    this.readOnlyPhone,
    this.readOnlyAddress,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BILL TO / PATIENT DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _infoRow('MR Number:', readOnlyMrNumber ?? 'N/A')),
                Expanded(child: _infoRow('Patient Name:', readOnlyName ?? 'N/A')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _infoRow('Phone:', readOnlyPhone ?? 'N/A')),
                Expanded(child: _infoRow('Address:', readOnlyAddress ?? 'N/A')),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (onSelectPatientFromDatabase != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onSelectPatientFromDatabase,
              icon: const Icon(Icons.person_search, size: 16, color: Color(0xFF1565C0)),
              label: const Text(
                'SELECT PATIENT FROM DATABASE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF1565C0), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MR NUMBER FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MR NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: mrNumberController,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Paste MR Number',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.normal,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            suffixIcon: isSearchingPatient
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search, size: 18),
                                    color: const Color(0xFF1565C0),
                                    onPressed: () {
                                      if (mrNumberController != null) {
                                        onSearchMRNumber?.call(mrNumberController!.text);
                                      }
                                    },
                                  ),
                          ),
                          onChanged: (val) {
                            if (val.trim().length >= 3) {
                              onSearchMRNumber?.call(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // PATIENT NAME FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PATIENT NAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Patient Name',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.normal,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (searchStatusMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  searchStatusMessage!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: searchStatusMessage!.startsWith('✓')
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PHONE FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PHONE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ADDRESS FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADDRESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: addressController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Address',
                            hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
