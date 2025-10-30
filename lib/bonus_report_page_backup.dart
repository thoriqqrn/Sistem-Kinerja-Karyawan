import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'utils/finance_utils.dart';
import 'utils/constants.dart';
import 'widgets/pdf_preview_page.dart';

class BonusReportPage extends StatefulWidget {
  const BonusReportPage({super.key});

  @override
  State<BonusReportPage> createState() => _BonusReportPageState();
}

class _BonusReportPageState extends State<BonusReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'custom';
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedPeriod = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Bonus"),
        backgroundColor: Colors.green[700],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: "Per Karyawan"),
            Tab(icon: Icon(Icons.calendar_month), text: "Per Periode"),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Periode',
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                if (value != 'custom') {
                  _startDate = null;
                  _endDate = null;
                }
              });
              if (value == 'custom') {
                _selectDateRange();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Semua Periode')),
              const PopupMenuItem(value: 'thisMonth', child: Text('Bulan Ini')),
              const PopupMenuItem(
                value: 'lastMonth',
                child: Text('Bulan Lalu'),
              ),
              const PopupMenuItem(value: 'thisYear', child: Text('Tahun Ini')),
              const PopupMenuItem(
                value: 'custom',
                child: Text('Pilih Tanggal'),
              ),
            ],
          ),
          if (_selectedPeriod != 'all')
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Hapus Filter',
              onPressed: _clearDateFilter,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Info Banner
          if (_selectedPeriod != 'all')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFilterText(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BonusReportByEmployee(
                  startDate: _startDate,
                  endDate: _endDate,
                  period: _selectedPeriod,
                ),
                BonusReportByPeriod(
                  startDate: _startDate,
                  endDate: _endDate,
                  period: _selectedPeriod,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterText() {
    switch (_selectedPeriod) {
      case 'thisMonth':
        return 'Menampilkan: Bulan Ini';
      case 'lastMonth':
        return 'Menampilkan: Bulan Lalu';
      case 'thisYear':
        return 'Menampilkan: Tahun Ini';
      case 'custom':
        if (_startDate != null && _endDate != null) {
          return 'Periode: ${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
        }
        return 'Pilih rentang tanggal';
      default:
        return 'Semua Periode';
    }
  }
}

// ===============================================================
// =============== LAPORAN PER KARYAWAN ==========================
// ===============================================================

class BonusReportByEmployee extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String period;

  const BonusReportByEmployee({
    Key? key,
    this.startDate,
    this.endDate,
    required this.period,
  }) : super(key: key);

  Query<Map<String, dynamic>> _getQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('bonus_requests')
        .where('status', isEqualTo: 'paid');

    // Apply date filter
    if (period == 'custom' && startDate != null && endDate != null) {
      query = query
          .where(
            'paidAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!),
          )
          .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    } else if (period == 'thisMonth') {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      query = query.where(
        'paidAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay),
      );
    } else if (period == 'lastMonth') {
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final lastDayLastMonth = firstDayThisMonth.subtract(
        const Duration(days: 1),
      );
      final firstDayLastMonth = DateTime(
        lastDayLastMonth.year,
        lastDayLastMonth.month,
        1,
      );
      query = query
          .where(
            'paidAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayLastMonth),
          )
          .where(
            'paidAt',
            isLessThanOrEqualTo: Timestamp.fromDate(lastDayLastMonth),
          );
    } else if (period == 'thisYear') {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, 1, 1);
      query = query.where(
        'paidAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay),
      );
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Belum ada data bonus untuk periode ini",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Group by employee
        Map<String, List<Map<String, dynamic>>> groupedData = {};
        int totalBonus = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final employeeId = data['employeeId'] as String;
          final bonusAmount = data['bonusAmount'] as int? ?? 0;

          if (!groupedData.containsKey(employeeId)) {
            groupedData[employeeId] = [];
          }
          groupedData[employeeId]!.add({...data, 'id': doc.id});
          totalBonus += bonusAmount;
        }

        return Column(
          children: [
            // Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "Total Bonus Dibayarkan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(totalBonus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${groupedData.length} Karyawan | ${snapshot.data!.docs.length} Transaksi",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Employee List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupedData.length,
                itemBuilder: (context, index) {
                  final employeeId = groupedData.keys.elementAt(index);
                  final bonuses = groupedData[employeeId]!;
                  final totalEmployeeBonus = bonuses.fold<int>(
                    0,
                    (sum, b) => sum + (b['bonusAmount'] as int? ?? 0),
                  );

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(employeeId)
                        .get(),
                    builder: (context, empSnapshot) {
                      final employeeName = empSnapshot.data?.data() != null
                          ? (empSnapshot.data!.data()
                                as Map<String, dynamic>)['fullName']
                          : 'Loading...';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Text(
                              employeeName
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            employeeName.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${bonuses.length} bonus diterima"),
                          trailing: Text(
                            _formatCurrency(totalEmployeeBonus),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          children: bonuses.map((bonus) {
                            final paidAt = bonus['paidAt'] as Timestamp?;
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.monetization_on,
                                color: Colors.green,
                                size: 20,
                              ),
                              title: Text(
                                _formatCurrency(bonus['bonusAmount']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                paidAt != null
                                    ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(paidAt.toDate())
                                    : 'N/A',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: bonus['invoiceGenerated'] == true
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 20,
                                      ),
                                      color: Colors.red[700],
                                      onPressed: () async {
                                        // Generate invoice untuk bonus ini
                                        try {
                                          // Fetch data lengkap
                                          final employeeDoc = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(bonus['employeeId'])
                                              .get();
                                          
                                          final submissionDoc = await FirebaseFirestore.instance
                                              .collection('performance_submissions')
                                              .doc(bonus['submissionId'])
                                              .get();
                                          
                                          final targetDoc = await FirebaseFirestore.instance
                                              .collection('targets')
                                              .doc(bonus['targetId'])
                                              .get();

                                          final pdfBytes = await _generatePdfFromData(
                                            requestData: bonus,
                                            employeeName: employeeDoc.data()?['fullName'] ?? 'Unknown',
                                            submissionData: submissionDoc.data() ?? {},
                                            targetData: targetDoc.data() ?? {},
                                          );

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PdfPreviewPage(
                                                pdfBytes: pdfBytes,
                                                title: 'Invoice Bonus',
                                                filename: 'invoice_${bonus['id']}.pdf',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $e"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _generatePdfFromData({
    required Map<String, dynamic> requestData,
    required String employeeName,
    required Map<String, dynamic> submissionData,
    required Map<String, dynamic> targetData,
  }) async {
    final pdf = pw.Document();
    final bonusAmount = requestData['bonusAmount'] ?? 0;
    final invoiceNumber = 'INV-${(requestData['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
    final paidAt = (requestData['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PT NAMA PERUSAHAAN', 
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Invoice Bonus Karyawan', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE', 
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoiceNumber, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 24),
                pw.Text('Kepada:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(employeeName, style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text('ID Karyawan: ${requestData['employeeId']}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Detail Bonus', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      _buildPdfRow('Target', targetData['title'] ?? 'N/A'),
                      _buildPdfRow('Periode', targetData['period'] ?? 'N/A'),
                      _buildPdfRow('Pencapaian', 
                        '${submissionData['achievedValue']} / ${targetData['targetValue']} ${targetData['unit'] ?? ''}'),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL BONUS:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(_formatCurrency(bonusAmount), 
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Text('Tanggal Pencairan: ${DateFormat('dd MMMM yyyy', 'id_ID').format(paidAt)}', 
                  style: const pw.TextStyle(fontSize: 10)),
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('Terima kasih atas kontribusi Anda!', 
                    style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}

// ===============================================================
// =============== LAPORAN PER PERIODE ===========================
// ===============================================================

class BonusReportByPeriod extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String period;

  const BonusReportByPeriod({
    Key? key,
    this.startDate,
    this.endDate,
    required this.period,
  }) : super(key: key);

  Query<Map<String, dynamic>> _getQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('bonus_requests')
        .where('status', isEqualTo: 'paid')
        .orderBy('paidAt', descending: true);

    if (period == 'custom' && startDate != null && endDate != null) {
      query = query
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    } else if (period == 'thisMonth') {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      query = query.where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay));
    } else if (period == 'lastMonth') {
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final lastDayLastMonth = firstDayThisMonth.subtract(const Duration(days: 1));
      final firstDayLastMonth = DateTime(lastDayLastMonth.year, lastDayLastMonth.month, 1);
      query = query
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayLastMonth))
          .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(lastDayLastMonth));
    } else if (period == 'thisYear') {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, 1, 1);
      query = query.where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay));
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Belum ada data bonus untuk periode ini",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        Map<String, List<Map<String, dynamic>>> groupedByMonth = {};
        int totalBonus = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
          final bonusAmount = data['bonusAmount'] as int? ?? 0;

          if (paidAt != null) {
            final monthKey = DateFormat('MMMM yyyy', 'id_ID').format(paidAt);
            if (!groupedByMonth.containsKey(monthKey)) {
              groupedByMonth[monthKey] = [];
            }
            groupedByMonth[monthKey]!.add({...data, 'id': doc.id});
            totalBonus += bonusAmount;
          }
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Text("Total Bonus Periode Ini",
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(_formatCurrency(totalBonus),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${snapshot.data!.docs.length} Transaksi",
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupedByMonth.length,
                itemBuilder: (context, index) {
                  final monthKey = groupedByMonth.keys.elementAt(index);
                  final bonuses = groupedByMonth[monthKey]!;
                  final monthTotal = bonuses.fold<int>(0, (sum, b) => sum + (b['bonusAmount'] as int? ?? 0));

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.calendar_month, color: Colors.blue[700]),
                      ),
                      title: Text(monthKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${bonuses.length} transaksi"),
                      trailing: Text(_formatCurrency(monthTotal),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                      children: bonuses.map((bonus) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(bonus['employeeId']).get(),
                          builder: (context, empSnapshot) {
                            final employeeName = empSnapshot.data?.data() != null
                                ? (empSnapshot.data!.data() as Map<String, dynamic>)['fullName']
                                : 'Loading...';
                            final paidAt = bonus['paidAt'] as Timestamp?;

                            return ListTile(
                              dense: true,
                              leading: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                              title: Text(employeeName.toString(), style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                  paidAt != null
                                      ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(paidAt.toDate())
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_formatCurrency(bonus['bonusAmount']),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  if (bonus['invoiceGenerated'] == true) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                                      color: Colors.red[700],
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        try {
                                          final employeeDoc = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(bonus['employeeId'])
                                              .get();
                                          final submissionDoc = await FirebaseFirestore.instance
                                              .collection('performance_submissions')
                                              .doc(bonus['submissionId'])
                                              .get();
                                          final targetDoc = await FirebaseFirestore.instance
                                              .collection('targets')
                                              .doc(bonus['targetId'])
                                              .get();

                                          final pdfBytes = await _generatePdfFromData(
                                            requestData: bonus,
                                            employeeName: employeeDoc.data()?['fullName'] ?? 'Unknown',
                                            submissionData: submissionDoc.data() ?? {},
                                            targetData: targetDoc.data() ?? {},
                                          );

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PdfPreviewPage(
                                                pdfBytes: pdfBytes,
                                                title: 'Invoice Bonus',
                                                filename: 'invoice_${bonus['id']}.pdf',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _generatePdfFromData({
    required Map<String, dynamic> requestData,
    required String employeeName,
    required Map<String, dynamic> submissionData,
    required Map<String, dynamic> targetData,
  }) async {
    final pdf = pw.Document();
    final bonusAmount = requestData['bonusAmount'] ?? 0;
    final invoiceNumber = 'INV-${(requestData['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
    final paidAt = (requestData['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PT NAMA PERUSAHAAN', 
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Invoice Bonus Karyawan', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE', 
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoiceNumber, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 24),
                pw.Text('Kepada:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(employeeName, style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 4),
                pw.Text('ID Karyawan: ${requestData['employeeId']}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Detail Bonus', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      _buildPdfRow('Target', targetData['title'] ?? 'N/A'),
                      _buildPdfRow('Periode', targetData['period'] ?? 'N/A'),
                      _buildPdfRow('Pencapaian', 
                        '${submissionData['achievedValue']} / ${targetData['targetValue']} ${targetData['unit'] ?? ''}'),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL BONUS:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(_formatCurrency(bonusAmount), 
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Text('Tanggal Pencairan: ${DateFormat('dd MMMM yyyy', 'id_ID').format(paidAt)}', 
                  style: const pw.TextStyle(fontSize: 10)),
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('Terima kasih atas kontribusi Anda!', 
                    style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatCurrency(num amount) {
    return FinanceUtils.formatCurrency(amount);
  }
}
}

// ===============================================================
// =============== PDF PREVIEW PAGE ==============================
// ===============================================================

class PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const PdfPreviewPage({
    Key? key,
    required this.pdfBytes,
    required this.title,
    required this.filename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.red[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan PDF',
            onPressed: () async {
              await Printing.sharePdf(bytes: pdfBytes, filename: filename);
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
            onPressed: () async {
              await Printing.layoutPdf(onLayout: (format) => pdfBytes);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: filename,
      ),
    );
  }
}