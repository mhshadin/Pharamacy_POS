import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import '../../models/sale_record.dart';
import '../../providers/language_provider.dart';
import '../../widgets/taka_symbol.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  String _selectedPeriod = 'Today';
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isLoading = false;
  List<SaleRecord> _sales = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final admin = context.read<AdminProvider>();
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (_selectedPeriod == 'Today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedPeriod == 'This Week') {
      start = now.subtract(const Duration(days: 7));
    } else if (_selectedPeriod == 'This Month') {
      start = DateTime(now.year, now.month, 1);
    } else if (_selectedPeriod == 'Last 30 Days') {
      start = now.subtract(const Duration(days: 30));
    } else if (_selectedPeriod == 'Custom') {
      start = _customStart ?? now.subtract(const Duration(days: 7));
      end = _customEnd ?? now;
    } else {
      start = DateTime(now.year, now.month, now.day);
    }

    try {
      final sales = await admin.fetchSalesInRange(start, end);
      if (mounted) {
        setState(() {
          _sales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
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
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _selectedPeriod = 'Custom';
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final totalRevenue = _sales.fold(0.0, (sum, s) => sum + s.effectiveAmount);
    final totalCost = _sales.fold(0.0, (sum, s) => sum + s.effectiveCost);
    final totalProfit = totalRevenue - totalCost;
    final margin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profitReport),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ResponsiveHelper.screenPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(context),
                    const SizedBox(height: 16),
                    _buildSummaryCards(totalRevenue, totalCost, totalProfit, margin, l10n),
                    const SizedBox(height: 24),
                    if (_sales.isEmpty)
                      Center(
                        child: Text(
                          l10n.profitReportEmpty,
                          style: const TextStyle(color: AppColors.secondaryAccent),
                        ),
                      )
                    else ...[
                      _buildProductBreakdown(l10n),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final l10n = context.read<LanguageProvider>().strings;
    final periods = ['Today', 'This Week', 'This Month', 'Last 30 Days', 'Custom'];
    final labels = [l10n.today, l10n.thisWeek, l10n.thisMonth, 'Last 30 Days', 'Custom'];

    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final p = periods[index];
          final label = labels[index];
          final isSelected = _selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (val) {
                if (p == 'Custom') {
                  _pickCustomDateRange();
                } else {
                  setState(() => _selectedPeriod = p);
                  _loadData();
                }
              },
              selectedColor: AppColors.primaryDark.withOpacity(0.1),
              checkmarkColor: AppColors.primaryDark,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryDark : AppColors.secondaryAccent,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryDark : AppColors.divider,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(double revenue, double cost, double profit, double margin, var l10n) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildSummaryCard(
            title: l10n.totalRevenue,
            value: revenue,
            icon: LucideIcons.trendingUp,
            color: AppColors.primaryDark,
          ),
          _buildSummaryCard(
            title: l10n.totalCost,
            value: cost,
            icon: LucideIcons.shoppingBag,
            color: Colors.orange,
          ),
          _buildSummaryCard(
            title: l10n.grossProfit,
            value: profit,
            icon: LucideIcons.coins,
            color: AppColors.success,
            isCurrency: true,
          ),
          _buildSummaryCard(
            title: l10n.profitMargin,
            value: margin,
            icon: LucideIcons.percent,
            color: AppColors.secondaryAccent,
            isPercent: true,
          ),
        ],
      );
    });
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    bool isCurrency = true,
    bool isPercent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (isCurrency && !isPercent) ...[
                  const TakaSymbol(size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 2),
                ],
                Text(
                  isPercent ? value.toStringAsFixed(1) : value.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (isPercent)
                  const Text(
                    '%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProductBreakdown(var l10n) {
    // Aggregate by product
    final Map<String, _ProfitStats> stats = {};
    for (var s in _sales) {
      if (!stats.containsKey(s.productName)) {
        stats[s.productName] = _ProfitStats();
      }
      final st = stats[s.productName]!;
      st.quantity += s.effectiveQuantity;
      st.revenue += s.effectiveAmount;
      st.cost += s.effectiveCost;
    }

    final sortedStats = stats.entries.toList()
      ..sort((a, b) => (b.value.revenue - b.value.cost).compareTo(a.value.revenue - a.value.cost));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.productBreakdown,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedStats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = sortedStats[index];
            final name = entry.key;
            final s = entry.value;
            final profit = s.revenue - s.cost;
            final margin = s.revenue > 0 ? (profit / s.revenue) * 100 : 0.0;
            final isLoss = profit < 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sold: ${s.quantity} pcs',
                          style: const TextStyle(fontSize: 11, color: AppColors.secondaryAccent),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const TakaSymbol(size: 13, color: AppColors.primaryDark),
                          Text(
                            profit.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isLoss ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${margin.toStringAsFixed(1)}% margin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isLoss ? AppColors.error : AppColors.success.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProfitStats {
  int quantity = 0;
  double revenue = 0.0;
  double cost = 0.0;
}
