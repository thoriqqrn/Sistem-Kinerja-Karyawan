// lib/hr_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_employees_page.dart';
import 'login_page.dart'; // <-- IMPORT HALAMAN LOGIN
import 'create_target_page.dart'; // <-- IMPORT HALAMAN YANG AKAN KITA BUAT
import 'evaluate_submissions_page.dart';
import 'hr_monitor_progress_page.dart';

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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B9D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                color: Color(0xFFFF6B9D),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'HR Dashboard',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Color(0xFFFF6B9D)),
            onPressed: () => _logout(context),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // Welcome Section
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFF6B9D).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage your team efficiently',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 25),

          // Menu Grid
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          SizedBox(height: 15),

          _buildMenuCard(
            context: context,
            icon: Icons.people_alt_rounded,
            title: 'Kelola Karyawan',
            subtitle: 'Tambah & kelola akun karyawan',
            color: Color(0xFFFF6B9D),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageEmployeesPage(),
                ),
              );
            },
          ),

          SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            icon: Icons.track_changes_rounded,
            title: 'Buat Target',
            subtitle: 'Tetapkan target kinerja baru',
            color: Color(0xFF8B5CF6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateTargetPage(),
                ),
              );
            },
          ),

          SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            icon: Icons.rate_review_rounded,
            title: 'Evaluasi Kinerja',
            subtitle: 'Tinjau & nilai laporan karyawan',
            color: Color(0xFF10B981),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EvaluateSubmissionsPage(),
                ),
              );
            },
          ),

          SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            icon: Icons.analytics_rounded,
            title: 'Monitor Progress',
            subtitle: 'Lihat perkembangan tim',
            color: Color(0xFF3B82F6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HRMonitorProgressPage(),
                ),
              );
            },
          ),

          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(18),
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
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFD1D5DB),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
