// lib/manage_employees_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_employee_page.dart'; // Kita akan buat file ini setelah ini

class ManageEmployeesPage extends StatelessWidget {
  const ManageEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Kelola Karyawan"),
      ),
      // StreamBuilder adalah widget ajaib untuk menampilkan data Firestore secara live.
      // Jika ada data baru di Firestore, halaman ini akan otomatis update.
      body: StreamBuilder<QuerySnapshot>(
        // Ini adalah query kita: ambil data dari koleksi 'users'
        // di mana field 'role' adalah 'employee'.
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .snapshots(),
        builder: (context, snapshot) {
          // Jika masih loading, tampilkan loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Jika tidak ada data sama sekali
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Belum ada data karyawan."));
          }

          // Jika ada error
          if (snapshot.hasError) {
            return Center(child: Text("Terjadi kesalahan."));
          }

          // Jika data berhasil didapat, tampilkan dalam bentuk list
          final employees = snapshot.data!.docs;

          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              // Ambil data dari setiap dokumen
              final employeeData = employees[index].data() as Map<String, dynamic>;
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(employeeData['fullName'] ?? 'Nama Tidak Ada'),
                  subtitle: Text(employeeData['email'] ?? 'Email Tidak Ada'),
                  // Kita bisa tambahkan tombol edit/delete di sini nanti
                ),
              );
            },
          );
        },
      ),
      // Tombol Aksi Mengambang (FAB) untuk menambah karyawan baru
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi ke halaman form tambah karyawan
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEmployeePage()),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Tambah Karyawan',
      ),
    );
  }
}