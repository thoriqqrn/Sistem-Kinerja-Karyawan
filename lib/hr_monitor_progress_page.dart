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
      appBar: AppBar(
        title: const Text('Monitor Progress Karyawan'),
        backgroundColor: Colors.green[700],
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
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTargetFilter()),
              const SizedBox(width: 12),
              Expanded(child: _buildEmployeeFilter()),
            ],
          ),
          if (_selectedTargetId != null || _selectedEmployeeId != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Reset Filter'),
              onPressed: () {
                setState(() {
                  _selectedTargetId = null;
                  _selectedEmployeeId = null;
                });
              },
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
          return const CircularProgressIndicator();
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

        return DropdownButtonFormField<String>(
          value: _selectedTargetId,
          decoration: const InputDecoration(
            labelText: 'Target',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Semua Target'),
          items: uniqueTargets.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedTargetId = value;
            });
          },
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
          return const CircularProgressIndicator();
        }

        return DropdownButtonFormField<String>(
          value: _selectedEmployeeId,
          decoration: const InputDecoration(
            labelText: 'Karyawan',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: const Text('Semua Karyawan'),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(
                data['fullName'] ?? 'Unknown',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployeeId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildTargetsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredTargetsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada target aktif',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Text(
                          employeeName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              targetData['title'] ?? 'No Title',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProgressSection(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDeadlineInfo(),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
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
            statusColor = Colors.green;
            statusText = 'ON TRACK';
            statusIcon = Icons.check_circle;
          } else if (percentage >= expectedPercentage * 0.7) {
            statusColor = Colors.orange;
            statusText = 'PERLU PERHATIAN';
            statusIcon = Icons.warning;
          } else {
            statusColor = Colors.red;
            statusText = 'SANGAT LAMBAT';
            statusIcon = Icons.error;
          }
        } else {
          statusColor = Colors.grey;
          statusText = 'N/A';
          statusIcon = Icons.help;
        }

        // Check if inactive (no input > 3 days)
        if (lastInputDate != null) {
          final daysSinceLastInput = now.difference(lastInputDate).inDays;
          if (daysSinceLastInput > 3) {
            statusColor = Colors.grey;
            statusText = 'TIDAK AKTIF';
            statusIcon = Icons.hourglass_empty;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalProgress / $targetValue $unit',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}% tercapai',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (lastInputDate != null)
                  Text(
                    'Terakhir: ${DateFormat('dd MMM, HH:mm').format(lastInputDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  )
                else
                  Text(
                    'Belum ada input',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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

    if (difference.isNegative) {
      text = 'Deadline lewat';
      color = Colors.red;
    } else if (difference.inDays <= 3) {
      text = 'Deadline: ${difference.inDays} hari lagi';
      color = Colors.orange;
    } else {
      text = 'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}';
      color = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
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
      appBar: AppBar(
        title: Text('Progress: $employeeName'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.green[700],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetData['title'] ?? 'No Title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Target: $targetValue $unit',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
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
