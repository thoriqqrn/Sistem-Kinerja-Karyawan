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
      appBar: AppBar(
        title: const Text("Detail Evaluasi"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Card Informasi Karyawan ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Card Informasi Waktu Pengiriman ---
            Card(
              elevation: 2,
              color: isLate ? Colors.red[50] : Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLate
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          color: isLate ? Colors.red[700] : Colors.green[700],
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isLate ? "⚠️ TERLAMBAT" : "✅ TEPAT WAKTU",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isLate
                                  ? Colors.red[900]
                                  : Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildTimeInfo(
                      icon: Icons.flag,
                      label: "Deadline",
                      value: deadline != null
                          ? _formatDateTime(deadline)
                          : "Tidak ada",
                      color: Colors.orange[800]!,
                    ),
                    const SizedBox(height: 12),
                    _buildTimeInfo(
                      icon: Icons.send,
                      label: "Tanggal Pengiriman",
                      value: submissionDate != null
                          ? _formatDateTime(submissionDate)
                          : "Tidak ada",
                      color: isLate ? Colors.red[700]! : Colors.green[700]!,
                    ),
                    if (isLate &&
                        deadline != null &&
                        submissionDate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.red[900],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _calculateLateDuration(
                                  deadline,
                                  submissionDate,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
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
            ),
            const SizedBox(height: 16),

            // --- Card Informasi Target ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Target Kinerja:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.targetData['title'] ?? 'Tanpa Judul',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Periode: ${widget.targetData['period'] ?? 'N/A'}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Card Perbandingan Hasil ---
            Card(
              elevation: 2,
              color: percentage >= 100 ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "HASIL PENCAPAIAN",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          "TARGET",
                          "$target ${widget.targetData['unit'] ?? ''}",
                          Colors.blue,
                        ),
                        _buildStat(
                          "HASIL",
                          "$achieved ${widget.targetData['unit'] ?? ''}",
                          Colors.black87,
                        ),
                        _buildStat(
                          "PENCAPAIAN",
                          "${percentage.toStringAsFixed(1)}%",
                          percentage >= 100 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Tombol Aksi HR ---
            const Text(
              "Tindakan Evaluasi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard, color: Colors.white),
                    label: const Text(
                      "Ajukan Bonus",
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: _giveBonus,
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.feedback, color: Colors.white),
                    label: const Text(
                      "Beri Feedback",
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: _giveFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.warning, color: Colors.white),
                    label: const Text(
                      "Beri Surat Peringatan (SP)",
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: _giveSP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
