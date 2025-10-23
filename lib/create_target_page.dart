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
          value: doc.id, // Value-nya adalah UID
          child: Text(doc['fullName']), // Yang ditampilkan adalah nama
        );
      }).toList();

      setState(() {
        _employeeDropdownItems = employees;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat data karyawan: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // Fungsi untuk menyimpan target ke Firestore
  Future<void> _saveTarget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedEmployeeId == null || _selectedPeriod == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Harap pilih karyawan dan periode."), backgroundColor: Colors.red),
        );
        return;
    }

    setState(() { _isLoading = true; });

    try {
      await FirebaseFirestore.instance.collection('targets').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'targetValue': int.tryParse(_targetValueController.text.trim()) ?? 0,
        'unit': _unitController.text.trim(),
        'period': _selectedPeriod,
        'employeeId': _selectedEmployeeId,
        'status': 'active', // Status awal target
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Target berhasil dibuat!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan target: $e"), backgroundColor: Colors.red),
        );
       }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
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
      appBar: AppBar(
        title: Text("Buat Target Baru"),
      ),
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
                hint: Text("Pilih Karyawan"),
                items: _employeeDropdownItems,
                onChanged: (value) {
                  setState(() {
                    _selectedEmployeeId = value;
                  });
                },
                validator: (value) => value == null ? 'Harap pilih karyawan' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Judul Target (Contoh: Penjualan Produk X)'),
                validator: (value) => value!.isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Deskripsi Target'),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _targetValueController,
                decoration: InputDecoration(labelText: 'Nilai Target (Angka)'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Nilai target tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),
               TextFormField(
                controller: _unitController,
                decoration: InputDecoration(labelText: 'Satuan (Contoh: unit, laporan, proyek)'),
                validator: (value) => value!.isEmpty ? 'Satuan tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),
              // Dropdown untuk memilih periode
              DropdownButtonFormField<String>(
                value: _selectedPeriod,
                hint: Text("Pilih Periode Target"),
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
                 validator: (value) => value == null ? 'Harap pilih periode' : null,
              ),
              SizedBox(height: 32),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveTarget,
                      child: Text('Simpan Target'),
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