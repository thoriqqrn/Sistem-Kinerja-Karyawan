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
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.red[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan PDF',
            onPressed: () async {
              await Printing.sharePdf(bytes: pdfBytes, filename: filename);
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
            onPressed: () async {
              await Printing.layoutPdf(onLayout: (format) => pdfBytes);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: filename,
      ),
    );
  }
}
