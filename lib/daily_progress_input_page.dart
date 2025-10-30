import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DailyProgressInputPage extends StatefulWidget {
  final String targetId;
  final Map<String, dynamic> targetData;

  const DailyProgressInputPage({
    Key? key,
    required this.targetId,
    required this.targetData,
  }) : super(key: key);

  @override
  State<DailyProgressInputPage> createState() => _DailyProgressInputPageState();
}

class _DailyProgressInputPageState extends State<DailyProgressInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  final currentUserUid = FirebaseAuth.instance.currentUser!.uid;

  bool _isLoading = false;
  int _totalProgress = 0;
  bool _hasInputToday = false;
  String? _todayProgressId;

  @override
  void initState() {
    super.initState();
    _loadTotalProgress();
    _checkTodayInput();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTotalProgress() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: widget.targetId)
          .where('employeeId', isEqualTo: currentUserUid)
          .get();

      int total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['dailyValue'] as int? ?? 0);
      }

      setState(() {
        _totalProgress = total;
      });
    } catch (e) {
      debugPrint("Error loading total progress: $e");
    }
  }

  Future<void> _checkTodayInput() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: widget.targetId)
          .where('employeeId', isEqualTo: currentUserUid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final todayData = snapshot.docs.first;
        setState(() {
          _hasInputToday = true;
          _todayProgressId = todayData.id;
          _valueController.text = todayData.data()['dailyValue'].toString();
          _notesController.text = todayData.data()['notes'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error checking today input: $e");
    }
  }

  Future<void> _saveProgress() async {
    if (!_formKey.currentState!.validate()) return;

    final dailyValue = int.parse(_valueController.text);
    final notes = _notesController.text.trim();

    // Validasi: total tidak boleh melebihi target
    final targetValue = widget.targetData['targetValue'] as int;
    if (_totalProgress + dailyValue > targetValue && !_hasInputToday) {
      _showError(
        'Total progress (${_totalProgress + dailyValue}) akan melebihi target ($targetValue)',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();

      if (_hasInputToday && _todayProgressId != null) {
        // Update input hari ini
        await FirebaseFirestore.instance
            .collection('daily_progress')
            .doc(_todayProgressId)
            .update({
              'dailyValue': dailyValue,
              'notes': notes,
              'updatedAt': Timestamp.now(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Progress hari ini berhasil diupdate!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Input baru untuk hari ini
        await FirebaseFirestore.instance.collection('daily_progress').add({
          'targetId': widget.targetId,
          'employeeId': currentUserUid,
          'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
          'dailyValue': dailyValue,
          'notes': notes,
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Progress hari ini berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Reload progress
      await _loadTotalProgress();
      await _checkTodayInput();
    } catch (e) {
      _showError('Gagal menyimpan progress: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetValue = widget.targetData['targetValue'] as int;
    final unit = widget.targetData['unit'] ?? '';
    final remaining = targetValue - _totalProgress;
    final percentage = targetValue > 0
        ? (_totalProgress / targetValue) * 100
        : 0;

    // Hitung sisa hari
    final deadline = (widget.targetData['deadline'] as Timestamp?)?.toDate();
    int remainingDays = 0;
    if (deadline != null) {
      remainingDays = deadline.difference(DateTime.now()).inDays;
    }

    final dailyTarget = remainingDays > 0
        ? (remaining / remainingDays).ceil()
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Hasil Harian'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Info Card
            Card(
              elevation: 3,
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.targetData['title'] ?? 'Target',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Target: $targetValue $unit',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    if (deadline != null)
                      Text(
                        'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Summary Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress Saat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: percentage >= 50
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 75
                            ? Colors.green
                            : percentage >= 50
                            ? Colors.blue
                            : percentage >= 25
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          'Tercapai',
                          '$_totalProgress $unit',
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Sisa',
                          '$remaining $unit',
                          Colors.orange,
                        ),
                        if (remainingDays > 0)
                          _buildStatItem(
                            'Per Hari',
                            '$dailyTarget $unit',
                            Colors.green,
                          ),
                      ],
                    ),
                    if (remainingDays > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Sisa waktu: $remainingDays hari',
                          style: TextStyle(
                            fontSize: 12,
                            color: remainingDays <= 7
                                ? Colors.red
                                : Colors.grey[700],
                            fontWeight: remainingDays <= 7
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasInputToday
                        ? 'Edit Progress Hari Ini'
                        : 'Input Progress Hari Ini',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat(
                      'EEEE, dd MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.now()),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hasil Hari Ini ($unit)',
                      hintText: 'Contoh: 100',
                      prefixIcon: const Icon(Icons.trending_up),
                      border: const OutlineInputBorder(),
                      helperText: 'Masukkan pencapaian hari ini',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nilai harus diisi';
                      }
                      final intValue = int.tryParse(value);
                      if (intValue == null || intValue <= 0) {
                        return 'Nilai harus lebih dari 0';
                      }
                      if (!_hasInputToday &&
                          (_totalProgress + intValue > targetValue)) {
                        return 'Total akan melebihi target ($targetValue)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      hintText: 'Catatan tentang pencapaian hari ini...',
                      prefixIcon: Icon(Icons.note_alt),
                      border: OutlineInputBorder(),
                      helperText: 'Tambahkan catatan jika perlu',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProgress,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(_hasInputToday ? Icons.update : Icons.save),
                      label: Text(
                        _isLoading
                            ? 'Menyimpan...'
                            : _hasInputToday
                            ? 'Update Progress'
                            : 'Simpan Progress',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // History Section
            const Text(
              'Riwayat Input',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_progress')
          .where('targetId', isEqualTo: widget.targetId)
          .where('employeeId', isEqualTo: currentUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada riwayat input',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Sort dan limit di client-side
        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
          final bDate = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
          return bDate.compareTo(aDate);
        });
        final limitedDocs = docs.take(10).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limitedDocs.length,
          itemBuilder: (context, index) {
            final doc = limitedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final dailyValue = data['dailyValue'] as int;
            final notes = data['notes'] as String?;
            final isToday =
                DateFormat('dd-MM-yyyy').format(date) ==
                DateFormat('dd-MM-yyyy').format(DateTime.now());

            return Card(
              elevation: isToday ? 3 : 1,
              color: isToday ? Colors.blue[50] : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isToday ? Colors.blue : Colors.grey[400],
                  child: Text(
                    date.day.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date),
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'HARI INI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: notes != null && notes.isNotEmpty
                    ? Text(
                        notes,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  '+$dailyValue ${widget.targetData['unit']}',
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
