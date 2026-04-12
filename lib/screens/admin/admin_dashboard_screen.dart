import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_strings.dart';
import '../../utils/colors.dart';
import '../../utils/inventory_alert_tiers.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import 'product_list_screen.dart';
import 'add_product_screen.dart';
import 'sales_report_screen.dart';
import 'expiring_soon_screen.dart';
import 'low_stock_screen.dart';
import 'returns_screen.dart';
import '../../services/auth_storage.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'top_products_screen.dart';
import 'profit_report_screen.dart';
import '../../widgets/taka_symbol.dart';

/// Same threshold as [PosCartList] / manual add for horizontal swipes.
const double _kAdminSwipeOpenDrawerMinVelocity = 450.0;

class AdminDashboardScreen extends StatefulWidget {
  /// Embedded Returns tab index (must match [_navItemsData] order).
  static const int returnsNavIndex = 5;

  const AdminDashboardScreen({
    super.key,
    /// Section index when opening admin (e.g. [returnsNavIndex] for Returns). Default `0` is dashboard-only.
    this.initialNavIndex = 0,
  });

  /// Must match [_NavItemData] indices in [_AdminDashboardScreenState].
  final int initialNavIndex;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Navigation stack: [0] is always dashboard at the bottom
  late List<int> _navStack;
  bool _salesReportInitialToday = false;
  bool _embeddedSearchVisible = false;

  @override
  void initState() {
    super.initState();
    final start = widget.initialNavIndex;
    if (start >= 1 && start <= 10) {
      _navStack = [0, start];
    } else {
      _navStack = [0];
    }
  }

  int get _currentIndex => _navStack.last;
  bool get _isEmbeddedSearchPage =>
      _currentIndex == 1 ||
      _currentIndex == 3 ||
      _currentIndex == 4 ||
      _currentIndex == 5;

  final List<_NavItemData> _navItemsData = [
    _NavItemData(icon: LucideIcons.layoutDashboard, labelKey: (l10n) => l10n.navDashboard),   // 0
    _NavItemData(icon: LucideIcons.package, labelKey: (l10n) => l10n.navProductList),          // 1
    _NavItemData(icon: LucideIcons.packagePlus, labelKey: (l10n) => l10n.navAddProduct),       // 2
    _NavItemData(icon: LucideIcons.alertTriangle, labelKey: (l10n) => l10n.navLowStock),       // 3
    _NavItemData(icon: LucideIcons.clock, labelKey: (l10n) => l10n.navExpiringSoon),           // 4
    _NavItemData(icon: LucideIcons.rotateCcw, labelKey: (l10n) => l10n.navReturns),           // 5
    _NavItemData(icon: LucideIcons.barChart3, labelKey: (l10n) => l10n.navSalesReport),        // 6
    _NavItemData(icon: LucideIcons.lineChart, labelKey: (l10n) => l10n.navProfitReport),       // 7
    _NavItemData(icon: LucideIcons.trendingUp, labelKey: (l10n) => l10n.navTopProducts),       // 8
    _NavItemData(icon: LucideIcons.settings, labelKey: (l10n) => l10n.navSettings),            // 9
    _NavItemData(icon: LucideIcons.user, labelKey: (l10n) => l10n.navProfile),                 // 10
  ];

  void _navigateTo(
    int index, {
    bool isMenuNavigation = false,
    bool closeDrawer = false,
    bool openSalesReportWithTodayFilter = false,
  }) {
    if (closeDrawer) Navigator.pop(context);
    if (!isMenuNavigation && index == _currentIndex) return;

    setState(() {
      if (index != 3 && index != 4 && index != 5) {
        _embeddedSearchVisible = false;
      }
      if (index == 6) {
        _salesReportInitialToday = openSalesReportWithTodayFilter;
      }
      if (index == 0 || isMenuNavigation) {
        // Going to dashboard or navigating via menu clears the internal history
        _navStack.clear();
        _navStack.add(0);
        if (index != 0) {
          _navStack.add(index);
        }
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
        return ProductListScreen(
          isAdmin: true,
          onOpenAddProduct: () => _navigateTo(2),
          externalSearchVisible: _embeddedSearchVisible,
          onSearchVisibilityChanged: (visible) {
            if (_embeddedSearchVisible != visible) {
              setState(() => _embeddedSearchVisible = visible);
            }
          },
        );
      case 2:
        return const AddProductScreen();
      case 3:
        return LowStockScreen(
          showAppBar: false,
          externalSearchVisible: _embeddedSearchVisible,
          onSearchVisibilityChanged: (visible) {
            if (_embeddedSearchVisible != visible) {
              setState(() => _embeddedSearchVisible = visible);
            }
          },
        );
      case 4:
        return ExpiringSoonScreen(
          showAppBar: false,
          externalSearchVisible: _embeddedSearchVisible,
          onSearchVisibilityChanged: (visible) {
            if (_embeddedSearchVisible != visible) {
              setState(() => _embeddedSearchVisible = visible);
            }
          },
        );
      case 5:
        return ReturnsScreen(
          externalSearchVisible: _embeddedSearchVisible,
          onSearchVisibilityChanged: (visible) {
            if (_embeddedSearchVisible != visible) {
              setState(() => _embeddedSearchVisible = visible);
            }
          },
        );
      case 6:
        return SalesReportScreen(
          onNavigateToProfit: () => _navigateTo(7),
          initialTransactionFilterToday: _salesReportInitialToday,
        );
      case 7:
        return const ProfitReportScreen(showAppBar: false);
      case 8:
        return const TopProductsScreen();
      case 9:
        return const SettingsScreen();
      case 10:
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
    final l10n = Provider.of<LanguageProvider>(context).strings;
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
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        // Keep swipe-open for mobile drawer; wide layout uses fixed sidebar.
        drawerEnableOpenDragGesture: !isWide,
        drawerEdgeDragWidth: isWide ? null : 40,
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
            _navItemsData[_currentIndex].labelKey(l10n),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          actions: [
            if (_isEmbeddedSearchPage)
              IconButton(
                icon: Icon(
                  _embeddedSearchVisible ? LucideIcons.x : LucideIcons.search,
                ),
                tooltip: _embeddedSearchVisible
                    ? l10n.closeSearchTooltip
                    : l10n.searchTooltip,
                onPressed: () {
                  setState(() {
                    _embeddedSearchVisible = !_embeddedSearchVisible;
                  });
                },
              ),
            IconButton(
              icon: const Icon(LucideIcons.logOut),
              tooltip: l10n.logout,
              onPressed: _exitAdmin,
            ),
          ],
        ),
        drawer: isWide ? null : _buildDrawer(l10n),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) _buildSidebar(l10n),
            Expanded(
              child: isWide
                  ? _getPage(_currentIndex)
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v >= _kAdminSwipeOpenDrawerMinVelocity) {
                          _scaffoldKey.currentState?.openDrawer();
                        }
                      },
                      child: _getPage(_currentIndex),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(AppStrings l10n) {
    return Container(
      width: 240,
      color: AppColors.primaryDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.cross,
                  color: AppColors.highlightActive,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.posTitle,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        l10n.adminPortal,
                        style: const TextStyle(
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
              itemCount: _navItemsData.length,
              itemBuilder: (_, idx) =>
                  _buildNavTile(idx, l10n, onTap: () => _navigateTo(idx, isMenuNavigation: true)),
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
              title: Text(
                l10n.backToPos,
                style: const TextStyle(
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

  Widget _buildDrawer(AppStrings l10n) {
    return Drawer(
      backgroundColor: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: ResponsiveHelper.screenPadding(context),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.cross,
                    color: AppColors.highlightActive,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.posTitle,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        l10n.adminPortal,
                        style: const TextStyle(
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
                itemCount: _navItemsData.length,
                itemBuilder: (_, idx) => _buildNavTile(
                  idx,
                  l10n,
                  onTap: () => _navigateTo(idx, isMenuNavigation: true, closeDrawer: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(int index, AppStrings l10n, {required VoidCallback onTap}) {
    final isSelected = _currentIndex == index;
    final item = _navItemsData[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? AppColors.white : AppColors.secondaryAccent,
          size: 22,
        ),
        title: Text(
          item.labelKey(l10n),
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
    final l10n = Provider.of<LanguageProvider>(context).strings;
    final admin = context.watch<AdminProvider>();
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isTablet = screenWidth > 600;
    final widthScale = (screenWidth / 390).clamp(0.82, 1.12).toDouble();
    final overviewHeadingFontSize = (20 * widthScale).clamp(17.0, 22.0);
    final sectionHeadingFontSize = (16 * widthScale).clamp(14.0, 18.0);
    final cardLabelFontSize = (11 * widthScale).clamp(10.0, 12.5);
    final cardValueFontSize = (22 * widthScale).clamp(18.0, 24.0);
    final cardPadding = (14 * widthScale).clamp(10.0, 16.0);
    final cardIconSize = (16 * widthScale).clamp(14.0, 18.0);
    final cardIconPadding = (6 * widthScale).clamp(4.0, 7.0);
    final cardSpacing = (12 * widthScale).clamp(8.0, 14.0);
    final overviewCardRunSpacing = cardSpacing;
    final overviewTopGap = (16 * widthScale).clamp(12.0, 20.0);
    final sectionGap = (20 * widthScale).clamp(14.0, 24.0);
    final infoTitleFontSize = (15 * widthScale).clamp(13.0, 17.0);
    final infoBodyFontSize = (12 * widthScale).clamp(11.0, 14.0);
    const overviewRows = 3.0; // 6 cards, 2 columns on phone
    final phoneOverviewHeightBudget = screenHeight * 0.4;
    final phoneMinCardHeight = (104 * widthScale).clamp(100.0, 116.0);
    final phoneMaxCardHeight = (144 * widthScale).clamp(128.0, 160.0);
    final phoneCardHeight =
        ((phoneOverviewHeightBudget - (overviewCardRunSpacing * (overviewRows - 1))) /
                overviewRows)
            .clamp(phoneMinCardHeight, phoneMaxCardHeight);
    final overviewCardHeight =
        isTablet ? (110 * widthScale).clamp(98.0, 124.0) : phoneCardHeight;

    return SingleChildScrollView(
      padding: ResponsiveHelper.screenPadding(context),
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
                    l10n.overview,
                    style: TextStyle(
                      fontSize: overviewHeadingFontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  // Last-updated date/time chip (hidden per product request)
                  // Container(
                  //   padding: const EdgeInsets.symmetric(
                  //     horizontal: 12,
                  //     vertical: 6,
                  //   ),
                  //   decoration: BoxDecoration(
                  //     color: AppColors.primaryDark.withValues(alpha: 0.1),
                  //     borderRadius: BorderRadius.circular(20),
                  //   ),
                  //   child: Row(
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       const Icon(
                  //         LucideIcons.calendar,
                  //         size: 14,
                  //         color: AppColors.primaryDark,
                  //       ),
                  //       const SizedBox(width: 8),
                  //       Text(
                  //         l10n.lastUpdated(
                  //           DateFormat('MMM dd, yyyy • hh:mm a',
                  //                   Provider.of<LanguageProvider>(context, listen: false).currentLocale)
                  //               .format(DateTime.now()),
                  //         ),
                  //         style: const TextStyle(
                  //           fontSize: 13,
                  //           fontWeight: FontWeight.bold,
                  //           color: AppColors.primaryDark,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
              SizedBox(height: overviewTopGap),
              // STAT CARDS — use Wrap for phone to avoid overflow
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = isTablet
                      ? (constraints.maxWidth - (cardSpacing * 3)) / 4
                      : (constraints.maxWidth - cardSpacing) / 2;

                  return Wrap(
                    spacing: cardSpacing,
                    runSpacing: overviewCardRunSpacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _StatCard(
                          title: l10n.todaySales,
                          value: admin.todaysSales.toStringAsFixed(2),
                          isTaka: true,
                          icon: LucideIcons.dollarSign,
                          iconColor: AppColors.success,
                          iconBg: AppColors.success.withValues(alpha: 0.1),
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(
                            6,
                            openSalesReportWithTodayFilter: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _StatCard(
                          title: l10n.totalOrders,
                          value: '${admin.todaysOrders}',
                          icon: LucideIcons.receipt,
                          iconColor: AppColors.secondaryAccent,
                          iconBg: AppColors.secondaryAccent.withValues(
                            alpha: 0.1,
                          ),
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(
                            6,
                            openSalesReportWithTodayFilter: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _StatCard(
                          title: l10n.lowStock,
                          value: '${admin.lowStockProducts.length}',
                          icon: LucideIcons.alertTriangle,
                          iconColor: AppColors.error,
                          iconBg: AppColors.error.withValues(alpha: 0.1),
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(3),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _StatCard(
                          title: l10n.expiringSoon,
                          value: '${admin.expiringSoonProducts.length}',
                          icon: LucideIcons.clock,
                          iconColor: AppColors.warningOrange,
                          iconBg: AppColors.warningOrange.withValues(
                            alpha: 0.1,
                          ),
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(4),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _StatCard(
                          title: l10n.profitReport,
                          value: admin.totalProfitToday.toStringAsFixed(2),
                          isTaka: true,
                          icon: LucideIcons.lineChart,
                          iconColor: AppColors.primaryDark,
                          iconBg: AppColors.primaryDark.withValues(
                            alpha: 0.1,
                          ),
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(7),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        height: overviewCardHeight,
                        child: _SubscriptionRenewalCard(
                          l10n: l10n,
                          session: admin.authSession,
                          cardPadding: cardPadding,
                          iconSize: cardIconSize,
                          iconPadding: cardIconPadding,
                          labelFontSize: cardLabelFontSize,
                          valueFontSize: cardValueFontSize,
                          onTap: () => _navigateTo(10),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: sectionGap),

              // CRITICAL INVENTORY (shown first)
              _SectionCard(
                title: l10n.criticalInventory,
                titleFontSize: sectionHeadingFontSize,
                child:
                    (admin.lowStockProducts.isEmpty &&
                        admin.expiringSoonProducts.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.checkCircle2,
                                  size: 32,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.allStockGood,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: infoTitleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.noLowStockExpiring,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.secondaryAccent,
                                  fontSize: infoBodyFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          ...admin.lowStockProducts.map((product) {
                            final accent =
                                admin.lowStockTierFor(product).accentColor;
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  LucideIcons.alertTriangle,
                                  color: accent,
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
                                l10n.productStockDetails(
                                  product.stockBoxes,
                                  product.remainingStrips,
                                  product.totalPieces,
                                  product.minStockLevel,
                                ),
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: infoBodyFontSize,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  l10n.lowStockBadge,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (11 * widthScale).clamp(10.0, 13.0),
                                  ),
                                ),
                              ),
                            );
                          }),
                          ...admin.expiringSoonProducts.map((product) {
                            final tier = admin.expiryTierFor(product);
                            final accent = tier.accentColor;
                            final iconData = switch (tier) {
                              InventoryAlertTier.critical =>
                                LucideIcons.alertOctagon,
                              InventoryAlertTier.moderate => LucideIcons.clock,
                              InventoryAlertTier.mild =>
                                LucideIcons.calendarDays,
                            };
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  iconData,
                                  color: accent,
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
                                    ? l10n.expiresDate(product.expiryDate!.toLocal())
                                    : l10n.unknownExpiry,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: infoBodyFontSize,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  l10n.expiringSoonBadge,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (11 * widthScale).clamp(10.0, 13.0),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              SizedBox(height: sectionGap),

              // RECENT SALES
              _SectionCard(
                title: l10n.recentTransactions,
                titleFontSize: sectionHeadingFontSize,
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
                                  sale.invoiceNumber ??
                                      (sale.id.length > 10
                                          ? '${sale.id.substring(0, 10)}...'
                                          : sale.id),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  l10n.productQuantity(sale.productName, sale.effectiveQuantity),
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
class _NavItemData {
  final IconData icon;
  final String Function(AppStrings) labelKey;
  _NavItemData({required this.icon, required this.labelKey});
}

class _SubscriptionRenewalCard extends StatelessWidget {
  final AppStrings l10n;
  final AuthSession? session;
  final VoidCallback onTap;
  final double cardPadding;
  final double iconSize;
  final double iconPadding;
  final double labelFontSize;
  final double valueFontSize;

  const _SubscriptionRenewalCard({
    required this.l10n,
    required this.session,
    required this.onTap,
    required this.cardPadding,
    required this.iconSize,
    required this.iconPadding,
    required this.labelFontSize,
    required this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final raw = session?.subscriptionValidUntil.trim() ?? '';
    final totalPlanDays = session?.subscriptionTotalPlanDays ?? 0;
    late final Color accent;
    late final String headline;
    double remainingFraction = 0;
    bool showTimeline = false;

    if (raw.isEmpty) {
      accent = AppColors.secondaryAccent;
      headline = l10n.subscriptionRenewalUnavailable;
    } else {
      try {
        final validUntil = DateTime.parse(raw);
        final daysRemaining = validUntil.difference(DateTime.now()).inDays;
        final tier = subscriptionRenewalTier(daysRemaining);
        accent = tier.accentColor;
        headline = l10n.subscriptionRenewalDaysLeft(daysRemaining);
        if (totalPlanDays > 0) {
          final clampedRemaining = daysRemaining.clamp(0, totalPlanDays);
          remainingFraction = clampedRemaining / totalPlanDays;
          showTimeline = true;
        }
      } catch (_) {
        accent = AppColors.secondaryAccent;
        headline = l10n.subscriptionRenewalUnavailable;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(cardPadding),
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
                    l10n.subscriptionTitle,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryAccent,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.calendarClock,
                    size: iconSize,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showTimeline) ...[
              const SizedBox(height: 8),
              _SubscriptionTimelineBar(remainingFraction: remainingFraction),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionTimelineBar extends StatelessWidget {
  final double remainingFraction;

  const _SubscriptionTimelineBar({required this.remainingFraction});

  @override
  Widget build(BuildContext context) {
    final elapsedFraction = (1 - remainingFraction).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            const Row(
              children: [
                Expanded(child: ColoredBox(color: AppColors.success)),
                Expanded(child: ColoredBox(color: AppColors.warningOrange)),
                Expanded(child: ColoredBox(color: AppColors.error)),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: elapsedFraction,
                child: Container(color: AppColors.white.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;
  final bool isTaka;
  final double cardPadding;
  final double iconSize;
  final double iconPadding;
  final double labelFontSize;
  final double valueFontSize;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
    this.isTaka = false,
    required this.cardPadding,
    required this.iconSize,
    required this.iconPadding,
    required this.labelFontSize,
    required this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(cardPadding),
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
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryAccent,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: iconSize, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isTaka)
                  TakaSymbol(
                    size: valueFontSize,
                    color: AppColors.primaryDark,
                  ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double titleFontSize;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.titleFontSize,
  });

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
              style: TextStyle(
                fontSize: titleFontSize,
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
