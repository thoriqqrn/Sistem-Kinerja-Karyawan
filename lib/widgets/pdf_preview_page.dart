// lib/widgets/pdf_preview_page.dart

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

/// Widget untuk preview dan share PDF
class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const PdfPreviewPage({
    Key? key,
    required this.pdfBytes,
    required this.title,
    required this.filename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B9D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0xFFFF6B9D)),
              tooltip: 'Bagikan PDF',
              onPressed: () async {
                await Printing.sharePdf(bytes: pdfBytes, filename: filename);
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B9D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.print_outlined, color: Color(0xFFFF6B9D)),
              tooltip: 'Print PDF',
              onPressed: () async {
                await Printing.layoutPdf(onLayout: (format) => pdfBytes);
              },
            ),
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: PdfPreview(
            build: (format) => pdfBytes,
            allowSharing: true,
            allowPrinting: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: filename,
          ),
        ),
      ),
    );
  }
}
