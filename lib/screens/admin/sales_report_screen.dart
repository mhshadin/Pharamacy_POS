import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import '../../models/sale_record.dart';
import '../../services/export_service.dart';
import '../../widgets/taka_symbol.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_strings.dart';
import 'profit_report_screen.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  static List<String> _getPeriodPresets(AppStrings l10n) => [
    l10n.today,
    l10n.thisWeek,
    l10n.thisMonth,
    l10n.last3Months,
    'All',
    l10n.customRange,
  ];

  static List<String> _getSortOptions(AppStrings l10n) => [
    l10n.newestFirst,
    l10n.oldestFirst,
    l10n.amountHigh,
    l10n.amountLow,
    l10n.productAZ,
  ];

  String _chartPeriod = 'Week';
  String _listFilter = '';
  String _sortBy = '';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
  }

  bool _initialized = false;

  List<double> _getWeeklyData(List<SaleRecord> sales) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final data = List.filled(7, 0.0);
    for (var s in sales) {
      if (!s.date.isBefore(startOfWeek)) {
        final diff = s.date.difference(startOfWeek).inDays;
        if (diff >= 0 && diff < 7) {
          data[diff] += s.effectiveAmount;
        }
      }
    }
    return data;
  }

  List<double> _getMonthlyData(List<SaleRecord> sales) {
    final currentYear = DateTime.now().year;
    final data = List.filled(12, 0.0);
    for (var s in sales) {
      if (s.date.year == currentYear) {
        data[s.date.month - 1] += s.effectiveAmount;
      }
    }
    return data;
  }

  List<double> _getYearlyData(List<SaleRecord> sales) {
    final currentYear = DateTime.now().year;
    final data = List.filled(5, 0.0);
    for (var s in sales) {
      if (s.date.year > currentYear - 5 && s.date.year <= currentYear) {
        final idx = 4 - (currentYear - s.date.year);
        data[idx] += s.effectiveAmount;
      }
    }
    return data;
  }

  List<String> _getYearlyLabels() {
    final currentYear = DateTime.now().year;
    return List.generate(5, (i) => (currentYear - 4 + i).toString());
  }

  List<double> _getBarData(List<SaleRecord> sales) {
    if (_chartPeriod == 'Month') return _getMonthlyData(sales);
    if (_chartPeriod == 'Year') return _getYearlyData(sales);
    return _getWeeklyData(sales);
  }

  List<String> _getLabels(AppStrings l10n) {
    if (_chartPeriod == 'Month') {
      return [
        l10n.jan,
        l10n.feb,
        l10n.mar,
        l10n.apr,
        l10n.may,
        l10n.jun,
        l10n.jul,
        l10n.aug,
        l10n.sep,
        l10n.oct,
        l10n.nov,
        l10n.dec,
      ];
    }
    if (_chartPeriod == 'Year') return _getYearlyLabels();
    return [
      l10n.mon,
      l10n.tue,
      l10n.wed,
      l10n.thu,
      l10n.fri,
      l10n.sat,
      l10n.sun,
    ];
  }

  double _getBarMaxY(List<double> barData) {
    if (barData.isEmpty) return 100.0;
    final maxVal = barData.reduce((a, b) => a > b ? a : b);
    return maxVal == 0 ? 100.0 : (maxVal * 1.2).ceilToDouble();
  }

  String _getSummaryLabel(AppStrings l10n) => _chartPeriod == 'Month'
      ? l10n.monthly
      : _chartPeriod == 'Year'
      ? l10n.yearly
      : l10n.weekly;

  double _getPeriodTotal(List<double> barData) {
    if (barData.isEmpty) return 0.0;
    return barData.reduce((a, b) => a + b);
  }

  List<SaleRecord> _getFilteredSales(AdminProvider admin, AppStrings l10n) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (_listFilter == l10n.today) {
      start = DateTime(now.year, now.month, now.day);
    } else if (_listFilter == l10n.thisWeek) {
      start = now.subtract(const Duration(days: 7));
    } else if (_listFilter == l10n.thisMonth) {
      start = DateTime(now.year, now.month, 1);
    } else if (_listFilter == l10n.last3Months) {
      start = DateTime(now.year, now.month - 3, now.day);
    } else if (_listFilter == l10n.customRange) {
      start = _customStart ?? now.subtract(const Duration(days: 7));
      end = _customEnd ?? now;
    } else {
      start = now.subtract(const Duration(days: 365));
    }

    var sales = admin.getSalesInRange(start, end);

    if (_sortBy == l10n.newestFirst) {
      sales.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == l10n.oldestFirst) {
      sales.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == l10n.amountHigh) {
      sales.sort((a, b) => b.effectiveAmount.compareTo(a.effectiveAmount));
    } else if (_sortBy == l10n.amountLow) {
      sales.sort((a, b) => a.effectiveAmount.compareTo(b.effectiveAmount));
    } else if (_sortBy == l10n.productAZ) {
      sales.sort((a, b) => a.productName.compareTo(b.productName));
    }
    return sales;
  }

  void _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _customStart ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _customEnd ?? DateTime.now(),
      ),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: AppColors.white,
              surface: AppColors.background,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final l10n = context.read<LanguageProvider>().strings;
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _listFilter = l10n.customRange;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final l10n = context.read<LanguageProvider>().strings;
      _listFilter = l10n.thisWeek;
      _sortBy = l10n.newestFirst;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final l10n = context.watch<LanguageProvider>().strings;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final filteredSales = _getFilteredSales(admin, l10n);

    final Map<String, List<SaleRecord>> groupedSales = {};
    for (var s in filteredSales) {
      final inv = s.invoiceNumber ?? 'N/A';
      groupedSales.putIfAbsent(inv, () => []).add(s);
    }
    final invoiceNumbers = groupedSales.keys.toList();

    final filteredTotal = filteredSales.fold(
      0.0,
      (sum, s) => sum + s.effectiveAmount,
    );
    final filteredQty = filteredSales.fold(
      0,
      (sum, s) => sum + s.effectiveQuantity,
    );

    final barData = _getBarData(admin.allSales);
    final barMaxY = _getBarMaxY(barData);
    final periodTotal = _getPeriodTotal(barData);

    return SingleChildScrollView(
      padding: ResponsiveHelper.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = isTablet
                  ? (constraints.maxWidth - 24) / 3
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: l10n.todaysSales,
                      value: admin.todaysSales.toStringAsFixed(2),
                      icon: LucideIcons.wallet,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: l10n.totalOrders,
                      value: '${admin.todaysOrders}',
                      icon: LucideIcons.shoppingCart,
                      color: AppColors.secondaryAccent,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      title: '${_getSummaryLabel(l10n)} ${l10n.totalRevenue}',
                      value: periodTotal.toStringAsFixed(0),
                      icon: LucideIcons.trendingUp,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          _buildChipSelector(
            items: [l10n.weekly, l10n.monthly, l10n.yearly],
            selected: _chartPeriod == 'Month'
                ? l10n.monthly
                : _chartPeriod == 'Year'
                ? l10n.yearly
                : l10n.weekly,
            onSelected: (v) {
              setState(() {
                if (v == l10n.monthly) {
                  _chartPeriod = 'Month';
                } else if (v == l10n.yearly) {
                  _chartPeriod = 'Year';
                } else {
                  _chartPeriod = 'Week';
                }
              });
            },
          ),

          const SizedBox(height: 16),

          _buildLineChart(barData, barMaxY, l10n),

          const SizedBox(height: 16),

          _buildPieChart(admin.allSales, l10n),

          const SizedBox(height: 24),

          _buildProfitReportCTA(context, l10n),

          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.list,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.transactionHistory,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          LucideIcons.download,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        tooltip: l10n.filter,
                        onSelected: (String value) async {
                          final title =
                              _listFilter == 'Custom' &&
                                  _customStart != null &&
                                  _customEnd != null
                              ? '${_customStart!.day}-${_customStart!.month}-${_customStart!.year}_to_${_customEnd!.day}-${_customEnd!.month}-${_customEnd!.year}'
                              : _listFilter;

                          String? savedPath;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );

                          try {
                            if (value == 'csv') {
                              savedPath = await ExportService.exportToCsv(
                                filteredSales,
                                title,
                              );
                            } else if (value == 'pdf') {
                              savedPath = await ExportService.exportToPdf(
                                sales: filteredSales,
                                title: title,
                              );
                            }

                            if (savedPath != null) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.reportSaved),
                                  duration: const Duration(seconds: 5),
                                  action: SnackBarAction(
                                    label: l10n.open,
                                    onPressed: () {
                                      OpenFile.open(savedPath!);
                                    },
                                  ),
                                ),
                              );
                            } else {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.reportFailed),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(l10n.exportError(e.toString())),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'csv',
                                child: ListTile(
                                  leading: const Icon(
                                    LucideIcons.fileSpreadsheet,
                                  ),
                                  title: Text(l10n.exportCsv),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'pdf',
                                child: ListTile(
                                  leading: const Icon(LucideIcons.fileCog),
                                  title: Text(l10n.exportPdf),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 8.0;
                      final inputBorder = OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.divider),
                      );
                      final periodField = InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.period,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: const BorderSide(
                              color: AppColors.primaryDark,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _listFilter == 'Custom' ? null : _listFilter,
                            hint: _listFilter == 'Custom'
                                ? Text(
                                    _customStart != null && _customEnd != null
                                        ? '${l10n.customRange} ${_customStart!.day}/${_customStart!.month} – ${_customEnd!.day}/${_customEnd!.month}'
                                        : l10n.customRange,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.primaryDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            items: _getPeriodPresets(l10n)
                                .map(
                                  (p) => DropdownMenuItem<String>(
                                    value: p,
                                    child: Text(
                                      p,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              if (v == l10n.customRange) {
                                _pickCustomDateRange();
                                return;
                              }
                              setState(() {
                                _listFilter = v;
                                _customStart = null;
                                _customEnd = null;
                              });
                            },
                          ),
                        ),
                      );
                      final sortField = InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.sortBy,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: const BorderSide(
                              color: AppColors.primaryDark,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _sortBy,
                            items: _getSortOptions(l10n)
                                .map(
                                  (s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(
                                      s,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _sortBy = v);
                            },
                          ),
                        ),
                      );
                      if (constraints.maxWidth >= 520) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: periodField),
                            const SizedBox(width: gap),
                            Expanded(child: sortField),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          periodField,
                          const SizedBox(height: gap),
                          sortField,
                        ],
                      );
                    },
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniStat(
                        label: l10n.orders,
                        value: '${filteredSales.length}',
                      ),
                      _MiniStat(label: l10n.itemsSold, value: '$filteredQty'),
                      _MiniStat(
                        label: l10n.totalRevenue,
                        amount: filteredTotal.toStringAsFixed(2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (filteredSales.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.searchX,
                            size: 40,
                            color: AppColors.secondaryAccent,
                          ),
                          SizedBox(height: 8),
                          Text(
                            l10n.noTransactionsFound,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryAccent,
                            ),
                          ),
                          Text(
                            l10n.tryAnotherFilter,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: invoiceNumbers.length,
                    itemBuilder: (_, idx) {
                      final invNo = invoiceNumbers[idx];
                      final items = groupedSales[invNo]!;
                      final totalAmount = items.fold(
                        0.0,
                        (sum, s) => sum + s.effectiveAmount,
                      );
                      final firstDate = items.first.date;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.fileText,
                              color: AppColors.primaryDark,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            invNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                '${firstDate.day}/${firstDate.month}/${firstDate.year} • ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryAccent,
                                ),
                              ),
                              const TakaSymbol(
                                size: 12,
                                color: AppColors.secondaryAccent,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                totalAmount.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryAccent,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            ...items.map(
                              (sale) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sale.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (sale.batchNumber != null)
                                            Text(
                                              '${l10n.batchLabel}: ${sale.batchNumber}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.secondaryAccent,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${l10n.qtyLabel}: ${sale.effectiveQuantity}${sale.returnedQuantity > 0 ? '\n(${l10n.retLabel}: ${sale.returnedQuantity})' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const TakaSymbol(
                                            size: 13,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            sale.effectiveAmount
                                                .toStringAsFixed(2),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.success,
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSelector({
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: items.map((p) {
          final isActive = selected == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.white
                          : AppColors.secondaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart(List<SaleRecord> sales, AppStrings l10n) {
    if (sales.isEmpty) {
      return _ChartCard(
        title: l10n.topProduct,
        icon: LucideIcons.pieChart,
        child: SizedBox(
          height: (MediaQuery.of(context).size.width * 0.5).clamp(150.0, 220.0),
          child: Center(
            child: Text(
              l10n.noTransactionsFound,
              style: const TextStyle(
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    Map<String, double> productSales = {};
    for (var s in sales) {
      productSales[s.productName] =
          (productSales[s.productName] ?? 0) + s.effectiveAmount;
    }

    final sortedEntries = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(4).toList();

    double otherSales = 0;
    if (sortedEntries.length > 4) {
      for (int i = 4; i < sortedEntries.length; i++) {
        otherSales += sortedEntries[i].value;
      }
    }

    final colors = [
      AppColors.primaryDark,
      AppColors.secondaryAccent,
      AppColors.success,
      AppColors.warningOrange,
    ];

    final total = sales.fold(0.0, (sum, s) => sum + s.effectiveAmount);
    List<_PieData> data = [];

    for (int i = 0; i < topEntries.length; i++) {
      final pct = (topEntries[i].value / total) * 100;
      data.add(_PieData(topEntries[i].key, pct, colors[i % colors.length]));
    }
    if (otherSales > 0) {
      final pct = (otherSales / total) * 100;
      data.add(_PieData(l10n.others, pct, AppColors.highlightActive));
    }
    return _ChartCard(
      title: l10n.topProduct,
      icon: LucideIcons.pieChart,
      child: SizedBox(
        height: (MediaQuery.of(context).size.width * 0.5).clamp(150.0, 220.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 32,
                  sections: data
                      .map(
                        (d) => PieChartSectionData(
                          value: d.value,
                          color: d.color,
                          radius: 50,
                          title: '${d.value.toInt()}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: data
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: d.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                d.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(
    List<double> barData,
    double barMaxY,
    AppStrings l10n,
  ) {
    final labels = _getLabels(l10n);
    return _ChartCard(
      title: '${l10n.revenueTrend} (${_getSummaryLabel(l10n)})',
      icon: LucideIcons.trendingUp,
      child: SizedBox(
        height: (MediaQuery.of(context).size.width * 0.5).clamp(150.0, 220.0),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: barMaxY,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
                        '৳${s.y.toStringAsFixed(0)}',
                        const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: barMaxY == 0 ? 1 : barMaxY / 4,
              getDrawingHorizontalLine: (v) =>
                  const FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) {
                    if (v.toInt() >= 0 && v.toInt() < labels.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[v.toInt()],
                          style: const TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: barMaxY == 0 ? 1 : barMaxY / 4,
                  getTitlesWidget: (v, m) {
                    return Text(
                      '৳${v.toInt()}',
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  barData.length,
                  (i) => FlSpot(i.toDouble(), barData[i]),
                ),
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primaryDark,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.white,
                    strokeWidth: 2.5,
                    strokeColor: AppColors.primaryDark,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.secondaryAccent.withValues(alpha: 0.3),
                      AppColors.secondaryAccent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfitReportCTA(BuildContext context, AppStrings l10n) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfitReportScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryDark, Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.lineChart,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.viewProfitReport,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.buyingPriceHelper,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _PieData {
  final String label;
  final double value;
  final Color color;
  _PieData(this.label, this.value, this.color);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String? value;
  final String? amount;
  const _MiniStat({required this.label, this.value, this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (value != null)
          Text(
            value!,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.primaryDark,
            ),
          )
        else if (amount != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TakaSymbol(size: 14, color: AppColors.primaryDark),
              const SizedBox(width: 4),
              Text(
                amount!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: AppColors.secondaryAccent,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryAccent,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TakaSymbol(size: 20, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
