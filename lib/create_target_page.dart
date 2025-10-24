// lib/create_target_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateTargetPage extends StatefulWidget {
  const CreateTargetPage({super.key});

  @override
  State<CreateTargetPage> createState() => _CreateTargetPageState();
}

class _CreateTargetPageState extends State<CreateTargetPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController();

  String? _selectedEmployeeId;
  String? _selectedPeriod;
  DateTime? _selectedDeadline;

  bool _isLoading = false;
  List<DropdownMenuItem<String>> _employeeDropdownItems = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  // Fungsi untuk mengambil data karyawan dari Firestore
  Future<void> _fetchEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      final employees = snapshot.docs.map((doc) {
        return DropdownMenuItem<String>(
          value: doc.id,
          child: Text(doc['fullName']),
        );
      }).toList();

      setState(() {
        _employeeDropdownItems = employees;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal memuat data karyawan: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi untuk memilih tanggal deadline
  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  // Fungsi untuk menyimpan target ke Firestore
  Future<void> _saveTarget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedEmployeeId == null ||
        _selectedPeriod == null ||
        _selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Harap lengkapi semua field termasuk deadline."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Set deadline ke akhir hari (23:59:59)
      final deadlineEndOfDay = DateTime(
        _selectedDeadline!.year,
        _selectedDeadline!.month,
        _selectedDeadline!.day,
        23,
        59,
        59,
      );

      await FirebaseFirestore.instance.collection('targets').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'targetValue': int.tryParse(_targetValueController.text.trim()) ?? 0,
        'unit': _unitController.text.trim(),
        'period': _selectedPeriod,
        'employeeId': _selectedEmployeeId,
        'deadline': Timestamp.fromDate(deadlineEndOfDay),
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan target: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buat Target Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdown untuk memilih karyawan
              DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                hint: const Text("Pilih Karyawan"),
                items: _employeeDropdownItems,
                onChanged: (value) {
                  setState(() {
                    _selectedEmployeeId = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Harap pilih karyawan' : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Input Judul Target
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Target',
                  hintText: 'Contoh: Penjualan Produk X',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // Input Deskripsi
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Target',
                  hintText: 'Jelaskan detail target...',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Input Nilai Target
              TextFormField(
                controller: _targetValueController,
                decoration: const InputDecoration(
                  labelText: 'Nilai Target (Angka)',
                  hintText: 'Contoh: 100',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty ? 'Nilai target tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // Input Satuan
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  hintText: 'Contoh: unit, laporan, proyek',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Satuan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // Dropdown untuk memilih periode
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                hint: const Text("Pilih Periode Target"),
                items: ['Mingguan', 'Bulanan', 'Kuartal'].map((period) {
                  return DropdownMenuItem<String>(
                    value: period.toLowerCase(),
                    child: Text(period),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Harap pilih periode' : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Pilih Deadline
              InkWell(
                onTap: _selectDeadline,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Deadline',
                    prefixIcon: const Icon(Icons.event),
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedDeadline != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedDeadline = null;
                              });
                            },
                          )
                        : const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _selectedDeadline != null
                        ? _formatDate(_selectedDeadline!)
                        : 'Pilih tanggal deadline',
                    style: TextStyle(
                      color: _selectedDeadline != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),

              // Info deadline
              if (_selectedDeadline != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Karyawan harus mengirim hasil kerja sebelum tanggal ini. Keterlambatan akan tercatat.',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Tombol Simpan
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _saveTarget,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Target'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
