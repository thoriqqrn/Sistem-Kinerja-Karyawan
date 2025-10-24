import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            statuses: const ['active', 'submitted'],
            currentUserUid: currentUserUid,
          ),
          TargetListView(
            statuses: const ['evaluated'],
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

    // Cek apakah telat
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
      'isLate': isLate, // Tandai jika telat
      'deadline': targetData['deadline'], // Simpan deadline reference
    });
    await firestore.collection('targets').doc(targetId).update({
      'status': 'submitted',
    });

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

  Future<DocumentSnapshot?> _getEvaluationResult() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('performance_submissions')
        .where('targetId', isEqualTo: targetId)
        .where('employeeId', isEqualTo: currentUserUid)
        .orderBy('submissionDate', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first;
    }
    return null;
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
            // Tampilkan Deadline
            if (targetData.containsKey('deadline') &&
                targetData['deadline'] != null) ...[
              const SizedBox(height: 8),
              _buildDeadlineInfo(targetData['deadline'] as Timestamp),
            ],
            const Divider(height: 24),

            // Status dan aksi target
            if (status == 'active')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showInputHasilDialog(context),
                  child: const Text('Input Hasil Kerja'),
                ),
              )
            else if (status == 'submitted') ...[
              _buildStatusChip("Menunggu Evaluasi", Colors.orange),
              const SizedBox(height: 8),
              _buildEvaluationResultRealtime(targetId),
            ] else if (status == 'evaluated')
              _buildEvaluationResultStatic(targetId),
          ],
        ),
      ),
    );
  }

  /// ✅ Realtime listener untuk menampilkan hasil evaluasi saat status "submitted"
  /// TIDAK mengubah status target (biarkan HR yang handle)
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
        final eval = data['evaluationResult'];

        // Jika belum ada evaluasi, tidak tampilkan apa-apa
        if (eval == null) return const SizedBox();

        final resultStatus = eval['status'] ?? 'N/A';
        final resultMessage = eval['message'] ?? 'Tidak ada catatan.';

        Color color;
        switch (resultStatus.toUpperCase()) {
          case 'BONUS':
            color = Colors.green;
            break;
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
            const Text(
              "✅ Evaluasi dari HR:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusChip("Status: $resultStatus", color),
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

  /// ✅ Menampilkan hasil evaluasi final (untuk status evaluated)
  /// Digunakan di tab "Riwayat"
  Widget _buildEvaluationResultStatic(String targetId) {
    return FutureBuilder<DocumentSnapshot?>(
      future: _getEvaluationResult(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatusChip("Memuat Hasil...", Colors.grey);
        }
        if (snapshot.hasError) {
          return _buildStatusChip("Error: ${snapshot.error}", Colors.red);
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildStatusChip("Hasil evaluasi tidak ditemukan", Colors.red);
        }

        final evalData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final evalResult =
            evalData['evaluationResult'] as Map<String, dynamic>?;

        if (evalResult == null || evalResult.isEmpty) {
          return _buildStatusChip("Terverifikasi", Colors.green);
        }

        final resultStatus = evalResult['status'] ?? 'N/A';
        final resultMessage = evalResult['message'] ?? 'Tidak ada catatan.';

        Color statusColor;
        switch (resultStatus.toUpperCase()) {
          case 'BONUS':
            statusColor = Colors.green;
            break;
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
          ],
        );
      },
    );
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

  // Widget untuk menampilkan info deadline
  Widget _buildDeadlineInfo(Timestamp deadlineTimestamp) {
    final deadline = deadlineTimestamp.toDate();
    final now = DateTime.now();
    final difference = deadline.difference(now);

    String deadlineText;
    Color deadlineColor;
    IconData deadlineIcon;

    if (difference.isNegative) {
      // Sudah lewat deadline
      deadlineText = '⚠️ Deadline: ${_formatDate(deadline)} (LEWAT)';
      deadlineColor = Colors.red;
      deadlineIcon = Icons.warning;
    } else if (difference.inDays == 0) {
      // Hari ini
      deadlineText = '⏰ Deadline: HARI INI (${_formatDate(deadline)})';
      deadlineColor = Colors.orange;
      deadlineIcon = Icons.today;
    } else if (difference.inDays <= 3) {
      // Kurang dari 3 hari
      deadlineText =
          '⏳ Deadline: ${_formatDate(deadline)} (${difference.inDays} hari lagi)';
      deadlineColor = Colors.orange;
      deadlineIcon = Icons.access_time;
    } else {
      // Masih lama
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
