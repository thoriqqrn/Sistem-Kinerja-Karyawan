// lib/hr_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_employees_page.dart';
import 'login_page.dart'; // <-- IMPORT HALAMAN LOGIN
import 'create_target_page.dart'; // <-- IMPORT HALAMAN YANG AKAN KITA BUAT
import 'evaluate_submissions_page.dart';

class HRDashboard extends StatelessWidget {
  const HRDashboard({super.key});

  // Fungsi untuk logout
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // Navigasi kembali ke LoginPage dan hapus semua halaman sebelumnya dari tumpukan
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard HR"),
        actions: [
          // Ini tombol logout kita
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Panggil fungsi logout saat ditekan
              _logout(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.people),
                label: Text('Kelola Akun Karyawan'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageEmployeesPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16), // Beri jarak
              // TOMBOL BARU UNTUK MEMBUAT TARGET
              ElevatedButton.icon(
                icon: Icon(Icons.track_changes),
                label: Text('Buat Target Kinerja'),
                onPressed: () {
                  // Navigasi ke halaman buat target
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTargetPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16), // Beri jarak
              // TOMBOL BARU UNTUK EVALUASI
              ElevatedButton.icon(
                icon: Icon(Icons.rate_review),
                label: Text('Evaluasi Kinerja'),
                onPressed: () {
                  // Navigasi ke halaman daftar laporan masuk
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EvaluateSubmissionsPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                  backgroundColor:
                      Colors.orange, // Beri warna berbeda agar menonjol
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
