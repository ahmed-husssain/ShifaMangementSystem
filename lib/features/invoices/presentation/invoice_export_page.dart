import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../domain/invoice_model.dart';
import '../utils/invoice_exporter.dart';
import '../data/invoice_repository.dart';

class InvoiceExportPage extends ConsumerWidget {
  final Invoice invoice;

  const InvoiceExportPage({super.key, required this.invoice});

  Future<void> _exportFile(BuildContext context, WidgetRef ref, String format) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Saving ${format.toUpperCase()} invoice... Please wait'),
              ],
            ),
            backgroundColor: const Color(0xFF004B93),
            duration: const Duration(seconds: 15),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Uint8List bytes;
      String extension;
      final invoiceNum = invoice.invoiceNumber.isNotEmpty
          ? invoice.invoiceNumber
          : (invoice.invoiceId.length > 8 ? invoice.invoiceId.substring(0, 8) : invoice.invoiceId);
      final fileName = 'invoice_$invoiceNum';

      if (format == 'pdf') {
        bytes = await InvoiceExporter.generatePdf(invoice);
        extension = 'pdf';
      } else if (format == 'png') {
        bytes = await InvoiceExporter.generateImage(invoice, isPng: true);
        extension = 'png';
      } else if (format == 'jpeg' || format == 'jpg') {
        bytes = await InvoiceExporter.generateImage(invoice, isPng: false);
        extension = 'jpg';
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        return;
      }

      final fullFileName = '$fileName.$extension';

      final result = await InvoiceExporter.saveInvoiceToDevice(
        bytes: bytes,
        fullFileName: fullFileName,
        format: format,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? const Color(0xFF16A34A) : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );

        ref.invalidate(staffInvoicesProvider);
        ref.invalidate(allInvoicesProvider(false));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final pdfBytes = await InvoiceExporter.generatePdf(invoice);
      final invoiceNum = invoice.invoiceNumber.isNotEmpty
          ? invoice.invoiceNumber
          : (invoice.invoiceId.length > 8 ? invoice.invoiceId.substring(0, 8) : invoice.invoiceId);
      final fullFileName = 'invoice_$invoiceNum.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fullFileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportFile(context, ref, 'pdf'),
          ),
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Export PNG',
            onPressed: () => _exportFile(context, ref, 'png'),
          ),
          IconButton(
            icon: const Icon(Icons.photo),
            tooltip: 'Export JPEG',
            onPressed: () => _exportFile(context, ref, 'jpeg'),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Invoice',
            onPressed: () => _shareFile(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => InvoiceExporter.generatePdf(invoice),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false, // Force A4
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
