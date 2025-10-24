import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
                              trailing: bonus['invoiceUrl'] != null
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 20,
                                      ),
                                      color: Colors.red[700],
                                      onPressed: () {
                                        // TODO: Open PDF
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

        // Group by month
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
            // Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "Total Bonus Periode Ini",
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
                    "${snapshot.data!.docs.length} Transaksi",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Month List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupedByMonth.length,
                itemBuilder: (context, index) {
                  final monthKey = groupedByMonth.keys.elementAt(index);
                  final bonuses = groupedByMonth[monthKey]!;
                  final monthTotal = bonuses.fold<int>(
                    0,
                    (sum, b) => sum + (b['bonusAmount'] as int? ?? 0),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(
                          Icons.calendar_month,
                          color: Colors.blue[700],
                        ),
                      ),
                      title: Text(
                        monthKey,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("${bonuses.length} transaksi"),
                      trailing: Text(
                        _formatCurrency(monthTotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      children: bonuses.map((bonus) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(bonus['employeeId'])
                              .get(),
                          builder: (context, empSnapshot) {
                            final employeeName =
                                empSnapshot.data?.data() != null
                                ? (empSnapshot.data!.data()
                                      as Map<String, dynamic>)['fullName']
                                : 'Loading...';

                            final paidAt = bonus['paidAt'] as Timestamp?;

                            return ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person, size: 16),
                              ),
                              title: Text(
                                employeeName.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                paidAt != null
                                    ? DateFormat(
                                        'dd MMM yyyy, HH:mm',
                                        'id_ID',
                                      ).format(paidAt.toDate())
                                    : 'N/A',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatCurrency(bonus['bonusAmount']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (bonus['invoiceUrl'] != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.picture_as_pdf,
                                        size: 18,
                                      ),
                                      color: Colors.red[700],
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        // TODO: Open PDF
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Invoice URL: ${bonus['invoiceUrl']}",
                                            ),
                                            backgroundColor: Colors.blue,
                                          ),
                                        );
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

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
