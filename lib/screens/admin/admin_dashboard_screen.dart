import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';
import 'product_list_screen.dart';
import 'stock_in_screen.dart';
import 'sales_report_screen.dart';
import 'expiring_soon_screen.dart';
import 'low_stock_screen.dart';
import 'package:intl/intl.dart';
import 'returns_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'top_products_screen.dart';
import '../../widgets/taka_symbol.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Navigation stack: [0] is always dashboard at the bottom
  final List<int> _navStack = [0];

  int get _currentIndex => _navStack.last;

  final List<_NavItem> _navItems = [
    _NavItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
    _NavItem(icon: LucideIcons.packagePlus, label: 'Stock In'),
    _NavItem(icon: LucideIcons.rotateCcw, label: 'Returns'),
    _NavItem(icon: LucideIcons.barChart3, label: 'Sales Report'),
    _NavItem(icon: LucideIcons.clock, label: 'Expiring Soon'),
    _NavItem(icon: LucideIcons.alertTriangle, label: 'Low Stock'),
    _NavItem(icon: LucideIcons.package, label: 'Product List'),
    _NavItem(icon: LucideIcons.trendingUp, label: 'Top Products'),
    _NavItem(icon: LucideIcons.settings, label: 'Settings'),
    _NavItem(icon: LucideIcons.user, label: 'Profile'),
  ];

  void _navigateTo(int index, {bool fromDrawer = false}) {
    if (fromDrawer) Navigator.pop(context); // close drawer
    if (index == _currentIndex) return;
    setState(() {
      if (index == 0) {
        // Going to dashboard clears the stack
        _navStack.clear();
        _navStack.add(0);
      } else {
        // Remove any existing occurrence so we don't duplicate
        _navStack.remove(index);
        _navStack.add(index);
      }
    });
  }

  /// Returns true if we handled the back press internally
  bool _handleBack() {
    if (_navStack.length > 1) {
      setState(() => _navStack.removeLast());
      return true; // consumed
    }
    return false; // let the system handle it (exit admin)
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildDashboardPage();
      case 1:
        return const StockInScreen();
      case 2:
        return const ReturnsScreen();
      case 3:
        return const SalesReportScreen();
      case 4:
        return const ExpiringSoonScreen();
      case 5:
        return const LowStockScreen();
      case 6:
        return const ProductListScreen(isAdmin: true);
      case 7:
        return const TopProductsScreen();
      case 8:
        return const SettingsScreen();
      case 9:
        return const ProfileScreen();
      default:
        return _buildDashboardPage();
    }
  }

  void _exitAdmin() {
    context.read<AdminProvider>().logout();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_handleBack()) {
          // On dashboard — exit admin panel
          _exitAdmin();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          automaticallyImplyLeading: false,
          leading: isWide
              ? null
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(LucideIcons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
          title: Text(
            _navItems[_currentIndex].label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.logOut),
              tooltip: 'Logout',
              onPressed: _exitAdmin,
            ),
          ],
        ),
        drawer: isWide ? null : _buildDrawer(),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) _buildSidebar(),
            Expanded(child: _getPage(_currentIndex)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: AppColors.primaryDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.cross,
                  color: AppColors.highlightActive,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHARMAPOS',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'ADMIN PORTAL',
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.secondaryAccent, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (_, idx) =>
                  _buildNavTile(idx, onTap: () => _navigateTo(idx)),
            ),
          ),
          const Divider(color: AppColors.secondaryAccent, height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: const Icon(
                LucideIcons.arrowLeft,
                color: AppColors.highlightActive,
              ),
              title: const Text(
                'Back to POS',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: _exitAdmin,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.cross,
                    color: AppColors.highlightActive,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHARMAPOS',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'ADMIN PORTAL',
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.secondaryAccent, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _navItems.length,
                itemBuilder: (_, idx) => _buildNavTile(
                  idx,
                  onTap: () => _navigateTo(idx, fromDrawer: true),
                ),
              ),
            ),
            const Divider(color: AppColors.secondaryAccent, height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: const Icon(LucideIcons.logOut, color: AppColors.error),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(context); // close drawer
                  _exitAdmin();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(int index, {required VoidCallback onTap}) {
    final isSelected = _currentIndex == index;
    final item = _navItems[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? AppColors.white : AppColors.secondaryAccent,
          size: 22,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.secondaryAccent,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.secondaryAccent.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  // ===== DASHBOARD PAGE =====
  Widget _buildDashboardPage() {
    final admin = context.watch<AdminProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Determine padding based on screen width
    final padding = isTablet
        ? const EdgeInsets.all(32)
        : const EdgeInsets.all(16);

    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overview',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // STAT CARDS — use Wrap for phone to avoid overflow
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = isTablet
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: "Today's Sales",
                          value: admin.todaysSales.toStringAsFixed(2),
                          isTaka: true,
                          icon: LucideIcons.dollarSign,
                          iconColor: AppColors.success,
                          iconBg: AppColors.success.withValues(alpha: 0.1),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Total Orders',
                          value: '${admin.todaysOrders}',
                          icon: LucideIcons.receipt,
                          iconColor: AppColors.secondaryAccent,
                          iconBg: AppColors.secondaryAccent.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Low Stock',
                          value: '${admin.lowStockProducts.length}',
                          icon: LucideIcons.alertTriangle,
                          iconColor: AppColors.error,
                          iconBg: AppColors.error.withValues(alpha: 0.1),
                          onTap: () => _navigateTo(4),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Expiring Soon',
                          value: '${admin.expiringSoonProducts.length}',
                          icon: LucideIcons.clock,
                          iconColor: AppColors.warningOrange,
                          iconBg: AppColors.warningOrange.withValues(
                            alpha: 0.1,
                          ),
                          onTap: () => _navigateTo(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // CRITICAL INVENTORY (shown first)
              _SectionCard(
                title: 'Critical Inventory',
                child:
                    (admin.lowStockProducts.isEmpty &&
                        admin.expiringSoonProducts.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'All stock is good! 🎉\nNo low stock or expiring items.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          ...admin.lowStockProducts.map((product) {
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  LucideIcons.alertTriangle,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              subtitle: Text(
                                '${product.stockBoxes} boxes • ${product.remainingStrips} strips • ${product.totalPieces} pcs remaining (min: ${product.minStockLevel})',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.error.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Low Stock',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            );
                          }),
                          ...admin.expiringSoonProducts.map((product) {
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.warningOrange.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  LucideIcons.clock,
                                  color: AppColors.warningOrange,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              subtitle: Text(
                                product.expiryDate != null
                                    ? 'Expires: ${product.expiryDate!.toLocal().toString().split(' ')[0]}'
                                    : 'Unknown Expiry',
                                style: const TextStyle(
                                  color: AppColors.warningOrange,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warningOrange.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.warningOrange.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Expiring Soon',
                                  style: TextStyle(
                                    color: AppColors.warningOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              const SizedBox(height: 20),

              // RECENT SALES
              _SectionCard(
                title: 'Recent Transactions',
                child: Column(
                  children: admin.allSales.take(5).map((sale) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryAccent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.receipt,
                              size: 18,
                              color: AppColors.secondaryAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sale.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${sale.productName} × ${sale.effectiveQuantity}',
                                  style: const TextStyle(
                                    color: AppColors.secondaryAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const TakaSymbol(
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sale.effectiveAmount.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== HELPER CLASSES =====
class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;
  final bool isTaka;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
    this.isTaka = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
