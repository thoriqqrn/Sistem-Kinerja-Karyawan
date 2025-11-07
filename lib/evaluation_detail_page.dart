import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EvaluationDetailPage extends StatefulWidget {
  final String submissionId;
  final Map<String, dynamic> submissionData;
  final Map<String, dynamic> targetData;
  final String employeeName;

  const EvaluationDetailPage({
    Key? key,
    required this.submissionId,
    required this.submissionData,
    required this.targetData,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<EvaluationDetailPage> createState() => _EvaluationDetailPageState();
}

class _EvaluationDetailPageState extends State<EvaluationDetailPage> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // ===============================================================
  // =============== FUNGSI-FUNGSI UTAMA HR =========================
  // ===============================================================

  /// 🎁 Fungsi untuk memberi BONUS
  Future<void> _giveBonus() async {
    // Konfirmasi terlebih dahulu
    final confirm = await _showConfirmDialog(
      "Ajukan Bonus",
      "Apakah Anda yakin ingin mengajukan bonus untuk karyawan ini?",
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1️⃣ Buat request bonus baru ke keuangan
      await firestore.collection('bonus_requests').add({
        'employeeId': widget.submissionData['employeeId'],
        'submissionId': widget.submissionId,
        'targetId': widget.submissionData['targetId'],
        'requestDate': Timestamp.now(),
        'status': 'pending',
        'hrId': currentUser?.uid ?? 'unknown',
        'hrName': currentUser?.displayName ?? 'HR',
      });

      // 2️⃣ Update data evaluasi di performance_submissions
      await firestore
          .collection('performance_submissions')
          .doc(widget.submissionId)
          .update({
            'status': 'evaluated',
            'evaluationResult': {
              'status': 'BONUS',
              'message':
                  'Selamat! Kinerja Anda sangat baik dan melebihi ekspektasi.',
              'evaluatedBy': currentUser?.uid ?? 'unknown',
              'evaluatedAt': Timestamp.now(),
            },
          });

      // 3️⃣ Update status target agar pindah ke tab Riwayat karyawan
      await firestore
          .collection('targets')
          .doc(widget.submissionData['targetId'])
          .update({'status': 'evaluated', 'evaluatedAt': Timestamp.now()});

      _showSuccessAndGoBack("✅ Bonus berhasil diajukan ke Keuangan.");
    } catch (e) {
      _showError("❌ Gagal memproses bonus: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 💬 Fungsi untuk memberi FEEDBACK
  Future<void> _giveFeedback() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Beri Feedback"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Berikan saran perbaikan untuk karyawan:",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: "Contoh: Tingkatkan kecepatan respons...",
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
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
            onPressed: () async {
              if (_feedbackController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Feedback tidak boleh kosong"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _processFeedback();
            },
            child: const Text("Kirim Feedback"),
          ),
        ],
      ),
    );
  }

  Future<void> _processFeedback() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1️⃣ Update data evaluasi di performance_submissions
      await firestore
          .collection('performance_submissions')
          .doc(widget.submissionId)
          .update({
            'status': 'evaluated',
            'evaluationResult': {
              'status': 'FEEDBACK',
              'message': _feedbackController.text.trim(),
              'evaluatedBy': currentUser?.uid ?? 'unknown',
              'evaluatedAt': Timestamp.now(),
            },
          });

      // 2️⃣ Update status target agar masuk ke Riwayat
      await firestore
          .collection('targets')
          .doc(widget.submissionData['targetId'])
          .update({'status': 'evaluated', 'evaluatedAt': Timestamp.now()});

      _showSuccessAndGoBack("✅ Feedback berhasil diberikan.");
    } catch (e) {
      _showError("❌ Gagal memberi feedback: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ⚠️ Fungsi untuk memberi SP (Surat Peringatan)
  Future<void> _giveSP() async {
    // Pilih level SP
    final spLevel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pilih Level Surat Peringatan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSPOption(context, "SP1", "Peringatan Pertama"),
            _buildSPOption(context, "SP2", "Peringatan Kedua"),
            _buildSPOption(context, "SP3", "Peringatan Terakhir"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
        ],
      ),
    );

    if (spLevel == null) return;

    // Tampilkan dialog untuk edit catatan SP
    await _showSPReasonDialog(spLevel);
  }

  /// Dialog untuk HR menulis/edit alasan SP
  Future<void> _showSPReasonDialog(String spLevel) async {
    final spReasonController = TextEditingController();

    // Template default berdasarkan level SP
    String defaultMessage;
    switch (spLevel) {
      case 'SP1':
        defaultMessage =
            'Kinerja Anda di bawah standar. Harap segera melakukan perbaikan.';
        break;
      case 'SP2':
        defaultMessage =
            'Peringatan kedua. Kinerja masih belum memenuhi standar perusahaan.';
        break;
      case 'SP3':
        defaultMessage =
            'Peringatan terakhir. Perbaikan harus segera dilakukan atau akan ada konsekuensi lebih lanjut.';
        break;
      default:
        defaultMessage = 'Kinerja perlu ditingkatkan.';
    }

    // Set template default
    spReasonController.text = defaultMessage;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            Text("Catatan $spLevel"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[800]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Anda bisa mengedit alasan sesuai kebutuhan",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Alasan/Catatan Surat Peringatan:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spReasonController,
                decoration: InputDecoration(
                  hintText: "Tulis alasan pemberian SP...",
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                  helperText: "Minimal 20 karakter, maksimal 500 karakter",
                  helperStyle: const TextStyle(fontSize: 11),
                ),
                maxLines: 6,
                maxLength: 500,
              ),
              const SizedBox(height: 8),
              // Preview box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Preview:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Text(
                      spReasonController.text.isNotEmpty
                          ? spReasonController.text
                          : defaultMessage,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: Text("Kirim $spLevel"),
            onPressed: () async {
              final reason = spReasonController.text.trim();

              // Validasi panjang catatan
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Catatan tidak boleh kosong"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (reason.length < 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Catatan minimal 20 karakter"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Konfirmasi final
              final confirm = await _showConfirmDialog(
                "Konfirmasi $spLevel",
                "Apakah Anda yakin ingin memberikan $spLevel dengan catatan ini?",
              );

              if (confirm) {
                await _processSP(spLevel, reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processSP(String spLevel, String customMessage) async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1️⃣ Update evaluasi di performance_submissions
      await firestore
          .collection('performance_submissions')
          .doc(widget.submissionId)
          .update({
            'status': 'evaluated',
            'evaluationResult': {
              'status': spLevel,
              'message': customMessage,
              'evaluatedBy': currentUser?.uid ?? 'unknown',
              'evaluatedAt': Timestamp.now(),
            },
          });

      // 2️⃣ Update target agar pindah ke Riwayat
      await firestore
          .collection('targets')
          .doc(widget.submissionData['targetId'])
          .update({'status': 'evaluated', 'evaluatedAt': Timestamp.now()});

      // 3️⃣ Catat SP di collection terpisah untuk tracking
      await firestore.collection('warning_letters').add({
        'employeeId': widget.submissionData['employeeId'],
        'submissionId': widget.submissionId,
        'targetId': widget.submissionData['targetId'],
        'level': spLevel,
        'message': customMessage,
        'issuedBy': currentUser?.uid ?? 'unknown',
        'issuedAt': Timestamp.now(),
        'status': 'active',
      });

      _showSuccessAndGoBack(
        "✅ $spLevel berhasil dikirim dengan catatan khusus.",
      );
    } catch (e) {
      _showError("❌ Gagal memberi SP: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // =============== HELPER UI DAN FEEDBACK =========================
  // ===============================================================

  Widget _buildSPOption(BuildContext context, String level, String subtitle) {
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

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          level.substring(2),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(level),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, level),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Ya, Lanjutkan"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessAndGoBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
    Navigator.pop(context, 'evaluated');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ===============================================================
  // =============== UI HALAMAN DETAIL EVALUASI ====================
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final int target = widget.targetData['targetValue'] ?? 0;
    final int achieved = widget.submissionData['achievedValue'] ?? 0;
    final double percentage = target > 0 ? (achieved / target) * 100 : 0;

    // Cek keterlambatan
    final bool isLate = widget.submissionData['isLate'] ?? false;
    final deadline = (widget.submissionData['deadline'] as Timestamp?)
        ?.toDate();
    final submissionDate =
        (widget.submissionData['submissionDate'] as Timestamp?)?.toDate();

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
          'Detail Evaluasi',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Card Informasi Karyawan ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Karyawan:",
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.employeeName,
                              style: TextStyle(
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Card Informasi Waktu Pengiriman ---
            Container(
              decoration: BoxDecoration(
                color: isLate ? Color(0xFFFFEBEE) : Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isLate
                      ? Color(0xFFEF5350).withOpacity(0.3)
                      : Color(0xFF4CAF50).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLate ? Color(0xFFEF5350) : Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isLate
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isLate ? "⚠️ TERLAMBAT" : "✅ TEPAT WAKTU",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE8E8E8)),
                  _buildTimeInfo(
                    icon: Icons.flag,
                    label: "Deadline",
                    value: deadline != null
                        ? _formatDateTime(deadline)
                        : "Tidak ada",
                    color: Color(0xFFFFB74D),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeInfo(
                    icon: Icons.send_rounded,
                    label: "Tanggal Pengiriman",
                    value: submissionDate != null
                        ? _formatDateTime(submissionDate)
                        : "Tidak ada",
                    color: isLate ? Color(0xFFEF5350) : Color(0xFF4CAF50),
                  ),
                  if (isLate && deadline != null && submissionDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(0xFFEF5350).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFFEF5350),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _calculateLateDuration(deadline, submissionDate),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Card Informasi Target ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Target Kinerja:",
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.targetData['title'] ?? 'Tanpa Judul',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Periode: ${widget.targetData['period'] ?? 'N/A'}",
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Card Perbandingan Hasil ---
            Container(
              decoration: BoxDecoration(
                color: percentage >= 100
                    ? Color(0xFFE8F5E9)
                    : Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: percentage >= 100
                      ? Color(0xFF4CAF50).withOpacity(0.3)
                      : Color(0xFFEF5350).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "HASIL PENCAPAIAN",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                        "TARGET",
                        "$target ${widget.targetData['unit'] ?? ''}",
                        Color(0xFFFF6B9D),
                      ),
                      _buildStat(
                        "HASIL",
                        "$achieved ${widget.targetData['unit'] ?? ''}",
                        Color(0xFF2D3142),
                      ),
                      _buildStat(
                        "PENCAPAIAN",
                        "${percentage.toStringAsFixed(1)}%",
                        percentage >= 100
                            ? Color(0xFF4CAF50)
                            : Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Tombol Aksi HR ---
            Text(
              "Tindakan Evaluasi",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6B9D),
                    ),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Ajukan Bonus",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _giveBonus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.feedback_rounded, color: Colors.white),
                    label: Text(
                      "Beri Feedback",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _giveFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF6B9D),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.warning_rounded, color: Colors.white),
                    label: Text(
                      "Beri Surat Peringatan (SP)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _giveSP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEF5350),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // =============== WIDGET BANTU UNTUK STATISTIK ==================
  // ===============================================================

  Widget _buildStat(String label, String value, Color color) {
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _calculateLateDuration(DateTime deadline, DateTime submission) {
    final difference = submission.difference(deadline);

    if (difference.inDays > 0) {
      return 'Terlambat ${difference.inDays} hari';
    } else if (difference.inHours > 0) {
      return 'Terlambat ${difference.inHours} jam';
    } else if (difference.inMinutes > 0) {
      return 'Terlambat ${difference.inMinutes} menit';
    } else {
      return 'Terlambat beberapa detik';
    }
  }
}
