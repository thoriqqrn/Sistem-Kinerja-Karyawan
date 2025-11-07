import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Laporan Bonus',
          style: TextStyle(
            color: Color(0xFF2D3142),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFFFF6B9D),
              unselectedLabelColor: Color(0xFF9CA3AF),
              indicatorColor: Color(0xFFFF6B9D),
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_outline_rounded),
                  text: "Per Karyawan",
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_rounded),
                  text: "Per Periode",
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list_rounded, color: Color(0xFFFF6B9D)),
            tooltip: 'Filter Periode',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 12),
                    Text('Semua Periode'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'thisMonth',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 12),
                    Text('Bulan Ini'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lastMonth',
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 12),
                    Text('Bulan Lalu'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'thisYear',
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(width: 12),
                    Text('Tahun Ini'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'custom',
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 20,
                      color: Color(0xFFFF6B9D),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Pilih Tanggal',
                      style: TextStyle(color: Color(0xFFFF6B9D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedPeriod != 'all')
            IconButton(
              icon: Icon(Icons.clear_rounded, color: Color(0xFFEF5350)),
              tooltip: 'Hapus Filter',
              onPressed: _clearDateFilter,
            ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Info Banner
          if (_selectedPeriod != 'all')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF6B9D).withOpacity(0.1),
                    Color(0xFFFF8FB3).withOpacity(0.1),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFFF6B9D).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B9D).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.filter_alt_rounded,
                      color: Color(0xFFFF6B9D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getFilterText(),
                      style: TextStyle(
                        color: Color(0xFF2D3142),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
        .where('status', isEqualTo: BonusStatus.paid);

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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Belum ada data bonus untuk periode ini",
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Data bonus akan muncul di sini setelah dibayarkan",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF9CA3AF),
                  ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Total Bonus Dibayarkan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    FinanceUtils.formatCurrency(totalBonus),
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
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                        color: Colors.white,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            childrenPadding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 12,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B9D),
                                    Color(0xFFFF8FB3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  employeeName
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              employeeName.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "${bonuses.length} bonus diterima",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                FinanceUtils.formatCurrency(totalEmployeeBonus),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF6B9D),
                                ),
                              ),
                            ),
                            children: bonuses.map((bonus) {
                              final paidAt = bonus['paidAt'] as Timestamp?;
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF6B9D,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.monetization_on_outlined,
                                        color: Color(0xFFFF6B9D),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            FinanceUtils.formatCurrency(
                                              bonus['bonusAmount'],
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF2D3142),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            paidAt != null
                                                ? DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(paidAt.toDate())
                                                : 'N/A',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (bonus['invoiceGenerated'] == true)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 20,
                                            color: Color(0xFFEF5350),
                                          ),
                                          onPressed: () async {
                                            await _showInvoice(context, bonus);
                                          },
                                          padding: const EdgeInsets.all(8),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
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

  Future<void> _showInvoice(
    BuildContext context,
    Map<String, dynamic> bonus,
  ) async {
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

      final pdfBytes = await FinanceUtils.generateInvoicePdf(
        requestData: bonus,
        employeeName: employeeDoc.data()?['fullName'] ?? 'Unknown',
        submissionData: submissionDoc.data() ?? {},
        targetData: targetDoc.data() ?? {},
      );

      if (context.mounted) {
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
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
        .where('status', isEqualTo: BonusStatus.paid)
        .orderBy('paidAt', descending: true);

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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Belum ada data bonus untuk periode ini",
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Pilih periode lain untuk melihat data bonus",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF9CA3AF),
                  ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Total Bonus Periode Ini",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    FinanceUtils.formatCurrency(totalBonus),
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE8E8E8)),
                    ),
                    color: Colors.white,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        childrenPadding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B9D), Color(0xFFFF8FB3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          monthKey,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "${bonuses.length} transaksi",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            FinanceUtils.formatCurrency(monthTotal),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B9D),
                            ),
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

                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF6B9D),
                                            Color(0xFFFF8FB3),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          employeeName
                                              .toString()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            employeeName.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2D3142),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            paidAt != null
                                                ? DateFormat(
                                                    'dd MMM yyyy, HH:mm',
                                                    'id_ID',
                                                  ).format(paidAt.toDate())
                                                : 'N/A',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          FinanceUtils.formatCurrency(
                                            bonus['bonusAmount'],
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFFFF6B9D),
                                          ),
                                        ),
                                        if (bonus['invoiceGenerated'] ==
                                            true) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 18,
                                                color: Color(0xFFEF5350),
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () async {
                                                await _showInvoice(
                                                  context,
                                                  bonus,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
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

  Future<void> _showInvoice(
    BuildContext context,
    Map<String, dynamic> bonus,
  ) async {
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

      final pdfBytes = await FinanceUtils.generateInvoicePdf(
        requestData: bonus,
        employeeName: employeeDoc.data()?['fullName'] ?? 'Unknown',
        submissionData: submissionDoc.data() ?? {},
        targetData: targetDoc.data() ?? {},
      );

      if (context.mounted) {
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
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
