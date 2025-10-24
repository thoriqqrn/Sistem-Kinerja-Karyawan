import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'login_page.dart';
import 'bonus_report_page.dart'; // Import halaman laporan
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Keuangan"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Laporan Bonus',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BonusReportPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: "Permintaan Bonus"),
            Tab(icon: Icon(Icons.check_circle), text: "Disetujui"),
            Tab(icon: Icon(Icons.history), text: "Riwayat"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BonusRequestListView(status: 'pending'),
          BonusRequestListView(status: 'approved'),
          BonusRequestListView(status: 'paid'),
        ],
      ),
    );
  }
}

// ===============================================================
// =============== LIST VIEW BONUS REQUESTS ======================
// ===============================================================

class BonusRequestListView extends StatelessWidget {
  final String status;
  const BonusRequestListView({Key? key, required this.status})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bonus_requests')
          .where('status', isEqualTo: status)
          .orderBy('requestDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Terjadi kesalahan: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.inbox
                      : status == 'approved'
                      ? Icons.check_circle_outline
                      : Icons.history,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? "Tidak ada permintaan bonus baru"
                      : status == 'approved'
                      ? "Belum ada bonus yang disetujui"
                      : "Belum ada riwayat pembayaran",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;
            return BonusRequestCard(
              requestId: requestId,
              requestData: requestData,
              status: status,
            );
          },
        );
      },
    );
  }
}

// ===============================================================
// =============== CARD BONUS REQUEST ============================
// ===============================================================

class BonusRequestCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final String status;

  const BonusRequestCard({
    Key? key,
    required this.requestId,
    required this.requestData,
    required this.status,
  }) : super(key: key);

  Future<Map<String, dynamic>> _getEmployeeData() async {
    final employeeDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(requestData['employeeId'])
        .get();

    final submissionDoc = await FirebaseFirestore.instance
        .collection('performance_submissions')
        .doc(requestData['submissionId'])
        .get();

    final targetDoc = await FirebaseFirestore.instance
        .collection('targets')
        .doc(requestData['targetId'])
        .get();

    return {
      'employeeName': employeeDoc.data()?['fullName'] ?? 'Unknown',
      'submissionData': submissionDoc.data() ?? {},
      'targetData': targetDoc.data() ?? {},
    };
  }

  @override
  Widget build(BuildContext context) {
    final requestDate =
        (requestData['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getEmployeeData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.red[50],
            child: ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text("Gagal memuat data"),
              subtitle: Text(snapshot.error.toString()),
            ),
          );
        }

        final employeeData = snapshot.data!;
        final employeeName = employeeData['employeeName'] as String;
        final submissionData =
            employeeData['submissionData'] as Map<String, dynamic>;
        final targetData = employeeData['targetData'] as Map<String, dynamic>;

        final int target = targetData['targetValue'] ?? 0;
        final int achieved = submissionData['achievedValue'] ?? 0;
        final double percentage = target > 0 ? (achieved / target) * 100 : 0;

        Color statusColor;
        IconData statusIcon;
        String statusText;

        switch (status) {
          case 'pending':
            statusColor = Colors.orange;
            statusIcon = Icons.pending_actions;
            statusText = 'Menunggu Persetujuan';
            break;
          case 'approved':
            statusColor = Colors.blue;
            statusIcon = Icons.check_circle;
            statusText = 'Disetujui';
            break;
          case 'paid':
            statusColor = Colors.green;
            statusIcon = Icons.payment;
            statusText = 'Sudah Dibayar';
            break;
          default:
            statusColor = Colors.grey;
            statusIcon = Icons.help;
            statusText = 'Unknown';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BonusDetailPage(
                    requestId: requestId,
                    requestData: requestData,
                    employeeName: employeeName,
                    submissionData: submissionData,
                    targetData: targetData,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Nama & Status
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: statusColor.withOpacity(0.2),
                        child: Icon(Icons.person, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(statusIcon, size: 16, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (requestData['bonusAmount'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Text(
                            _formatCurrency(requestData['bonusAmount']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Info Target & Pencapaian
                  _buildInfoRow(
                    Icons.flag,
                    "Target",
                    targetData['title'] ?? 'N/A',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.calendar_today,
                    "Periode",
                    targetData['period'] ?? 'N/A',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.trending_up,
                    "Pencapaian",
                    "$achieved / $target ${targetData['unit'] ?? ''} (${percentage.toStringAsFixed(1)}%)",
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    "Tanggal Permintaan",
                    _formatDate(requestDate),
                  ),

                  // Tampilkan info tambahan jika sudah approved
                  if (status == 'approved' || status == 'paid') ...[
                    const SizedBox(height: 8),
                    if (requestData['approvedAt'] != null)
                      _buildInfoRow(
                        Icons.check,
                        "Disetujui",
                        _formatDate(
                          (requestData['approvedAt'] as Timestamp).toDate(),
                        ),
                      ),
                  ],

                  if (status == 'paid') ...[
                    const SizedBox(height: 8),
                    if (requestData['paidAt'] != null)
                      _buildInfoRow(
                        Icons.payment,
                        "Dibayar",
                        _formatDate(
                          (requestData['paidAt'] as Timestamp).toDate(),
                        ),
                      ),
                    if (requestData['invoiceUrl'] != null)
                      const SizedBox(height: 12),
                    if (requestData['invoiceUrl'] != null)
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Open PDF invoice
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Buka invoice PDF"),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text("Lihat Invoice"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey[800], fontSize: 13),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }
}

// ===============================================================
// =============== HALAMAN DETAIL BONUS ==========================
// ===============================================================

class BonusDetailPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;
  final String employeeName;
  final Map<String, dynamic> submissionData;
  final Map<String, dynamic> targetData;

  const BonusDetailPage({
    Key? key,
    required this.requestId,
    required this.requestData,
    required this.employeeName,
    required this.submissionData,
    required this.targetData,
  }) : super(key: key);

  @override
  State<BonusDetailPage> createState() => _BonusDetailPageState();
}

class _BonusDetailPageState extends State<BonusDetailPage> {
  final _bonusAmountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _bonusAmountController.dispose();
    super.dispose();
  }

  // ===============================================================
  // =============== APPROVE BONUS =================================
  // ===============================================================

  Future<void> _approveBonus() async {
    // Validasi nominal bonus
    if (_bonusAmountController.text.isEmpty) {
      _showError("Silakan masukkan nominal bonus terlebih dahulu");
      return;
    }

    final bonusAmount = int.tryParse(_bonusAmountController.text);
    if (bonusAmount == null || bonusAmount <= 0) {
      _showError("Nominal bonus tidak valid");
      return;
    }

    // Konfirmasi
    final confirm = await _showConfirmDialog(
      "Setujui Bonus",
      "Apakah Anda yakin ingin menyetujui bonus sebesar ${_formatCurrency(bonusAmount)}?",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      // Update bonus request
      await FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId)
          .update({
            'status': 'approved',
            'bonusAmount': bonusAmount,
            'approvedBy': currentUser?.uid ?? 'unknown',
            'approvedAt': Timestamp.now(),
          });

      _showSuccess("✅ Bonus berhasil disetujui!");
      Navigator.pop(context);
    } catch (e) {
      _showError("❌ Gagal menyetujui bonus: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // =============== REJECT BONUS ==================================
  // ===============================================================

  Future<void> _rejectBonus() async {
    final confirm = await _showConfirmDialog(
      "Tolak Permintaan Bonus",
      "Apakah Anda yakin ingin menolak permintaan bonus ini?",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId)
          .update({
            'status': 'rejected',
            'rejectedBy': currentUser?.uid ?? 'unknown',
            'rejectedAt': Timestamp.now(),
          });

      _showSuccess("✅ Permintaan bonus ditolak");
      Navigator.pop(context);
    } catch (e) {
      _showError("❌ Gagal menolak bonus: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // =============== GENERATE PDF & MARK AS PAID ===================
  // ===============================================================

  Future<void> _generateInvoiceAndPay() async {
    final confirm = await _showConfirmDialog(
      "Konfirmasi Pembayaran",
      "Apakah Anda yakin bonus sudah dicairkan? Invoice PDF akan dibuat.",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      // 1. Generate PDF
      final pdfBytes = await _createInvoicePDF();

      // 2. Upload ke Firebase Storage
      final invoiceUrl = await _uploadPDFToStorage(pdfBytes);

      // 3. Update status ke 'paid'
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId)
          .update({
            'status': 'paid',
            'invoiceUrl': invoiceUrl,
            'paidBy': currentUser?.uid ?? 'unknown',
            'paidAt': Timestamp.now(),
          });

      _showSuccess("✅ Pembayaran berhasil dicatat dan invoice dibuat!");
      Navigator.pop(context);
    } catch (e) {
      _showError("❌ Gagal memproses pembayaran: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // =============== CREATE PDF INVOICE ============================
  // ===============================================================

  Future<Uint8List> _createInvoicePDF() async {
    final pdf = pw.Document();
    final bonusAmount = widget.requestData['bonusAmount'] ?? 0;
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

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

                // Info Karyawan
                pw.Text(
                  'Kepada:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  widget.employeeName,
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ID Karyawan: ${widget.requestData['employeeId']}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 32),

                // Detail Bonus
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
                      _buildPDFRow(
                        'Target',
                        widget.targetData['title'] ?? 'N/A',
                      ),
                      _buildPDFRow(
                        'Periode',
                        widget.targetData['period'] ?? 'N/A',
                      ),
                      _buildPDFRow(
                        'Pencapaian',
                        '${widget.submissionData['achievedValue']} / ${widget.targetData['targetValue']} ${widget.targetData['unit'] ?? ''}',
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
                            _formatCurrency(bonusAmount),
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

                // Tanggal
                pw.Text(
                  'Tanggal Pencairan: ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Spacer(),

                // Footer
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

  pw.Widget _buildPDFRow(String label, String value) {
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

  // ===============================================================
  // =============== UPLOAD PDF TO FIREBASE STORAGE ================
  // ===============================================================

  Future<String> _uploadPDFToStorage(Uint8List pdfBytes) async {
    final fileName =
        'invoices/bonus_${widget.requestId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);

    await storageRef.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    return await storageRef.getDownloadURL();
  }

  // ===============================================================
  // =============== HELPER FUNCTIONS ==============================
  // ===============================================================

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Ya, Lanjutkan"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // ===============================================================
  // =============== UI BUILD ======================================
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final status = widget.requestData['status'];
    final int target = widget.targetData['targetValue'] ?? 0;
    final int achieved = widget.submissionData['achievedValue'] ?? 0;
    final double percentage = target > 0 ? (achieved / target) * 100 : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Permintaan Bonus"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Karyawan
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Karyawan:",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            widget.employeeName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Target & Pencapaian
            Card(
              elevation: 2,
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Target Kinerja",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("Judul: ${widget.targetData['title'] ?? 'N/A'}"),
                    Text("Periode: ${widget.targetData['period'] ?? 'N/A'}"),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          "Target",
                          "$target ${widget.targetData['unit'] ?? ''}",
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          "Hasil",
                          "$achieved ${widget.targetData['unit'] ?? ''}",
                          Colors.black87,
                        ),
                        _buildStatColumn(
                          "Pencapaian",
                          "${percentage.toStringAsFixed(1)}%",
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Input Nominal Bonus (hanya untuk status pending)
            if (status == 'pending') ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tentukan Nominal Bonus",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bonusAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nominal Bonus (Rp)',
                          hintText: 'Contoh: 1000000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Masukkan nominal bonus sesuai kebijakan perusahaan",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Aksi untuk Pending
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _approveBonus,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        "Setujui Bonus",
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _rejectBonus,
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text(
                        "Tolak Permintaan",
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            // Info & Tombol untuk Approved
            if (status == 'approved') ...[
              Card(
                elevation: 2,
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Bonus Telah Disetujui",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Nominal Bonus:",
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _formatCurrency(widget.requestData['bonusAmount']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      if (widget.requestData['approvedAt'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Disetujui: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format((widget.requestData['approvedAt'] as Timestamp).toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Generate Invoice & Pay
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _generateInvoiceAndPay,
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: const Text(
                    "Buat Invoice & Konfirmasi Pembayaran",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],

            // Info untuk Paid
            if (status == 'paid') ...[
              Card(
                elevation: 2,
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Bonus Sudah Dibayar",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Nominal Bonus:",
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _formatCurrency(widget.requestData['bonusAmount']),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      if (widget.requestData['paidAt'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Dibayar: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format((widget.requestData['paidAt'] as Timestamp).toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (widget.requestData['invoiceUrl'] != null) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Open PDF
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Invoice URL: ${widget.requestData['invoiceUrl']}",
                                ),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text("Lihat Invoice PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
