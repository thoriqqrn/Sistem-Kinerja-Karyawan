// lib/add_employee_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  // Controller untuk setiap field
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _departemenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  Future<void> _saveEmployee() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() { _isLoading = true; });

    try {
      // 1. Buat user baru di Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // 2. Simpan data user ke Firestore dengan UID yang sama sebagai Document ID
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'jabatan': _jabatanController.text.trim(),
        'departemen': _departemenController.text.trim(),
        'role': 'employee', // Langsung set role sebagai 'employee'
        'createdAt': Timestamp.now(),
      });

      // Tampilkan pesan sukses dan kembali ke halaman sebelumnya
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Karyawan berhasil ditambahkan!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Kembali ke halaman daftar karyawan
      }

    } on FirebaseAuthException catch (e) {
      // Tangani error spesifik
      String message = 'Terjadi kesalahan.';
      if (e.code == 'email-already-in-use') {
        message = 'Email ini sudah terdaftar.';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan tidak diketahui.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    // Selalu dispose controller
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _jabatanController.dispose();
    _departemenController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tambah Karyawan Baru"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(labelText: 'Nama Lengkap'),
                validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty || !value.contains('@') ? 'Masukkan email valid' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password Sementara'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _jabatanController,
                decoration: InputDecoration(labelText: 'Jabatan'),
                validator: (value) => value!.isEmpty ? 'Jabatan tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _departemenController,
                decoration: InputDecoration(labelText: 'Departemen'),
                validator: (value) => value!.isEmpty ? 'Departemen tidak boleh kosong' : null,
              ),
              SizedBox(height: 32),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveEmployee,
                      child: Text('Simpan Karyawan'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}