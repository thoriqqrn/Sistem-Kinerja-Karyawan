import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Penting: Pastikan Anda sudah membuat file-file ini di folder lib/
// meskipun isinya masih kosong atau sederhana (placeholder).
import 'hr_dashboard.dart';
import 'finance_dashboard.dart';
import 'employee_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controller untuk mengambil teks dari TextField
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Instance dari Firebase Authentication dan Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variabel untuk mengontrol status loading
  bool _isLoading = false;

  // Fungsi untuk menampilkan pesan error atau informasi
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, // Ubah warna sesuai kebutuhan
      ),
    );
  }

  // Fungsi utama untuk proses login
  Future<void> _login() async {
    // Validasi sederhana, pastikan field tidak kosong
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage("Email dan Password tidak boleh kosong.");
      return;
    }

    // Ubah state menjadi loading
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Melakukan proses login dengan Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Jika login berhasil, ambil UID pengguna
      if (userCredential.user != null) {
        // 3. Panggil fungsi navigasi berdasarkan peran
        await _navigateBasedOnRole(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      // Tangani error spesifik dari Firebase Auth
      if (e.code == 'user-not-found') {
        _showMessage('User tidak ditemukan untuk email tersebut.');
      } else if (e.code == 'wrong-password') {
        _showMessage('Password yang dimasukkan salah.');
      } else {
        _showMessage('Terjadi kesalahan: ${e.message}');
      }
    } catch (e) {
      // Tangani error umum lainnya
      _showMessage('Terjadi kesalahan yang tidak diketahui.');
    } finally {
      // Hentikan loading, apapun hasilnya (sukses atau gagal)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk navigasi berdasarkan peran (role) dari Firestore
  Future<void> _navigateBasedOnRole(String uid) async {
    try {
      // 1. Ambil dokumen pengguna dari koleksi 'users' berdasarkan UID
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        // 2. Ambil nilai field 'role' dari dokumen
        final String role = userDoc.get('role');

        // 3. Lakukan navigasi berdasarkan nilai 'role'
        // Menggunakan pushReplacement agar pengguna tidak bisa kembali ke halaman login
        if (mounted) { // Pastikan widget masih ada di tree
            switch (role) {
                case 'hr':
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HRDashboard()));
                    break;
                case 'finance':
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const FinanceDashboard()));
                    break;
                case 'employee':
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployeeDashboard()));
                    break;
                default:
                    _showMessage('Peran tidak valid. Hubungi administrator.');
            }
        }

      } else {
        _showMessage('Data pengguna tidak ditemukan di database.');
      }
    } catch (e) {
        _showMessage('Gagal mengambil data peran pengguna.');
    }
  }

  // Selalu dispose controller untuk menghindari memory leaks
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sistem Kinerja Karyawan"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tambahkan logo atau judul di sini jika perlu
              Text(
                'Selamat Datang',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan login untuk melanjutkan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 40),

              // TextField untuk Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // TextField untuk Password
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // Tombol Login dengan Indikator Loading
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('LOGIN', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}