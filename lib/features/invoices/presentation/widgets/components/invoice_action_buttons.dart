import 'package:flutter/material.dart';

class InvoiceActionButtons extends StatelessWidget {
  final VoidCallback onPrint;
  final VoidCallback onPdf;
  final VoidCallback onPng;
  final VoidCallback onJpg;

  const InvoiceActionButtons({
    super.key,
    required this.onPrint,
    required this.onPdf,
    required this.onPng,
    required this.onJpg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildButton('PRINT', const Color(0xFF1565C0), Icons.print, onPrint),
        const SizedBox(width: 8),
        _buildButton('PDF', const Color(0xFFE53935), Icons.picture_as_pdf, onPdf),
        const SizedBox(width: 8),
        _buildButton('PNG', const Color(0xFF43A047), Icons.image, onPng),
        const SizedBox(width: 8),
        _buildButton('JPG', const Color(0xFFFB8C00), Icons.photo, onJpg),
      ],
    );
  }

  Widget _buildButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
      ),
    );
  }
}
