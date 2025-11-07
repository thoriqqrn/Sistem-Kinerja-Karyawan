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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Input Hasil Harian',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Info Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
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
                              widget.targetData['title'] ?? 'Target',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Target: $targetValue $unit',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (deadline != null) ...[
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Summary Card
            Container(
              padding: EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress Saat Ini',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 10,
                      backgroundColor: Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 75
                            ? Color(0xFF4CAF50)
                            : percentage >= 50
                            ? Color(0xFFFF6B9D)
                            : percentage >= 25
                            ? Color(0xFFFFB74D)
                            : Color(0xFFEF5350),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        'Tercapai',
                        '$_totalProgress $unit',
                        Color(0xFFFF6B9D),
                      ),
                      Container(height: 40, width: 1, color: Color(0xFFE8E8E8)),
                      _buildStatItem(
                        'Sisa',
                        '$remaining $unit',
                        Color(0xFFFFB74D),
                      ),
                      if (remainingDays > 0) ...[
                        Container(
                          height: 40,
                          width: 1,
                          color: Color(0xFFE8E8E8),
                        ),
                        _buildStatItem(
                          'Per Hari',
                          '$dailyTarget $unit',
                          Color(0xFF4CAF50),
                        ),
                      ],
                    ],
                  ),
                  if (remainingDays > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: remainingDays <= 7
                              ? Color(0xFFFFEBEE)
                              : Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: remainingDays <= 7
                                  ? Color(0xFFEF5350)
                                  : Color(0xFF42A5F5),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sisa waktu: $remainingDays hari',
                              style: TextStyle(
                                fontSize: 12,
                                color: remainingDays <= 7
                                    ? Color(0xFFEF5350)
                                    : Color(0xFF42A5F5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input Form
            Form(
              key: _formKey,
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
                          _hasInputToday
                              ? Icons.edit_rounded
                              : Icons.add_task_rounded,
                          color: Color(0xFFFF6B9D),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        _hasInputToday
                            ? 'Edit Progress Hari Ini'
                            : 'Input Progress Hari Ini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat(
                      'EEEE, dd MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.now()),
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 16),

                  Container(
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
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Color(0xFF2D3142), fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Hasil Hari Ini ($unit)',
                        hintText: 'Contoh: 100',
                        labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                        prefixIcon: Icon(
                          Icons.trending_up_rounded,
                          color: Color(0xFFFF6B9D),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Color(0xFFFF6B9D),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                  ),
                  const SizedBox(height: 16),

                  Container(
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
                    child: TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 200,
                      style: TextStyle(color: Color(0xFF2D3142), fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Catatan tentang pencapaian hari ini...',
                        labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                        prefixIcon: Icon(
                          Icons.note_alt_outlined,
                          color: Color(0xFFFF6B9D),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Color(0xFFFF6B9D),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF6B9D).withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading ? null : _saveProgress,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _hasInputToday
                                          ? Icons.update_rounded
                                          : Icons.save_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      _hasInputToday
                                          ? 'Update Progress'
                                          : 'Simpan Progress',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // History Section
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B9D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: Color(0xFFFF6B9D),
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Riwayat Input',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
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
        Text(label, style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(32),
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
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat input',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ],
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

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isToday ? Color(0xFFFFF5F9) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isToday
                    ? Border.all(color: Color(0xFFFF6B9D), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isToday ? 0.08 : 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          )
                        : null,
                    color: isToday ? null : Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM', 'id_ID').format(date).toUpperCase(),
                        style: TextStyle(
                          color: isToday ? Colors.white : Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: isToday ? Colors.white : Color(0xFF2D3142),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE', 'id_ID').format(date),
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'HARI INI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: notes != null && notes.isNotEmpty
                    ? Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          notes,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$dailyValue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      Text(
                        widget.targetData['unit'],
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
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
