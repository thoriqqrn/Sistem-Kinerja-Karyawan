// lib/evaluate_submissions_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluation_detail_page.dart';

class EvaluateSubmissionsPage extends StatefulWidget {
  const EvaluateSubmissionsPage({super.key});

  @override
  State<EvaluateSubmissionsPage> createState() =>
      _EvaluateSubmissionsPageState();
}

class _EvaluateSubmissionsPageState extends State<EvaluateSubmissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
          'Evaluasi Kinerja',
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
                Tab(text: "Perlu Dievaluasi"),
                Tab(text: "Riwayat"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SubmissionListView(status: 'submitted'),
          SubmissionListView(status: 'evaluated'),
        ],
      ),
    );
  }
}

class SubmissionListView extends StatelessWidget {
  final String status;
  const SubmissionListView({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('performance_submissions')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Tidak ada data untuk kategori ini.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Terjadi kesalahan: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final submissions = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            final submissionData =
                submissions[index].data() as Map<String, dynamic>;
            return SubmissionTile(
              submissionData: submissionData,
              submissionId: submissions[index].id,
              status: status,
            );
          },
        );
      },
    );
  }
}

class SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> submissionData;
  final String submissionId;
  final String status;

  const SubmissionTile({
    Key? key,
    required this.submissionData,
    required this.submissionId,
    required this.status,
  }) : super(key: key);

  Future<Map<String, dynamic>> _getRelatedData() async {
    final employeeDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(submissionData['employeeId'])
        .get();
    final targetDoc = await FirebaseFirestore.instance
        .collection('targets')
        .doc(submissionData['targetId'])
        .get();

    return {
      'employeeName': employeeDoc.data()?['fullName'] ?? 'Unknown',
      'targetTitle': targetDoc.data()?['title'] ?? 'No Title',
      'targetData': targetDoc.data() ?? {},
    };
  }

  /// Fungsi untuk mengubah status target ke "evaluated" setelah HR memberikan evaluasi
  Future<void> _updateTargetStatus(String targetId) async {
    try {
      await FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId)
          .update({'status': 'evaluated'});
      debugPrint("Status target $targetId berhasil diubah menjadi evaluated ✅");
    } catch (e) {
      debugPrint("Gagal memperbarui status target: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah submission ini terlambat
    final bool isLate = submissionData['isLate'] ?? false;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getRelatedData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(child: CircularProgressIndicator()),
              title: Text("Memuat data..."),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.error, color: Colors.white),
              ),
              title: const Text("Gagal memuat detail"),
              subtitle: Text(
                snapshot.error.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }

        final relatedData = snapshot.data!;
        final employeeName = relatedData['employeeName'] as String;
        final targetTitle = relatedData['targetTitle'] as String;
        final targetData = relatedData['targetData'] as Map<String, dynamic>;

        // Dapatkan hasil evaluasi jika sudah ada (untuk tab Riwayat)
        String evaluationResult = '';
        Color evaluationColor = Colors.grey;
        if (status == 'evaluated' &&
            submissionData['evaluationResult'] != null) {
          evaluationResult =
              submissionData['evaluationResult']['status'] ?? 'N/A';

          // Set warna berdasarkan hasil evaluasi
          switch (evaluationResult.toUpperCase()) {
            case 'BONUS':
              evaluationColor = Colors.green;
              break;
            case 'FEEDBACK':
              evaluationColor = Colors.blue;
              break;
            case 'SP1':
            case 'SP2':
            case 'SP3':
              evaluationColor = Colors.red;
              break;
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: isLate ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isLate
                ? const BorderSide(color: Colors.red, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person, size: 28),
                ),
                // Badge warning untuk keterlambatan
                if (isLate)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    employeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Badge TELAT di sebelah nama
                if (isLate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'TELAT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  "Target: $targetTitle",
                  style: const TextStyle(fontSize: 14),
                ),
                // Pesan keterlambatan
                if (isLate) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Terlambat mengirim hasil kerja",
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            trailing: status == 'evaluated'
                ? Chip(
                    label: Text(
                      evaluationResult,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: evaluationColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  )
                : const Icon(Icons.chevron_right, size: 28),
            onTap: () async {
              if (status == 'submitted') {
                // Buka halaman detail evaluasi
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvaluationDetailPage(
                      submissionId: submissionId,
                      submissionData: submissionData,
                      targetData: targetData,
                      employeeName: employeeName,
                    ),
                  ),
                );

                // ✅ Jika HR selesai memberikan evaluasi, ubah status target
                if (result == 'evaluated') {
                  await _updateTargetStatus(submissionData['targetId']);
                }
              } else {
                // Untuk tab Riwayat, bisa tampilkan detail read-only
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(employeeName),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Target: $targetTitle"),
                        const SizedBox(height: 8),
                        Text("Hasil Evaluasi: $evaluationResult"),
                        if (isLate) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "⚠️ Karyawan ini terlambat mengirim",
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Tutup"),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
