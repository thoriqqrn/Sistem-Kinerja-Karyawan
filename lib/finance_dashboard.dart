import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'login_page.dart';
import 'bonus_report_page.dart';
import 'utils/finance_utils.dart';
import 'utils/constants.dart';
import 'widgets/pdf_preview_page.dart';

// ===============================================================
// =============== DASHBOARD UTAMA ===============================
// ===============================================================

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<String> _statusList = ['pending', 'approved', 'paid', 'rejected'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B9D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFFF6B9D),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Finance Dashboard',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.assessment_rounded, color: Color(0xFFFF6B9D)),
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
            icon: Icon(Icons.logout_rounded, color: Color(0xFFFF6B9D)),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: BonusRequestListView(status: _statusList[_currentIndex]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.pending_actions_rounded,
                  label: 'Permintaan',
                  color: Color(0xFFFF6B9D),
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.check_circle_rounded,
                  label: 'Disetujui',
                  color: Color(0xFF3B82F6),
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.payments_rounded,
                  label: 'Dibayar',
                  color: Color(0xFF10B981),
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.cancel_rounded,
                  label: 'Ditolak',
                  color: Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(isSelected ? 8 : 6),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: isSelected ? 24 : 20,
              ),
            ),
            SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: isSelected ? 12 : 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Color(0xFF9CA3AF),
              ),
              child: Text(label),
            ),
          ],
        ),
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
                      : status == 'paid'
                      ? Icons.payment
                      : Icons.cancel,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? "Tidak ada permintaan bonus baru"
                      : status == 'approved'
                      ? "Belum ada bonus yang disetujui"
                      : status == 'paid'
                      ? "Belum ada riwayat pembayaran"
                      : "Tidak ada bonus yang ditolak",
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
          case 'rejected':
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
            statusText = 'Ditolak';
            break;
          default:
            statusColor = Colors.grey;
            statusIcon = Icons.help;
            statusText = 'Unknown';
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Navigasi ke BonusDetailPage
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
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header - Nama & Status
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: statusColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employeeName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
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
                              ),
                            ],
                          ),
                        ),
                        // Tampilkan Nominal Bonus jika sudah ada
                        if (requestData['bonusAmount'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              FinanceUtils.formatCurrency(
                                requestData['bonusAmount'],
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),

                    Divider(height: 24, color: Color(0xFFE8E8E8)),

                    // Info Target & Pencapaian
                    _buildInfoRow(
                      Icons.flag_rounded,
                      "Target",
                      targetData['title'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.calendar_today_rounded,
                      "Periode",
                      targetData['period'] ?? 'N/A',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.trending_up_rounded,
                      "Pencapaian",
                      "$achieved / $target ${targetData['unit'] ?? ''} (${percentage.toStringAsFixed(1)}%)",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.access_time_rounded,
                      "Tanggal Permintaan",
                      FinanceUtils.formatDate(requestDate),
                    ),

                    // Info Tambahan (Approved, Paid, Rejected)
                    if (status == 'approved' || status == 'paid') ...[
                      const SizedBox(height: 8),
                      if (requestData['approvedAt'] != null)
                        _buildInfoRow(
                          Icons.check_circle_rounded,
                          "Disetujui",
                          FinanceUtils.formatDate(
                            (requestData['approvedAt'] as Timestamp).toDate(),
                          ),
                        ),
                    ],

                    if (status == 'paid') ...[
                      const SizedBox(height: 8),
                      if (requestData['paidAt'] != null)
                        _buildInfoRow(
                          Icons.payment_rounded,
                          "Dibayar",
                          FinanceUtils.formatDate(
                            (requestData['paidAt'] as Timestamp).toDate(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Generate dan tampilkan invoice lokal
                          try {
                            final pdfBytes =
                                await FinanceUtils.generateInvoicePdf(
                                  requestData: requestData,
                                  employeeName: employeeName,
                                  submissionData: submissionData,
                                  targetData: targetData,
                                );

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PdfPreviewPage(
                                  pdfBytes: pdfBytes,
                                  title: 'Invoice Bonus - $employeeName',
                                  filename: 'invoice_bonus_$requestId.pdf',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text("Cetak Invoice"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],

                    if (status == 'rejected') ...[
                      const SizedBox(height: 8),
                      if (requestData['rejectedAt'] != null)
                        _buildInfoRow(
                          Icons.cancel,
                          "Ditolak",
                          FinanceUtils.formatDate(
                            (requestData['rejectedAt'] as Timestamp).toDate(),
                          ),
                        ),
                      if (requestData['rejectionReason'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFFEF4444).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Alasan Penolakan:",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                requestData['rejectionReason'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
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
        Icon(icon, size: 18, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Color(0xFF2D3142), fontSize: 13),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: Color(0xFF2D3142)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
  void initState() {
    super.initState();
    // Inisialisasi controller dengan nilai bonus yang sudah ada (jika ada)
    final initialAmount = widget.requestData['bonusAmount'];
    if (initialAmount != null) {
      _bonusAmountController.text = initialAmount.toString();
    }
  }

  @override
  void dispose() {
    _bonusAmountController.dispose();
    super.dispose();
  }

  Future<void> _approveBonus() async {
    if (_bonusAmountController.text.isEmpty) {
      _showError("Silakan masukkan nominal bonus terlebih dahulu");
      return;
    }

    final bonusAmount = int.tryParse(_bonusAmountController.text);
    if (bonusAmount == null || bonusAmount <= 0) {
      _showError("Nominal bonus tidak valid");
      return;
    }

    // Validasi minimal bonus amount
    if (bonusAmount < BonusConfig.minimumAmount) {
      _showError(
        "Nominal bonus minimal adalah ${BonusConfig.minimumAmountFormatted}",
      );
      return;
    }

    final confirm = await _showConfirmDialog(
      "Setujui Bonus",
      "Apakah Anda yakin ingin menyetujui bonus sebesar ${FinanceUtils.formatCurrency(bonusAmount)}?",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      final submissionId = widget.requestData['submissionId'];
      final targetId = widget.requestData['targetId'];

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Bonus Request (status: approved)
      final requestRef = FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId);
      batch.update(requestRef, {
        'status': 'approved',
        'bonusAmount': bonusAmount,
        'approvedBy': currentUser?.uid ?? 'unknown',
        'approvedAt': Timestamp.now(),
      });

      // 2. Update Performance Submissions (Status: bonus_approved untuk Karyawan/HR)
      final submissionRef = FirebaseFirestore.instance
          .collection('performance_submissions')
          .doc(submissionId);
      batch.update(submissionRef, {'status': 'bonus_approved'});

      // 3. Update Targets (Status: bonus_approved untuk Karyawan)
      final targetRef = FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId);
      batch.update(targetRef, {'status': 'bonus_approved'});

      await batch.commit();

      _showSuccess("✅ Bonus berhasil disetujui!");
      Navigator.pop(context);
    } catch (e) {
      _showError("❌ Gagal menyetujui bonus: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectBonus() async {
    final reason = await _showRejectReasonDialog();
    if (reason == null || reason.isEmpty) return;

    final confirm = await _showConfirmDialog(
      "Tolak Permintaan Bonus",
      "Apakah Anda yakin ingin menolak permintaan bonus ini?",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      final submissionId = widget.requestData['submissionId'];
      final targetId = widget.requestData['targetId'];

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Bonus Request (status: rejected)
      final requestRef = FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId);
      batch.update(requestRef, {
        'status': 'rejected',
        'rejectedBy': currentUser?.uid ?? 'unknown',
        'rejectedAt': Timestamp.now(),
        'rejectionReason': reason,
      });

      // 2. Update Performance Submissions (Status: evaluated dengan hasil DITOLAK)
      final submissionRef = FirebaseFirestore.instance
          .collection('performance_submissions')
          .doc(submissionId);
      batch.update(submissionRef, {
        'status': 'evaluated', // Kembalikan ke evaluated/riwayat HR
        'evaluationResult': {
          'status': 'DITOLAK',
          'message': 'Permintaan bonus ditolak oleh Keuangan: $reason',
        },
      });

      // 3. Update Targets (Status: evaluated)
      final targetRef = FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId);
      batch.update(targetRef, {
        'status': 'evaluated', // Kembalikan ke riwayat Karyawan
      });

      await batch.commit();

      _showSuccess("✅ Permintaan bonus ditolak");
      Navigator.pop(context);
    } catch (e) {
      _showError("❌ Gagal menolak bonus: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showRejectReasonDialog() async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Alasan Penolakan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Jelaskan alasan penolakan bonus ini:",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Contoh: Budget bonus bulan ini sudah habis",
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Alasan tidak boleh kosong"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Lanjutkan"),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPreviewInvoice() async {
    final confirm = await _showConfirmDialog(
      "Konfirmasi Pembayaran",
      "Apakah Anda yakin bonus sudah dicairkan? Invoice PDF akan dibuat untuk dicetak/dibagikan.",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final paidAtTimestamp = Timestamp.now();
      final currentUser = FirebaseAuth.instance.currentUser;

      final submissionId = widget.requestData['submissionId'];
      final targetId = widget.requestData['targetId'];
      final invoiceNumber = 'INV-${paidAtTimestamp.millisecondsSinceEpoch}';

      // Ambil data untuk generate PDF
      final updatedRequestData = Map<String, dynamic>.from(widget.requestData)
        ..['status'] = 'paid'
        ..['paidAt'] = paidAtTimestamp
        ..['invoiceNumber'] = invoiceNumber;

      // Generate PDF
      final pdfBytes = await FinanceUtils.generateInvoicePdf(
        requestData: updatedRequestData,
        employeeName: widget.employeeName,
        submissionData: widget.submissionData,
        targetData: widget.targetData,
      );

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Bonus Request (status: paid)
      final requestRef = FirebaseFirestore.instance
          .collection('bonus_requests')
          .doc(widget.requestId);
      batch.update(requestRef, {
        'status': BonusStatus.paid,
        'paidBy': currentUser?.uid ?? 'unknown',
        'paidAt': paidAtTimestamp,
        'invoiceNumber': invoiceNumber,
        'invoiceGenerated': true, // Flag untuk laporan bonus
      });

      // 2. Update Performance Submissions (Status: paid)
      final submissionRef = FirebaseFirestore.instance
          .collection('performance_submissions')
          .doc(submissionId);
      batch.update(submissionRef, {'status': SubmissionStatus.paid});

      // 3. Update Targets (Status: paid)
      final targetRef = FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId);
      batch.update(targetRef, {'status': TargetStatus.paid});

      await batch.commit();

      setState(() => _isLoading = false);

      if (mounted) {
        await _showPdfPreview(pdfBytes);
        _showSuccess("✅ Pembayaran berhasil dicatat!");
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("❌ Gagal memproses pembayaran: $e");
    }
  }

  Future<void> _regenerateInvoice() async {
    setState(() => _isLoading = true);

    try {
      final pdfBytes = await FinanceUtils.generateInvoicePdf(
        requestData: widget.requestData,
        employeeName: widget.employeeName,
        submissionData: widget.submissionData,
        targetData: widget.targetData,
      );
      setState(() => _isLoading = false);

      await _showPdfPreview(pdfBytes);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("❌ Gagal membuat invoice: $e");
    }
  }

  Future<void> _showPdfPreview(Uint8List pdfBytes) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          pdfBytes: pdfBytes,
          title: 'Invoice Bonus - ${widget.employeeName}',
          filename: 'invoice_bonus_${widget.requestId}.pdf',
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final status = widget.requestData['status'];
    final int target = widget.targetData['targetValue'] ?? 0;
    final int achieved = widget.submissionData['achievedValue'] ?? 0;
    final double percentage = target > 0 ? (achieved / target) * 100 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Detail Permintaan Bonus",
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Karyawan
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Karyawan:",
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.employeeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3142),
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B9D).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.flag_outlined,
                            color: Color(0xFFFF6B9D),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Target Kinerja",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Judul: ${widget.targetData['title'] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Periode: ${widget.targetData['period'] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFFE8E8E8)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          "Target",
                          "$target ${widget.targetData['unit'] ?? ''}",
                          const Color(0xFFFF6B9D),
                        ),
                        _buildStatColumn(
                          "Hasil",
                          "$achieved ${widget.targetData['unit'] ?? ''}",
                          const Color(0xFF2D3142),
                        ),
                        _buildStatColumn(
                          "Pencapaian",
                          "${percentage.toStringAsFixed(1)}%",
                          const Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Aksi: Pending
            if (status == 'pending') ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B9D).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: Color(0xFFFF6B9D),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Tentukan Nominal Bonus",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bonusAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2D3142),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nominal Bonus (Rp)',
                          labelStyle: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                          hintText:
                              'Minimal ${BonusConfig.minimumAmountFormatted}',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8E8E8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8E8E8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B9D),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.monetization_on_outlined,
                            color: Color(0xFFFF6B9D),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Minimal bonus: ${BonusConfig.minimumAmountFormatted}. Sesuaikan dengan kebijakan perusahaan.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6B9D),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _approveBonus,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Setujui Bonus",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _rejectBonus,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Color(0xFFEF5350),
                      ),
                      label: const Text(
                        "Tolak Permintaan",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFEF5350),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFEF5350),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            // Card Aksi: Approved
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
                            FinanceUtils.formatCurrency(
                              widget.requestData['bonusAmount'],
                            ),
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
                          "Disetujui: ${FinanceUtils.formatDate((widget.requestData['approvedAt'] as Timestamp).toDate())}",
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _generateAndPreviewInvoice,
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

            // Card Aksi: Paid
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
                            FinanceUtils.formatCurrency(
                              widget.requestData['bonusAmount'],
                            ),
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
                          "Dibayar: ${FinanceUtils.formatDate((widget.requestData['paidAt'] as Timestamp).toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          onPressed: _regenerateInvoice,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text("Cetak/Bagikan Invoice"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Card Aksi: Rejected
            if (status == 'rejected') ...[
              Card(
                elevation: 2,
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Bonus Ditolak",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (widget.requestData['rejectedAt'] != null) ...[
                        Text(
                          "Ditolak: ${FinanceUtils.formatDate((widget.requestData['rejectedAt'] as Timestamp).toDate())}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.requestData['rejectionReason'] != null) ...[
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
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.red[700],
                                  ),
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
                                widget.requestData['rejectionReason'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                  height: 1.4,
                                ),
                              ),
                            ],
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
