import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../data/invoice_repository.dart';
import '../invoice_export_page.dart';
import '../invoice_form_screen.dart';
import '../../../patients/data/patient_repository.dart';
import '../widgets/invoice_details_dialog.dart';
import '../widgets/invoices_search_bar.dart';
import '../widgets/invoices_table_view.dart';

class RecentInvoiceHighlightNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setHighlight(String? id) => state = id;
}

final recentInvoiceHighlightProvider = NotifierProvider<RecentInvoiceHighlightNotifier, String?>(
  RecentInvoiceHighlightNotifier.new,
);

class InvoiceSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query.trim();
  void clear() => state = '';
}

final invoiceSearchQueryProvider = NotifierProvider<InvoiceSearchQueryNotifier, String>(
  InvoiceSearchQueryNotifier.new,
);

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(invoiceSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userProfileProvider.select((v) => v.value?['role'] ?? 'staff'));
    final highlightId = ref.watch(recentInvoiceHighlightProvider);
    final rawSearchQuery = ref.watch(invoiceSearchQueryProvider);
    final searchQuery = rawSearchQuery.toLowerCase();

    ref.listen<String>(invoiceSearchQueryProvider, (prev, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    if (highlightId != null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && ref.read(recentInvoiceHighlightProvider) == highlightId) {
          ref.read(recentInvoiceHighlightProvider.notifier).setHighlight(null);
        }
      });
    }

    // RBAC: Admin sees all invoices, staff only sees their own assigned/created invoices
    final invoicesAsync = role == 'admin'
        ? ref.watch(allInvoicesProvider(false))
        : ref.watch(staffInvoicesProvider);

    final patientsAsync = role == 'admin'
        ? ref.watch(allPatientsProvider(true))
        : ref.watch(staffPatientsProvider);

    final patientMap = {
      for (final p in (patientsAsync.value ?? [])) p.patientId: p,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INVOICES',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.5,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InvoiceFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Create Invoice',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004B93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Instant Multi-Field Invoice Search Bar
            InvoicesSearchBar(
              controller: _searchController,
              query: rawSearchQuery,
              onChanged: (val) => ref.read(invoiceSearchQueryProvider.notifier).setQuery(val),
              onClear: () {
                _searchController.clear();
                ref.read(invoiceSearchQueryProvider.notifier).clear();
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: invoicesAsync.when(
                data: (invoices) {
                  if (invoices.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          'NO INVOICES FOUND',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    );
                  }

                  final filteredInvoices = invoices.where((inv) {
                    if (searchQuery.isEmpty) return true;

                    final invNum = inv.invoiceNumber.toLowerCase();
                    final pId = inv.patientId.toLowerCase();
                    final p = patientMap[inv.patientId];
                    final mrNum = (p?.mrNumber ?? '').toLowerCase();
                    final pName = (p?.patientName ?? '').toLowerCase();
                    final status = inv.paymentStatus.toLowerCase();

                    return invNum.contains(searchQuery) ||
                        pId.contains(searchQuery) ||
                        mrNum.contains(searchQuery) ||
                        pName.contains(searchQuery) ||
                        status.contains(searchQuery);
                  }).toList();

                  if (filteredInvoices.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 44, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text(
                              'No invoices found for "$rawSearchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                ref.read(invoiceSearchQueryProvider.notifier).clear();
                              },
                              child: const Text('Clear Search Filter'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return InvoicesTableView(
                    invoices: filteredInvoices,
                    highlightId: highlightId,
                    onInvoiceTap: (inv) {
                      showDialog(
                        context: context,
                        builder: (_) => InvoiceDetailsDialog(invoice: inv),
                      );
                    },
                    onExportTap: (inv) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => InvoiceExportPage(invoice: inv),
                      ));
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
