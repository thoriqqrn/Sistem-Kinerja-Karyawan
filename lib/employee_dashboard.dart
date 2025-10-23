// lib/employee_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart'; // Import halaman login untuk logout
import 'employee_targets_page.dart'; // Halaman yang akan kita buat

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  // Fungsi untuk logout
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ambil nama pengguna untuk sapaan
    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Karyawan';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Karyawan"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat Datang, $userName!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.checklist),
                label: Text('Lihat Target Saya'),
                onPressed: () {
                  // Navigasi ke halaman target karyawan
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeTargetsPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              // Nanti kita akan tambahkan tombol lain di sini
            ],
          ),
        ),
      ),
    );
  }
}