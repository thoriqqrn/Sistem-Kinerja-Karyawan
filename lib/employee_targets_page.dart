import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/finance_utils.dart';
import 'widgets/pdf_preview_page.dart';
import 'daily_progress_input_page.dart';

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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Target Kinerja Saya',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFFFF6B9D),
              unselectedLabelColor: Color(0xFF9CA3AF),
              indicatorColor: Color(0xFFFF6B9D),
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: "Target Aktif"),
                Tab(text: "Riwayat"),
              ],
            ),
          ),
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

            // Progress Bar (untuk semua status kecuali evaluated/paid)
            if (status != 'evaluated' && status != 'paid') ...[
              const SizedBox(height: 16),
              _buildProgressBar(),
            ],

            const Divider(height: 24),

            if (status == 'active') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DailyProgressInputPage(
                              targetId: targetId,
                              targetData: targetData,
                            ),
                          ),
                        );
                      },
                      label: const Text('Input Harian'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      onPressed: () => _showInputHasilDialog(context),
                      label: const Text('Kirim Final'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'submitted') ...[
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

  Widget _buildProgressBar() {
    final targetValue = targetData['targetValue'] as int;
    final unit = targetData['unit'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: targetId)
          .where('employeeId', isEqualTo: currentUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalProgress = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            totalProgress +=
                (doc.data() as Map<String, dynamic>)['dailyValue'] as int? ?? 0;
          }
        }

        final percentage = targetValue > 0
            ? (totalProgress / targetValue) * 100
            : 0;
        final remaining = targetValue - totalProgress;

        // Hitung sisa hari
        final deadline = targetData['deadline'] as Timestamp?;
        int remainingDays = 0;
        if (deadline != null) {
          remainingDays = deadline.toDate().difference(DateTime.now()).inDays;
        }

        final dailyTarget = remainingDays > 0 && remaining > 0
            ? (remaining / remainingDays).ceil()
            : 0;

        // Determine status color
        Color progressColor;
        String statusText;

        if (percentage >= 75) {
          progressColor = Colors.green;
          statusText = 'Excellent! 🌟';
        } else if (percentage >= 50) {
          progressColor = Colors.blue;
          statusText = 'On Track ✓';
        } else if (percentage >= 25) {
          progressColor = Colors.orange;
          statusText = 'Perlu Ditingkatkan ⚡';
        } else {
          progressColor = Colors.red;
          statusText = 'Perlu Fokus! 🔥';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progress Harian',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalProgress / $targetValue $unit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}% tercapai',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (remainingDays > 0 && remaining > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: progressColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$dailyTarget $unit/hari',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                          Text(
                            'target harian',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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
