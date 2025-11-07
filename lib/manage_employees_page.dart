// lib/manage_employees_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_employee_page.dart'; // Kita akan buat file ini setelah ini

class ManageEmployeesPage extends StatefulWidget {
  const ManageEmployeesPage({super.key});

  @override
  State<ManageEmployeesPage> createState() => _ManageEmployeesPageState();
}

class _ManageEmployeesPageState extends State<ManageEmployeesPage> {
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String employeeId,
    String employeeName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFEF5350).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Color(0xFFEF5350),
                size: 28,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Hapus Karyawan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                ),
              ),
            ),
          ],
        ),
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFEF5350).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFFEF5350),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Peringatan!",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                "Apakah Anda yakin ingin menghapus akun:",
                style: TextStyle(fontSize: 13, color: Color(0xFF2D3142)),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: Color(0xFFFF6B9D),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employeeName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                "⚠️ Data karyawan, target, dan riwayat progress akan terhapus permanen!",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF5350),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Batal",
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF5350),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_rounded, size: 18),
                SizedBox(width: 6),
                Text(
                  "Ya, Hapus",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _deleteEmployee(employeeId, employeeName);
    }
  }

  Future<void> _deleteEmployee(String employeeId, String employeeName) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Menghapus data karyawan...'),
              ],
            ),
            backgroundColor: Color(0xFFFF6B9D),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final firestore = FirebaseFirestore.instance;

      // Hapus semua target karyawan
      final targetsSnapshot = await firestore
          .collection('targets')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (var doc in targetsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Hapus semua daily progress karyawan
      final progressSnapshot = await firestore
          .collection('daily_progress')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (var doc in progressSnapshot.docs) {
        await doc.reference.delete();
      }

      // Hapus semua performance submissions karyawan
      final submissionsSnapshot = await firestore
          .collection('performance_submissions')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (var doc in submissionsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Hapus semua bonus requests karyawan
      final bonusSnapshot = await firestore
          .collection('bonus_requests')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      for (var doc in bonusSnapshot.docs) {
        await doc.reference.delete();
      }

      // Terakhir, hapus user account
      await firestore.collection('users').doc(employeeId).delete();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Akun $employeeName berhasil dihapus!')),
              ],
            ),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Gagal menghapus: $e')),
              ],
            ),
            backgroundColor: Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Kelola Karyawan",
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 80,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Belum ada data karyawan",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 80,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Terjadi kesalahan",
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          final employees = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employeeData =
                  employees[index].data() as Map<String, dynamic>;
              final employeeId = employees[index].id;

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeData['fullName'] ?? 'Nama Tidak Ada',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              employeeData['email'] ?? 'Email Tidak Ada',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tombol Hapus
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFEF5350).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_rounded,
                            color: Color(0xFFEF5350),
                            size: 22,
                          ),
                          onPressed: () => _showDeleteConfirmation(
                            context,
                            employeeId,
                            employeeData['fullName'] ?? 'Karyawan',
                          ),
                          tooltip: 'Hapus Karyawan',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEmployeePage()),
          );
        },
        backgroundColor: Color(0xFFFF6B9D),
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Tambah Karyawan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
