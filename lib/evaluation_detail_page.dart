// lib/evaluation_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // LOGIKA UTAMA ADA DI FUNGSI-FUNGSI INI
  
  // Fungsi untuk memberi BONUS
  Future<void> _giveBonus() async {
    setState(() { _isLoading = true; });
    try {
      final firestore = FirebaseFirestore.instance;
      // 1. Buat request bonus baru untuk Keuangan
      await firestore.collection('bonus_requests').add({
        'employeeId': widget.submissionData['employeeId'],
        'submissionId': widget.submissionId,
        'requestDate': Timestamp.now(),
        'status': 'pending', // Status awal request
        'hrId': 'id_hr_yang_login', // TODO: Ganti dengan ID HR yang sedang login
      });

      // 2. Update dokumen submission
      await firestore.collection('performance_submissions').doc(widget.submissionId).update({
        'status': 'evaluated',
        'evaluationResult': {
          'status': 'BONUS',
          'message': 'Selamat! Kinerja Anda sangat baik.',
        }
      });
      
      _showSuccessAndGoBack("Bonus berhasil diajukan ke Keuangan.");

    } catch (e) {
      _showError("Gagal memproses bonus: $e");
    } finally {
       if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Fungsi untuk memberi FEEDBACK
  Future<void> _giveFeedback() async {
    // Tampilkan dialog untuk mengisi feedback
    await showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("Beri Feedback"),
      content: TextField(
        controller: _feedbackController,
        decoration: InputDecoration(hintText: "Tulis saran perbaikan..."),
        maxLines: 4,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal")),
        ElevatedButton(onPressed: () async {
          if (_feedbackController.text.isEmpty) return;
          Navigator.pop(context);
          setState(() { _isLoading = true; });
          try {
            await FirebaseFirestore.instance.collection('performance_submissions').doc(widget.submissionId).update({
              'status': 'evaluated',
              'evaluationResult': {
                'status': 'FEEDBACK',
                'message': _feedbackController.text.trim(),
              }
            });
            _showSuccessAndGoBack("Feedback berhasil diberikan.");
          } catch(e) {
            _showError("Gagal memberi feedback: $e");
          } finally {
            if (mounted) setState(() { _isLoading = false; });
          }
        }, child: Text("Kirim")),
      ],
    ));
  }
  
  // Fungsi untuk memberi SP (Surat Peringatan)
  Future<void> _giveSP() async {
    // Untuk saat ini, kita hanya update status. Pembuatan PDF akan di fase selanjutnya.
    setState(() { _isLoading = true; });
     try {
      await FirebaseFirestore.instance.collection('performance_submissions').doc(widget.submissionId).update({
        'status': 'evaluated',
        'evaluationResult': {
          'status': 'SP1', // Contoh, bisa dibuat dinamis
          'message': 'Kinerja Anda di bawah standar yang diharapkan. Harap segera perbaiki.',
        }
      });
      _showSuccessAndGoBack("Status SP1 berhasil dicatat.");
    } catch(e) {
      _showError("Gagal memberi SP: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showSuccessAndGoBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
    Navigator.pop(context); // Kembali ke halaman list
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final int target = widget.targetData['targetValue'];
    final int achieved = widget.submissionData['achievedValue'];
    final double percentage = (achieved / target) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text("Detail Evaluasi"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Karyawan:", style: TextStyle(color: Colors.grey)),
            Text(widget.employeeName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text("Target Kinerja:", style: TextStyle(color: Colors.grey)),
            Text(widget.targetData['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Divider(height: 32),
            
            // Bagian Perbandingan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("TARGET", "$target ${widget.targetData['unit']}"),
                _buildStat("HASIL", "$achieved ${widget.targetData['unit']}"),
                _buildStat("PENCAPAIAN", "${percentage.toStringAsFixed(1)}%", color: percentage >= 100 ? Colors.green : Colors.red),
              ],
            ),
            Divider(height: 32),

            // Bagian Tombol Aksi
            Text("Tindakan Evaluasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.card_giftcard),
                    label: Text("Ajukan Bonus"),
                    onPressed: _giveBonus,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.feedback),
                    label: Text("Beri Feedback"),
                    onPressed: _giveFeedback,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.warning),
                    label: Text("Beri Surat Peringatan (SP)"),
                    onPressed: _giveSP,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 12)),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  // Widget helper untuk menampilkan statistik
  Widget _buildStat(String label, String value, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}