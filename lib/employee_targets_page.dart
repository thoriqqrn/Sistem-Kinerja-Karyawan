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
        title: Text("Target Kinerja Saya"),
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
          // Tab 1: Menampilkan target yang perlu dikerjakan atau sedang dievaluasi
          TargetListView(
            statuses: const ['active', 'submitted'],
            currentUserUid: currentUserUid,
          ),
          // Tab 2: Menampilkan target yang sudah selesai dievaluasi
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
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Tidak ada data target untuk kategori ini.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
        }

        final targets = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(8.0),
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
    final _hasilController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Input Hasil Kerja"),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _hasilController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Hasil Pencapaian'),
            validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final achievedValue = int.tryParse(_hasilController.text);
                if (achievedValue != null) {
                  _saveSubmission(context, achievedValue);
                  Navigator.pop(context);
                }
              }
            },
            child: Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSubmission(BuildContext context, int achievedValue) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('performance_submissions').add({
      'targetId': targetId,
      'employeeId': currentUserUid,
      'achievedValue': achievedValue,
      'submissionDate': Timestamp.now(),
      'status': 'submitted',
    });
    await firestore.collection('targets').doc(targetId).update({
      'status': 'submitted',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hasil kerja berhasil dikirim!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<DocumentSnapshot?> _getEvaluationResult() async {
    print(
      'Mencari evaluasi untuk Target ID: $targetId, Employee: $currentUserUid',
    );

    final querySnapshot = await FirebaseFirestore.instance
        .collection('performance_submissions')
        .where('targetId', isEqualTo: targetId)
        .where('employeeId', isEqualTo: currentUserUid)
        .orderBy('submissionDate', descending: true)
        .limit(5) // ambil beberapa terakhir untuk dicheck
        .get();

    print('Query menemukan ${querySnapshot.docs.length} dokumen.');

    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('evaluationResult') &&
          data['evaluationResult'] != null) {
        print(
          'Ditemukan evaluasi di doc: ${doc.id} -> ${data['evaluationResult']}',
        );
        return doc;
      }
    }

    print('Tidak ditemukan dokumen dengan evaluationResult untuk target ini.');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = targetData['status'];

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              targetData['title'] ?? 'Tanpa Judul',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '${targetData['targetValue']} ${targetData['unit']} | Periode: ${targetData['period']}'
                  .toUpperCase(),
              style: TextStyle(color: Colors.grey[700]),
            ),
            Divider(height: 24),

            // Bagian bawah kartu yang dinamis berdasarkan status
            if (status == 'active')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showInputHasilDialog(context),
                  child: Text('Input Hasil Kerja'),
                ),
              )
            else if (status == 'submitted')
              _buildStatusChip("Menunggu Evaluasi", Colors.orange)
            else if (status == 'evaluated')
              FutureBuilder<DocumentSnapshot?>(
                future: _getEvaluationResult(),
                builder: (context, snapshot) {
                  // --- PRINT DEBUG 3 ---
                  if (snapshot.connectionState == ConnectionState.done) {
                    print(
                      'FutureBuilder selesai. snapshot.hasError=${snapshot.hasError}, data=${snapshot.data?.data()}',
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildStatusChip("Memuat Hasil...", Colors.grey);
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return _buildStatusChip(
                      "Hasil evaluasi tidak ditemukan — cek Firestore console",
                      Colors.red,
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildStatusChip(
                      "Error: ${snapshot.error}",
                      Colors.red,
                    );
                  }

                  final evalData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  final evalResult = evalData?['evaluationResult'];

                  if (evalResult == null) {
                    return _buildStatusChip(
                      "Data evaluasi tidak lengkap",
                      Colors.red,
                    );
                  }

                  final resultStatus = evalResult['status'] ?? 'N/A';
                  final resultMessage =
                      evalResult['message'] ?? 'Tidak ada pesan.';

                  Color statusColor;
                  switch (resultStatus) {
                    case 'BONUS':
                      statusColor = Colors.green;
                      break;
                    case 'FEEDBACK':
                      statusColor = Colors.blue;
                      break;
                    default:
                      statusColor = Colors.red;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusChip("Hasil: $resultStatus", statusColor),
                      SizedBox(height: 12),
                      Text(
                        "Catatan dari HR:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          resultMessage,
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
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
}
