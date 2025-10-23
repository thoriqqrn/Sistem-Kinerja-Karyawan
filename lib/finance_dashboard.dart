import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';


class FinanceDashboard extends StatelessWidget {
  const FinanceDashboard({super.key});

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
        title: Text("Dashboard Finance"),
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
      body: Center(child: Text("Selamat Datang, Finance!")),
    );
  }
}
