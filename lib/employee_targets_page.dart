import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// ===============================================================
// =============== UTILITIES CLASS ===============================
// ===============================================================

class FinanceUtils {
  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

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
                          'PT NAMA PERUSAHAAN',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Invoice Bonus Karyawan',
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
                      FinanceUtils.buildPDFRow(
                        'Target',
                        targetData['title'] ?? 'N/A',
                      ),
                      FinanceUtils.buildPDFRow(
                        'Periode',
                        targetData['period'] ?? 'N/A',
                      ),
                      FinanceUtils.buildPDFRow(
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
                  requestData['status'] == 'paid'
                      ? 'Status: DIBAYAR'
                      : 'Status: DISETUJUI - Menunggu Pencairan',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: requestData['status'] == 'paid'
                        ? PdfColors.green700
                        : PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(paidAt)}',
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

  // FUNCTION YANG HILANG - IMPLEMENTASI LENGKAP
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
      case 'SP1':
        levelColor = PdfColors.orange;
        break;
      case 'SP2':
        levelColor = PdfColors.deepOrange;
        break;
      case 'SP3':
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
                          'PT NAMA PERUSAHAAN',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Divisi Human Resources',
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
                  'Tanggal Terbit: ${DateFormat('dd MMMM yyyy', 'id_ID').format(issuedAt)}',
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

// ===============================================================
// =============== PAGE UTAMA ====================================
// ===============================================================

class EmployeeTargetsPage extends StatefulWidget {
  const EmployeeTargetsPage({super.key});

  @override
  State<EmployeeTargetsPage> createState() => _EmployeeTargetsPageState();
}

class _EmployeeTargetsPageState extends State<EmployeeTargetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String currentUserUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Target Kinerja Saya"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Target Aktif"),
            Tab(text: "Riwayat"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TargetListView(
            statuses: const [
              'active',
              'submitted',
              'bonus_pending',
              'bonus_approved',
            ],
            currentUserUid: currentUserUid,
          ),
          TargetListView(
            statuses: const ['evaluated', 'paid'],
            currentUserUid: currentUserUid,
          ),
        ],
      ),
    );
  }
}

class TargetListView extends StatelessWidget {
  final List<String> statuses;
  final String currentUserUid;

  const TargetListView({
    Key? key,
    required this.statuses,
    required this.currentUserUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('targets')
          .where('employeeId', isEqualTo: currentUserUid)
          .where('status', whereIn: statuses)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Tidak ada data target untuk kategori ini.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final targets = snapshot.data!.docs;

        // Sort di client-side untuk menghindari composite index
        targets.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate =
              (aData['startDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bDate =
              (bData['startDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bDate.compareTo(aDate); // Descending
        });

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: targets.length,
          itemBuilder: (context, index) {
            final targetData = targets[index].data() as Map<String, dynamic>;
            final targetId = targets[index].id;
            return TargetCard(
              targetId: targetId,
              targetData: targetData,
              currentUserUid: currentUserUid,
            );
          },
        );
      },
    );
  }
}

class TargetCard extends StatelessWidget {
  final String targetId;
  final Map<String, dynamic> targetData;
  final String currentUserUid;

  const TargetCard({
    Key? key,
    required this.targetId,
    required this.targetData,
    required this.currentUserUid,
  }) : super(key: key);

  Future<void> _showInputHasilDialog(BuildContext context) async {
    final hasilController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Input Hasil Kerja"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: hasilController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hasil Pencapaian'),
            validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final achievedValue = int.tryParse(hasilController.text);
                if (achievedValue != null) {
                  _saveSubmission(context, achievedValue);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSubmission(BuildContext context, int achievedValue) async {
    final firestore = FirebaseFirestore.instance;
    final submissionDate = DateTime.now();

    final deadline = (targetData['deadline'] as Timestamp?)?.toDate();
    bool isLate = false;
    if (deadline != null && submissionDate.isAfter(deadline)) {
      isLate = true;
    }

    await firestore.collection('performance_submissions').add({
      'targetId': targetId,
      'employeeId': currentUserUid,
      'achievedValue': achievedValue,
      'submissionDate': Timestamp.now(),
      'status': 'submitted',
      'isLate': isLate,
      'deadline': targetData['deadline'],
    });
    await firestore.collection('targets').doc(targetId).update({
      'status': 'submitted',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLate
                ? '⚠️ Hasil kerja dikirim (TERLAMBAT)'
                : '✅ Hasil kerja berhasil dikirim!',
          ),
          backgroundColor: isLate ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<DocumentSnapshot?> _getEvaluationResult() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('performance_submissions')
        .where('targetId', isEqualTo: targetId)
        .where('employeeId', isEqualTo: currentUserUid)
        .get(); // ❌ HAPUS .orderBy() dan .limit()

    if (querySnapshot.docs.isNotEmpty) {
      // ✅ Sort di client-side dan ambil yang terakhir
      final docs = querySnapshot.docs;
      docs.sort((a, b) {
        final aDate =
            (a.data()['submissionDate'] as Timestamp?)?.toDate() ??
            DateTime(1970);
        final bDate =
            (b.data()['submissionDate'] as Timestamp?)?.toDate() ??
            DateTime(1970);
        return bDate.compareTo(aDate); // Descending
      });
      return docs.first; // Yang paling baru
    }
    return null;
  }

  Future<void> _downloadInvoice(
    BuildContext context,
    Map<String, dynamic> bonusData,
  ) async {
    try {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(width: 16),
              Text("Membuat Invoice PDF..."),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final submissionDoc = await FirebaseFirestore.instance
          .collection('performance_submissions')
          .doc(bonusData['submissionId'])
          .get();

      final targetDoc = await FirebaseFirestore.instance
          .collection('targets')
          .doc(bonusData['targetId'])
          .get();

      final employeeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      final submissionData = submissionDoc.data() ?? {};
      final targetData = targetDoc.data() ?? {};
      final employeeName = employeeDoc.data()?['fullName'] ?? 'Karyawan';

      final pdfBytes = await FinanceUtils.generateInvoicePdf(
        requestData: bonusData,
        employeeName: employeeName,
        submissionData: submissionData,
        targetData: targetData,
      );

      scaffold.hideCurrentSnackBar();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              title: 'Invoice Bonus',
              filename:
                  'invoice_bonus_${bonusData['invoiceNumber'] ?? 'N/A'}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal membuat/mengunduh invoice: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = targetData['status'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              targetData['title'] ?? 'Tanpa Judul',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${targetData['targetValue']} ${targetData['unit']} | Periode: ${targetData['period']}'
                  .toUpperCase(),
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (targetData.containsKey('deadline') &&
                targetData['deadline'] != null) ...[
              const SizedBox(height: 8),
              _buildDeadlineInfo(targetData['deadline'] as Timestamp),
            ],
            const Divider(height: 24),

            if (status == 'active')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showInputHasilDialog(context),
                  child: const Text('Input Hasil Kerja'),
                ),
              )
            else if (status == 'submitted') ...[
              _buildStatusChip("Menunggu Evaluasi HR", Colors.amber),
              const SizedBox(height: 8),
              _buildEvaluationResultRealtime(targetId),
            ] else if (status == 'bonus_pending') ...[
              _buildStatusChip("Menunggu Persetujuan Keuangan", Colors.orange),
              const SizedBox(height: 8),
              _buildBonusStatusWidget(targetId),
            ] else if (status == 'bonus_approved') ...[
              _buildStatusChip("Bonus Disetujui Keuangan", Colors.green),
              const SizedBox(height: 8),
              _buildBonusStatusWidget(targetId),
            ] else if (status == 'paid' || status == 'evaluated')
              _buildEvaluationResultStatic(targetId),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationResultRealtime(String targetId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('performance_submissions')
          .where('targetId', isEqualTo: targetId)
          .where('employeeId', isEqualTo: currentUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final data =
            snapshot.data!.docs.last.data() as Map<String, dynamic>? ?? {};
        final evalResult = data['evaluationResult'];
        final status = data['status'];

        if (status == 'submitted') {
          return const SizedBox();
        }

        if (status == 'bonus_pending' ||
            status == 'bonus_approved' ||
            status == 'paid') {
          return _buildBonusStatusWidget(targetId);
        }

        if (evalResult == null) return const SizedBox();

        final resultStatus = evalResult['status'] ?? 'N/A';
        final resultMessage = evalResult['message'] ?? 'Tidak ada catatan.';

        Color color;
        switch (resultStatus.toUpperCase()) {
          case 'FEEDBACK':
            color = Colors.blue;
            break;
          case 'SP1':
          case 'SP2':
          case 'SP3':
            color = Colors.red;
            break;
          default:
            color = Colors.grey;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusChip("Hasil: $resultStatus", color),
            const SizedBox(height: 12),
            Text(
              "Catatan HR:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                resultMessage,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEvaluationResultStatic(String targetId) {
    return FutureBuilder<DocumentSnapshot?>(
      future: _getEvaluationResult(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatusChip("Memuat Hasil...", Colors.grey);
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildStatusChip("Hasil evaluasi tidak ditemukan", Colors.red);
        }

        final evalData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final status = evalData['status'];
        final evalResult =
            evalData['evaluationResult'] as Map<String, dynamic>?;

        if (status == 'paid') {
          return _buildBonusStatusWidget(targetId);
        }

        if (evalResult == null || evalResult.isEmpty) {
          return _buildStatusChip("Terverifikasi (No Result)", Colors.green);
        }

        final resultStatus = evalResult['status'] ?? 'N/A';

        Color statusColor;
        switch (resultStatus.toUpperCase()) {
          case 'BONUS':
          case 'DITOLAK':
            return _buildBonusStatusWidget(targetId);
          case 'FEEDBACK':
            statusColor = Colors.blue;
            break;
          case 'SP1':
          case 'SP2':
          case 'SP3':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.grey;
        }

        final resultMessage = evalResult['message'] ?? 'Tidak ada catatan.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusChip("✅ Terverifikasi", Colors.green),
            const SizedBox(height: 8),
            _buildStatusChip("Hasil: $resultStatus", statusColor),
            const SizedBox(height: 12),
            const Text(
              "Catatan dari HR:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                resultMessage,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            if (['SP1', 'SP2', 'SP3'].contains(resultStatus.toUpperCase()))
              _buildSPStatusWidget(snapshot.data!.id, resultStatus),
          ],
        );
      },
    );
  }

  Widget _buildBonusStatusWidget(String targetId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bonus_requests')
          .where('targetId', isEqualTo: targetId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final bonusData =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final status = bonusData['status'];
        final submissionId = snapshot.data!.docs.first.id;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          child: _buildBonusCard(bonusData, status, submissionId),
        );
      },
    );
  }

  Widget _buildBonusCard(
    Map<String, dynamic> bonusData,
    String status,
    String requestId,
  ) {
    switch (status) {
      case 'pending':
        return _buildBonusPendingCard(bonusData);
      case 'approved':
        return _buildBonusApprovedCard(bonusData);
      case 'paid':
        return _buildBonusPaidCard(bonusData);
      case 'rejected':
        return _buildBonusRejectedCard(bonusData);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBonusApprovedCard(Map<String, dynamic> bonusData) {
    final bonusAmount = bonusData['bonusAmount'] ?? 0;
    final approvedAt = (bonusData['approvedAt'] as Timestamp?)?.toDate();

    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[300]!, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "✅ Bonus Disetujui",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      if (approvedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(approvedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Nominal Disetujui:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    FinanceUtils.formatCurrency(bonusAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _downloadInvoice(context, bonusData),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text("Lihat Invoice Persetujuan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusPaidCard(Map<String, dynamic> bonusData) {
    final bonusAmount = bonusData['bonusAmount'] ?? 0;
    final paidAt = (bonusData['paidAt'] as Timestamp?)?.toDate();

    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[300]!, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "💰 Bonus Telah Dibayar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      if (paidAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(paidAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Nominal Bonus:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    FinanceUtils.formatCurrency(bonusAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _downloadInvoice(context, bonusData),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text("Download Bukti Pembayaran (Invoice)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusPendingCard(Map<String, dynamic> bonusData) {
    final requestDate = (bonusData['requestDate'] as Timestamp?)?.toDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🕐 Bonus Sedang Diajukan",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    if (requestDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(requestDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Menunggu persetujuan dari Keuangan",
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusRejectedCard(Map<String, dynamic> bonusData) {
    final reason = bonusData['rejectionReason'] ?? 'Tidak ada alasan';
    final rejectedAt = (bonusData['rejectedAt'] as Timestamp?)?.toDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "❌ Bonus Ditolak",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    if (rejectedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(rejectedAt),
                        style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      "Alasan Penolakan:",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Ditolak oleh: Tim Keuangan",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSPStatusWidget(String submissionId, String level) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('warning_letters')
          .where('submissionId', isEqualTo: submissionId)
          .where('level', isEqualTo: level)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final spData = snapshot.data!.docs.first.data() as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          child: _buildSPCard(spData),
        );
      },
    );
  }

  Widget _buildSPCard(Map<String, dynamic> spData) {
    final level = spData['level'] ?? 'SP';
    final message = spData['message'] ?? 'Tidak ada catatan';
    final issuedAt = (spData['issuedAt'] as Timestamp?)?.toDate();

    Color color;
    switch (level) {
      case 'SP1':
        color = Colors.orange;
        break;
      case 'SP2':
        color = Colors.deepOrange;
        break;
      case 'SP3':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "⚠️ Surat Peringatan $level",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (issuedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(issuedAt),
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(
                        "Catatan:",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _downloadWarningLetter(context, spData),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text("Download Surat SP"),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadWarningLetter(
    BuildContext context,
    Map<String, dynamic> spData,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Membuat surat peringatan..."),
          duration: Duration(seconds: 1),
        ),
      );

      final submissionDoc = await FirebaseFirestore.instance
          .collection('performance_submissions')
          .doc(spData['submissionId'])
          .get();

      final targetDoc = await FirebaseFirestore.instance
          .collection('targets')
          .doc(spData['targetId'])
          .get();

      final employeeDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      final submissionData = submissionDoc.data() ?? {};
      final targetData = targetDoc.data() ?? {};
      final employeeName = employeeDoc.data()?['fullName'] ?? 'Karyawan';

      final pdfBytes = await FinanceUtils.generateWarningLetterPdf(
        warningLetter: spData,
        employeeName: employeeName,
        submissionData: submissionData,
        targetData: targetData,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              title: 'Surat Peringatan ${spData['level']}',
              filename: 'sp_${spData['letterNumber'] ?? 'N/A'}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDeadlineInfo(Timestamp deadlineTimestamp) {
    final deadline = deadlineTimestamp.toDate();
    final now = DateTime.now();
    final difference = deadline.difference(now);

    String deadlineText;
    Color deadlineColor;
    IconData deadlineIcon;

    if (difference.isNegative) {
      deadlineText = '⚠️ Deadline: ${_formatDate(deadline)} (LEWAT)';
      deadlineColor = Colors.red;
      deadlineIcon = Icons.warning;
    } else if (difference.inDays == 0) {
      deadlineText = '⏰ Deadline: HARI INI (${_formatDate(deadline)})';
      deadlineColor = Colors.orange;
      deadlineIcon = Icons.today;
    } else if (difference.inDays <= 3) {
      deadlineText =
          '⏳ Deadline: ${_formatDate(deadline)} (${difference.inDays} hari lagi)';
      deadlineColor = Colors.orange;
      deadlineIcon = Icons.access_time;
    } else {
      deadlineText = '📅 Deadline: ${_formatDate(deadline)}';
      deadlineColor = Colors.blue;
      deadlineIcon = Icons.event;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: deadlineColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: deadlineColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(deadlineIcon, size: 16, color: deadlineColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              deadlineText,
              style: TextStyle(
                color: deadlineColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ===============================================================
// =============== PDF PREVIEW PAGE ==============================
// ===============================================================

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
