import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HRMonitorProgressPage extends StatefulWidget {
  const HRMonitorProgressPage({Key? key}) : super(key: key);

  @override
  State<HRMonitorProgressPage> createState() => _HRMonitorProgressPageState();
}

class _HRMonitorProgressPageState extends State<HRMonitorProgressPage> {
  String? _selectedTargetId;
  String? _selectedEmployeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Monitor Progress Karyawan',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildTargetsList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B9D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: Color(0xFFFF6B9D),
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTargetFilter()),
              const SizedBox(width: 12),
              Expanded(child: _buildEmployeeFilter()),
            ],
          ),
          if (_selectedTargetId != null || _selectedEmployeeId != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: Color(0xFFFF6B9D),
                ),
                label: Text(
                  'Reset Filter',
                  style: TextStyle(
                    color: Color(0xFFFF6B9D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedTargetId = null;
                    _selectedEmployeeId = null;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B9D).withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('targets')
          .where('status', whereIn: ['active', 'submitted'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE8E8E8)),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                ),
              ),
            ),
          );
        }

        final targets = snapshot.data!.docs;
        final uniqueTargets = <String, String>{};

        for (var doc in targets) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'No Title';
          if (!uniqueTargets.containsKey(title)) {
            uniqueTargets[doc.id] = title;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedTargetId,
            decoration: InputDecoration(
              labelText: 'Target',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon: Icon(
                Icons.flag_rounded,
                color: Color(0xFFFF6B9D),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE8E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE8E8E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFFF6B9D), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            hint: Text(
              'Semua Target',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            items: uniqueTargets.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF2D3142), fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTargetId = value;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildEmployeeFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE8E8E8)),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedEmployeeId,
            decoration: InputDecoration(
              labelText: 'Karyawan',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFFF6B9D),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE8E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFE8E8E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFFF6B9D), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            hint: Text(
              'Semua Karyawan',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
            items: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: doc.id,
                child: Text(
                  data['fullName'] ?? 'Unknown',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF2D3142), fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEmployeeId = value;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildTargetsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredTargetsStream(),
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
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.inbox_rounded,
                    size: 64,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada target aktif',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Target akan muncul di sini',
                  style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB)),
                ),
              ],
            ),
          );
        }

        final targets = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: targets.length,
          itemBuilder: (context, index) {
            final targetDoc = targets[index];
            final targetData = targetDoc.data() as Map<String, dynamic>;
            return TargetProgressCard(
              targetId: targetDoc.id,
              targetData: targetData,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredTargetsStream() {
    Query query = FirebaseFirestore.instance
        .collection('targets')
        .where('status', whereIn: ['active', 'submitted']);

    if (_selectedEmployeeId != null) {
      query = query.where('employeeId', isEqualTo: _selectedEmployeeId);
    }

    if (_selectedTargetId != null) {
      // This would need a different approach since we can't filter by doc ID in where clause
      // For now, we'll filter on client side
    }

    return query.snapshots();
  }
}

// ===============================================================
// =============== TARGET PROGRESS CARD ==========================
// ===============================================================

class TargetProgressCard extends StatelessWidget {
  final String targetId;
  final Map<String, dynamic> targetData;

  const TargetProgressCard({
    Key? key,
    required this.targetId,
    required this.targetData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final employeeId = targetData['employeeId'] as String;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get(),
      builder: (context, empSnapshot) {
        if (!empSnapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final employeeName =
            (empSnapshot.data!.data() as Map<String, dynamic>?)?['fullName'] ??
            'Unknown';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProgressDetailPage(
                      targetId: targetId,
                      targetData: targetData,
                      employeeName: employeeName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              employeeName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employeeName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                targetData['title'] ?? 'No Title',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFFF6B9D),
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProgressSection(),
                    const SizedBox(height: 12),
                    _buildDeadlineInfo(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSection() {
    final targetValue = targetData['targetValue'] as int;
    final unit = targetData['unit'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: targetId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalProgress = 0;
        DateTime? lastInputDate;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalProgress += data['dailyValue'] as int? ?? 0;

            final date = (data['date'] as Timestamp?)?.toDate();
            if (date != null &&
                (lastInputDate == null || date.isAfter(lastInputDate))) {
              lastInputDate = date;
            }
          }
        }

        final percentage = targetValue > 0
            ? (totalProgress / targetValue) * 100
            : 0;

        // Determine status
        Color statusColor;
        String statusText;
        IconData statusIcon;

        final deadline = (targetData['deadline'] as Timestamp?)?.toDate();
        final now = DateTime.now();

        if (deadline != null) {
          final totalDays = deadline
              .difference(
                (targetData['startDate'] as Timestamp?)?.toDate() ?? now,
              )
              .inDays;
          final elapsedDays = now
              .difference(
                (targetData['startDate'] as Timestamp?)?.toDate() ?? now,
              )
              .inDays;
          final expectedPercentage = totalDays > 0
              ? (elapsedDays / totalDays) * 100
              : 0;

          if (percentage >= expectedPercentage * 0.9) {
            statusColor = Color(0xFF4CAF50);
            statusText = 'ON TRACK';
            statusIcon = Icons.check_circle_rounded;
          } else if (percentage >= expectedPercentage * 0.7) {
            statusColor = Color(0xFFFFB74D);
            statusText = 'PERLU PERHATIAN';
            statusIcon = Icons.warning_rounded;
          } else {
            statusColor = Color(0xFFEF5350);
            statusText = 'SANGAT LAMBAT';
            statusIcon = Icons.error_rounded;
          }
        } else {
          statusColor = Color(0xFF9CA3AF);
          statusText = 'N/A';
          statusIcon = Icons.help_rounded;
        }

        // Check if inactive (no input > 3 days)
        if (lastInputDate != null) {
          final daysSinceLastInput = now.difference(lastInputDate).inDays;
          if (daysSinceLastInput > 3) {
            statusColor = Color(0xFF9CA3AF);
            statusText = 'TIDAK AKTIF';
            statusIcon = Icons.hourglass_empty_rounded;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$totalProgress / $targetValue $unit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Color(0xFFF0F0F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF6B9D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF6B9D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'tercapai',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                if (lastInputDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(lastInputDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Belum ada input',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF5350),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeadlineInfo() {
    final deadline = (targetData['deadline'] as Timestamp?)?.toDate();
    if (deadline == null) return const SizedBox();

    final now = DateTime.now();
    final difference = deadline.difference(now);

    String text;
    Color color;
    IconData icon;

    if (difference.isNegative) {
      text = 'Deadline lewat';
      color = Color(0xFFEF5350);
      icon = Icons.event_busy_rounded;
    } else if (difference.inDays <= 3) {
      text = 'Deadline: ${difference.inDays} hari lagi';
      color = Color(0xFFFFB74D);
      icon = Icons.warning_rounded;
    } else {
      text = 'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}';
      color = Color(0xFF4CAF50);
      icon = Icons.event_available_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================================
// =============== PROGRESS DETAIL PAGE ==========================
// ===============================================================

class ProgressDetailPage extends StatelessWidget {
  final String targetId;
  final Map<String, dynamic> targetData;
  final String employeeName;

  const ProgressDetailPage({
    Key? key,
    required this.targetId,
    required this.targetData,
    required this.employeeName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final targetValue = targetData['targetValue'] as int;
    final unit = targetData['unit'] ?? '';

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Progress: $employeeName',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetData['title'] ?? 'No Title',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Target: $targetValue $unit',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildProgressSummary(),
            ),

            // Daily Input History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riwayat Input Harian',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDailyHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final targetValue = targetData['targetValue'] as int;
    final unit = targetData['unit'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: targetId)
          .snapshots(),
      builder: (context, snapshot) {
        int totalProgress = 0;
        int inputCount = 0;

        if (snapshot.hasData) {
          inputCount = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            totalProgress +=
                (doc.data() as Map<String, dynamic>)['dailyValue'] as int? ?? 0;
          }
        }

        final percentage = targetValue > 0
            ? (totalProgress / targetValue) * 100
            : 0;
        final remaining = targetValue - totalProgress;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: percentage >= 50 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage >= 50 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Tercapai', '$totalProgress $unit', Colors.blue),
                    _buildStat('Sisa', '$remaining $unit', Colors.orange),
                    _buildStat('Input', '$inputCount hari', Colors.green),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: targetId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Belum ada input harian')),
            ),
          );
        }

        // Sort di client-side
        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
          final bDate = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
          return bDate.compareTo(aDate); // Descending
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final dailyValue = data['dailyValue'] as int;
            final notes = data['notes'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: notes != null && notes.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.note,
                                  size: 14,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    notes,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
                trailing: Text(
                  '+$dailyValue ${targetData['unit']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
