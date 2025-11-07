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
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: Color(0xFFFF6B9D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        // 2. Ambil nilai field 'role' dari dokumen
        final String role = userDoc.get('role');

        // 3. Lakukan navigasi berdasarkan nilai 'role'
        // Menggunakan pushReplacement agar pengguna tidak bisa kembali ke halaman login
        if (mounted) {
          // Pastikan widget masih ada di tree
          switch (role) {
            case 'hr':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HRDashboard()),
              );
              break;
            case 'finance':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinanceDashboard(),
                ),
              );
              break;
            case 'employee':
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeDashboard(),
                ),
              );
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Decorative Pink Wave
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(50),
                        bottomRight: Radius.circular(50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    right: 40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Content in wave
                  Container(
                    height: screenHeight * 0.35,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_center_rounded,
                            size: 70,
                            color: Colors.white,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Form Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Field
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Color(0xFFE8E8E8),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2D3142),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Color(0xFFFF6B9D),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 25),

                    // Password Field
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Color(0xFFE8E8E8),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2D3142),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(
                            color: Color(0xFFBDBDBD),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Color(0xFFFF6B9D),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40),

                    // Sign In Button
                    _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6B9D),
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFF6B9D),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),

                    SizedBox(height: 30),

                    // Footer
                    Center(
                      child: Text(
                        'Sistem Kinerja Karyawan',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBDBDBD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
