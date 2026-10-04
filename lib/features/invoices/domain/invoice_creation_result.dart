class InvoiceCreationResult {
  final String id;
  final String invoiceNumber;
  final bool isReplayed;
  final int? counter;

  const InvoiceCreationResult({
    required this.id,
    required this.invoiceNumber,
    this.isReplayed = false,
    this.counter,
  });

  factory InvoiceCreationResult.fromMap(Map<String, dynamic> map) {
    return InvoiceCreationResult(
      id: map['id']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      isReplayed: map['idempotent_replayed'] == true,
      counter: (map['counter'] as num?)?.toInt(),
    );
  }
}
