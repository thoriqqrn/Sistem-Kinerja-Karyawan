// lib/evaluate_submissions_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluation_detail_page.dart';

class EvaluateSubmissionsPage extends StatefulWidget {
  const EvaluateSubmissionsPage({super.key});

  @override
  State<EvaluateSubmissionsPage> createState() => _EvaluateSubmissionsPageState();
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
      appBar: AppBar(
        title: Text("Evaluasi Kinerja"),
        // Tambahkan TabBar di bagian bawah AppBar
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Perlu Dievaluasi"),
            Tab(text: "Riwayat"),
          ],
        ),
      ),
      // Gunakan TabBarView untuk menampilkan konten sesuai tab yang aktif
      body: TabBarView(
        controller: _tabController,
        children: [
          // Konten untuk tab pertama: Laporan yang statusnya 'submitted'
          SubmissionListView(status: 'submitted'),
          // Konten untuk tab kedua: Laporan yang statusnya 'evaluated'
          SubmissionListView(status: 'evaluated'),
        ],
      ),
    );
  }
}

// Widget ini kita pisahkan agar bisa digunakan ulang untuk kedua tab
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
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Tidak ada data untuk kategori ini."));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Terjadi kesalahan."));
        }

        final submissions = snapshot.data!.docs;

        return ListView.builder(
          itemCount: submissions.length,
          itemBuilder: (context, index) {
            final submissionData = submissions[index].data() as Map<String, dynamic>;
            return SubmissionTile(
              submissionData: submissionData,
              submissionId: submissions[index].id,
              // Kirim status agar kita tahu item ini bisa di-tap atau tidak
              status: status,
            );
          },
        );
      },
    );
  }
}


// Kita modifikasi sedikit SubmissionTile
class SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> submissionData;
  final String submissionId;
  final String status; // Tambahkan parameter status

  const SubmissionTile({
    Key? key,
    required this.submissionData,
    required this.submissionId,
    required this.status, // Wajib diisi
  }) : super(key: key);
  
  // Fungsi untuk mengambil data karyawan dan target
  Future<Map<String, dynamic>> _getRelatedData() async {
    final employeeDoc = await FirebaseFirestore.instance.collection('users').doc(submissionData['employeeId']).get();
    final targetDoc = await FirebaseFirestore.instance.collection('targets').doc(submissionData['targetId']).get();
    return {
      'employeeName': employeeDoc.data()?['fullName'],
      'targetTitle': targetDoc.data()?['title'],
      'targetData': targetDoc.data(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getRelatedData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(title: Text("Memuat data..."));
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return ListTile(title: Text("Gagal memuat detail"), subtitle: Text(snapshot.error.toString()));
        }

        final relatedData = snapshot.data!;
        final employeeName = relatedData['employeeName'] ?? 'N/A';
        final targetTitle = relatedData['targetTitle'] ?? 'N/A';
        final targetData = relatedData['targetData'] as Map<String, dynamic>? ?? {};
        
        // Dapatkan hasil evaluasi jika ada
        String evaluationResult = '';
        if (status == 'evaluated' && submissionData['evaluationResult'] != null) {
          evaluationResult = submissionData['evaluationResult']['status'];
        }

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text(employeeName),
            subtitle: Text("Target: $targetTitle"),
            // Tampilkan status evaluasi di trailing jika sudah dievaluasi
            trailing: status == 'evaluated'
              ? Chip(label: Text(evaluationResult, style: TextStyle(color: Colors.white)), backgroundColor: Colors.grey)
              : Icon(Icons.chevron_right),
            onTap: () {
              // HANYA BISA DI-TAP JIKA STATUSNYA 'submitted'
              if (status == 'submitted') {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return EvaluationDetailPage(
                    submissionId: submissionId,
                    submissionData: submissionData,
                    targetData: targetData,
                    employeeName: employeeName,
                  );
                }));
              }
            },
          ),
        );
      },
    );
  }
}