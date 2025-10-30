// lib/utils/finance_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'constants.dart';

/// Utility class untuk fungsi-fungsi Finance
class FinanceUtils {
  /// Format angka ke mata uang Rupiah
  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Format tanggal dan waktu
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  /// Format tanggal saja (tanpa waktu)
  static String formatDateOnly(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  /// Format tanggal lengkap untuk PDF
  static String formatDateFull(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  /// Build row untuk PDF
  static pw.Widget buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Generate Invoice PDF untuk bonus
  static Future<Uint8List> generateInvoicePdf({
    required Map<String, dynamic> requestData,
    required String employeeName,
    required Map<String, dynamic> submissionData,
    required Map<String, dynamic> targetData,
  }) async {
    final pdf = pw.Document();
    final bonusAmount = requestData['bonusAmount'] ?? 0;
    final invoiceNumber =
        requestData['invoiceNumber'] ??
        'INV-${DateTime.now().millisecondsSinceEpoch}';

    final paidAt = requestData['paidAt'] != null
        ? (requestData['paidAt'] as Timestamp).toDate()
        : requestData['approvedAt'] != null
        ? (requestData['approvedAt'] as Timestamp).toDate()
        : DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          CompanyInfo.name,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          CompanyInfo.invoiceTitle,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          invoiceNumber,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 24),
                pw.Text(
                  'Kepada:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(employeeName, style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ID Karyawan: ${requestData['employeeId']}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Detail Bonus',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      buildPDFRow('Target', targetData['title'] ?? 'N/A'),
                      buildPDFRow('Periode', targetData['period'] ?? 'N/A'),
                      buildPDFRow(
                        'Pencapaian',
                        '${submissionData['achievedValue']} / ${targetData['targetValue']} ${targetData['unit'] ?? ''}',
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL BONUS:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            formatCurrency(bonusAmount),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  requestData['status'] == BonusStatus.paid
                      ? 'Status: DIBAYAR'
                      : 'Status: DISETUJUI - Menunggu Pencairan',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: requestData['status'] == BonusStatus.paid
                        ? PdfColors.green700
                        : PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Tanggal: ${formatDateFull(paidAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Terima kasih atas kontribusi Anda!',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Warning Letter PDF untuk SP
  static Future<Uint8List> generateWarningLetterPdf({
    required Map<String, dynamic> warningLetter,
    required String employeeName,
    required Map<String, dynamic> submissionData,
    required Map<String, dynamic> targetData,
  }) async {
    final pdf = pw.Document();
    final level = warningLetter['level'] ?? 'SP';
    final message = warningLetter['message'] ?? 'Tidak ada catatan';
    final letterNumber =
        warningLetter['letterNumber'] ??
        'SP-${DateTime.now().millisecondsSinceEpoch}';
    final issuedAt = warningLetter['issuedAt'] != null
        ? (warningLetter['issuedAt'] as Timestamp).toDate()
        : DateTime.now();

    // Tentukan warna berdasarkan level
    PdfColor levelColor;
    switch (level) {
      case WarningLevel.sp1:
        levelColor = PdfColors.orange;
        break;
      case WarningLevel.sp2:
        levelColor = PdfColors.deepOrange;
        break;
      case WarningLevel.sp3:
        levelColor = PdfColors.red;
        break;
      default:
        levelColor = PdfColors.grey;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          CompanyInfo.name,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          CompanyInfo.hrDivision,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SURAT PERINGATAN',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          letterNumber,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 24),

                // Level SP
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: levelColor.shade(0.1),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      level,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),

                // Kepada
                pw.Text(
                  'Kepada:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(employeeName, style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ID Karyawan: ${warningLetter['employeeId']}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 32),

                // Detail Target
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Detail Kinerja',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      buildPDFRow('Target', targetData['title'] ?? 'N/A'),
                      buildPDFRow('Periode', targetData['period'] ?? 'N/A'),
                      buildPDFRow(
                        'Target',
                        '${targetData['targetValue']} ${targetData['unit'] ?? ''}',
                      ),
                      buildPDFRow(
                        'Pencapaian',
                        '${submissionData['achievedValue']} ${targetData['unit'] ?? ''}',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Catatan
                pw.Text(
                  'Catatan:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    message,
                    style: const pw.TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Text(
                  'Tanggal Terbit: ${formatDateFull(issuedAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 32),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Hormat Kami,',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.SizedBox(height: 40),
                        pw.Text(
                          'Human Resources Department',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
