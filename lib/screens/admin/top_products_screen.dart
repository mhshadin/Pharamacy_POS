import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/taka_symbol.dart';

class TopProductsScreen extends StatefulWidget {
  const TopProductsScreen({super.key});

  @override
  State<TopProductsScreen> createState() => _TopProductsScreenState();
}

class _TopProductsScreenState extends State<TopProductsScreen> {
  String _timeFrame = 'Week';

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_timeFrame) {
      case 'Today':
        return DateTimeRange(start: todayStart, end: todayStart);
      case 'Week':
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 7)),
          end: todayStart,
        );
      case 'Month':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, now.day),
          end: todayStart,
        );
      case 'Year':
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, now.day),
          end: todayStart,
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year - 100, 1, 1),
          end: todayStart,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final range = _getDateRange();
    final topProducts = admin.getTopSellingProducts(
      start: range.start,
      end: range.end,
    );

    return Column(
      children: [
        // Timeframe Selector
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          color: AppColors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Today', 'Week', 'Month', 'Year', 'All Time'].map((
                tf,
              ) {
                final isSelected = _timeFrame == tf;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tf),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _timeFrame = tf);
                    },
                    selectedColor: AppColors.primaryDark,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.white
                          : AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: AppColors.background,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: topProducts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: topProducts.length,
                  itemBuilder: (context, index) {
                    final p = topProducts[index];
                    return _buildProductCard(p, index + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.barChart3,
            size: 64,
            color: AppColors.secondaryAccent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sales data for this period',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(TopSellingProduct p, int rank) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = AppColors.secondaryAccent.withValues(alpha: 0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rankColor.withValues(alpha: 1.0),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          p.name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              const Icon(
                LucideIcons.package2,
                size: 14,
                color: AppColors.secondaryAccent,
              ),
              const SizedBox(width: 4),
              Text(
                '${p.boxesSold.toStringAsFixed(1)} boxes sold',
                style: const TextStyle(
                  color: AppColors.secondaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'REVENUE',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TakaSymbol(size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  p.revenue.toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
