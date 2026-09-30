import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/invoice_model.dart';

class InvoicesTableView extends StatelessWidget {
  final List<Invoice> invoices;
  final String? highlightId;
  final ValueChanged<Invoice> onInvoiceTap;
  final ValueChanged<Invoice> onExportTap;

  const InvoicesTableView({
    super.key,
    required this.invoices,
    this.highlightId,
    required this.onInvoiceTap,
    required this.onExportTap,
  });

  Widget _buildStatusBadge(String status) {
    final cleanStatus = status.trim().toLowerCase();
    Color bg;
    Color border;
    Color textColor;

    if (cleanStatus == 'paid') {
      bg = Colors.green.shade100;
      border = Colors.green.shade400;
      textColor = Colors.green.shade900;
    } else if (cleanStatus == 'partial') {
      bg = Colors.amber.shade100;
      border = Colors.amber.shade400;
      textColor = Colors.amber.shade900;
    } else {
      bg = Colors.red.shade100;
      border = Colors.red.shade400;
      textColor = Colors.red.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final uniqueInvoices = invoices.where((inv) {
      final key = inv.invoiceId.isNotEmpty ? inv.invoiceId : inv.invoiceNumber;
      return seen.add(key);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth = constraints.maxWidth < 580 ? 580.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minTableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC22727),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(2.5),
                        topRight: Radius.circular(2.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 25, child: Text('INVOICE #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8))),
                        Expanded(flex: 38, child: Text('MR NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8))),
                        Expanded(flex: 25, child: Text('GRAND TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8), textAlign: TextAlign.left)),
                        Expanded(flex: 12, child: Text('VIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  // Table Body
                  Expanded(
                    child: ListView.separated(
                      itemCount: uniqueInvoices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final inv = uniqueInvoices[index];
                        final isRecent = (highlightId != null && (inv.invoiceId == highlightId || inv.invoiceNumber == highlightId));

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: isRecent ? const EdgeInsets.symmetric(vertical: 4, horizontal: 4) : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: isRecent ? const Color(0xFFF1F5F9) : Colors.transparent,
                            borderRadius: isRecent ? BorderRadius.circular(6) : BorderRadius.zero,
                            border: isRecent
                                ? Border.all(color: const Color(0xFF64748B), width: 1.5)
                                : null,
                            boxShadow: isRecent
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isRecent)
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF475569),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(4.5),
                                      topRight: Radius.circular(4.5),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.history_outlined, color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'RECENT INVOICE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              InkWell(
                                onTap: () => onInvoiceTap(inv),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 25,
                                        child: Text(
                                          inv.invoiceNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 38,
                                        child: _PatientMrText(patientId: inv.patientId),
                                      ),
                                      Expanded(
                                        flex: 25,
                                        child: Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              'Rs. ${NumberFormat("#,###").format(inv.grandTotal.toInt())}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                                color: Color(0xFF14532D),
                                              ),
                                            ),
                                            _buildStatusBadge(inv.paymentStatus),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 12,
                                        child: Center(
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              color: Colors.black87,
                                              size: 18,
                                            ),
                                            onPressed: () => onExportTap(inv),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatientMrText extends StatefulWidget {
  final String patientId;

  const _PatientMrText({required this.patientId});

  @override
  State<_PatientMrText> createState() => _PatientMrTextState();
}

class _PatientMrTextState extends State<_PatientMrText> {
  static final Map<String, String> _cache = {};
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchMrNumber();
  }

  @override
  void didUpdateWidget(_PatientMrText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _future = _fetchMrNumber();
    }
  }

  Future<String> _fetchMrNumber() async {
    if (widget.patientId.isEmpty) return 'N/A';
    if (_cache.containsKey(widget.patientId)) {
      return _cache[widget.patientId]!;
    }
    try {
      final doc = await Supabase.instance.client
          .from('patients')
          .select('mr_number')
          .eq('id', widget.patientId)
          .maybeSingle();
      if (doc != null) {
        final mr = (doc['mr_number'] ?? doc['mrNumber'])?.toString() ?? 'Unknown';
        _cache[widget.patientId] = mr;
        return mr;
      }
    } catch (_) {}
    return widget.patientId;
  }

  @override
  Widget build(BuildContext context) {
    if (_cache.containsKey(widget.patientId)) {
      return Text(
        _cache[widget.patientId]!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Color(0xFF222222),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        final text = snapshot.data ?? '...';
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: Color(0xFF222222),
          ),
        );
      },
    );
  }
}
