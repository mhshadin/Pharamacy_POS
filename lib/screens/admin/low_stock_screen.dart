import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/inventory_alert_tiers.dart';
import '../../utils/phone_launcher.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../../services/export_service.dart';
import 'restock_screen.dart';
import '../../utils/med_type_icons.dart';
import '../../providers/language_provider.dart';
import '../../utils/med_type_units.dart';
import '../../widgets/shared/empty_state_widget.dart';
import '../../widgets/shared/right_filter_panel.dart';
import '../../l10n/app_strings.dart';

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({
    super.key,
    this.showAppBar = true,
    this.externalSearchVisible,
    this.onSearchVisibilityChanged,
  });

  final bool showAppBar;
  final bool? externalSearchVisible;
  final ValueChanged<bool>? onSearchVisibilityChanged;

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearchVisible = false;
  String _searchQuery = '';
  String _filter = 'All'; // Using keys for logic
  String _sortBy = 'Most Urgent';
  final Set<String> _selectedCompanies = {};

  Widget _statBox({
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 9 : 10,
              color: fg.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 13 : 16,
              color: fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // Note: These are logic values that map to l10n keys in the UI
  static const _sortOptions = [
    'Most Urgent',
    'Biggest Deficit',
    'A \u2192 Z',
    'Z \u2192 A',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.externalSearchVisible != null) {
      _isSearchVisible = widget.externalSearchVisible!;
    }
  }

  @override
  void didUpdateWidget(covariant LowStockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ext = widget.externalSearchVisible;
    if (ext != null && ext != _isSearchVisible) {
      setState(() {
        _isSearchVisible = ext;
        if (!_isSearchVisible) {
          _searchCtrl.clear();
          _searchQuery = '';
          _searchFocus.unfocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchCtrl.clear();
        _searchQuery = '';
        _searchFocus.unfocus();
      }
    });
    if (_isSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
    widget.onSearchVisibilityChanged?.call(_isSearchVisible);
  }

  List<Product> _applyFilters(List<Product> source) {
    var list = List<Product>.from(source);

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.generic.toLowerCase().contains(q) ||
            (p.companyName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Severity chip
    if (_filter == 'Out of Stock') {
      list = list.where((p) => p.stockStrips == 0).toList();
    } else if (_filter == 'Low Stock') {
      list = list.where((p) => p.stockStrips > 0).toList();
    }

    // Multi-company
    if (_selectedCompanies.isNotEmpty) {
      list = list
          .where((p) => _selectedCompanies.contains(p.companyName))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Most Urgent':
        list.sort((a, b) {
          final ratioA = a.minStockLevel > 0
              ? a.stockStrips / a.minStockLevel
              : 0.0;
          final ratioB = b.minStockLevel > 0
              ? b.stockStrips / b.minStockLevel
              : 0.0;
          return ratioA.compareTo(ratioB);
        });
        break;
      case 'Biggest Deficit':
        list.sort((a, b) {
          final defA = a.minStockLevel - a.stockStrips;
          final defB = b.minStockLevel - b.stockStrips;
          return defB.compareTo(defA);
        });
        break;
      case 'A \u2192 Z':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Z \u2192 A':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return list;
  }

  void _showStockStatusFilterPanel(AppStrings l10n) {
    showRightFilterPanel(context, (dialogContext) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  color: AppColors.secondaryAccent,
                  onPressed: () => Navigator.pop(dialogContext),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
                Expanded(
                  child: Text(
                    l10n.filterByStockStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _filter = 'All');
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    l10n.clearAll,
                    style: const TextStyle(color: AppColors.secondaryAccent),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView(
              children: [
                for (final entry in <(String, String)>[
                  ('All', l10n.filterAll),
                  ('Out of Stock', l10n.filterOutOfStock),
                  ('Low Stock', l10n.lowStockBadge),
                ])
                  ListTile(
                    leading: Icon(
                      _filter == entry.$1
                          ? LucideIcons.checkCircle2
                          : LucideIcons.circle,
                      size: 20,
                      color: _filter == entry.$1
                          ? AppColors.primaryDark
                          : AppColors.secondaryAccent,
                    ),
                    title: Text(
                      entry.$2,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      setState(() => _filter = entry.$1);
                      Navigator.pop(dialogContext);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.applyBtn,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showCompanySheet(List<String> allCompanies, AppStrings l10n) {
    showRightFilterPanel(context, (dialogContext) {
      String sheetSearch = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visible = sheetSearch.isEmpty
              ? allCompanies
              : allCompanies
                  .where(
                    (c) =>
                        c.toLowerCase().contains(sheetSearch.toLowerCase()),
                  )
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      color: AppColors.secondaryAccent,
                      onPressed: () => Navigator.pop(dialogContext),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                    ),
                    Expanded(
                      child: Text(
                        l10n.filterByCompany,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {});
                        setState(() => _selectedCompanies.clear());
                      },
                      child: Text(
                        l10n.clearAll,
                        style: const TextStyle(color: AppColors.secondaryAccent),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    onChanged: (v) => setSheetState(() => sheetSearch = v),
                    decoration: InputDecoration(
                      hintText: l10n.searchCompanies,
                      hintStyle: TextStyle(
                        color: AppColors.secondaryAccent.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        color: AppColors.secondaryAccent,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noCompaniesFound,
                          style: const TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView(
                        children: visible.map((company) {
                          final isSelected =
                              _selectedCompanies.contains(company);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(
                              company,
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: AppColors.primaryDark,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  _selectedCompanies.add(company);
                                } else {
                                  _selectedCompanies.remove(company);
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.applyBtn,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildSortActionTile(AppStrings l10n, {required bool expand}) {
    final tile = PopupMenuButton<String>(
      tooltip: l10n.sortBtn,
      icon: SizedBox(
        height: 52,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.posButtonIdle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.arrowUpDown,
                color: AppColors.primaryDark,
                size: 16,
              ),
              SizedBox(height: 2),
              Text(
                'Sort',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
      onSelected: (v) => setState(() => _sortBy = v),
      itemBuilder: (_) => _sortOptions
          .map(
            (o) => PopupMenuItem(
              value: o,
              child: Row(
                children: [
                  Icon(
                    _sortBy == o ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 16,
                    color: _sortBy == o
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    o == 'Most Urgent'
                        ? l10n.sortMostUrgent
                        : o == 'Biggest Deficit'
                            ? l10n.sortBiggestDeficit
                            : o == 'A → Z'
                                ? l10n.sortNameAZ
                                : l10n.sortNameZA,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );

    if (expand) return Expanded(child: tile);
    return SizedBox(width: 74, child: tile);
  }

  Future<void> _doExport(
    List<Product> products,
    Map<String, int> orderQtys, {
    required bool isPdf,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.read<LanguageProvider>().strings;
    String? path;
    try {
      if (isPdf) {
        path = await ExportService.exportOrderListToPdf(
          products: products,
          orderQtys: orderQtys,
          title: 'Low Stock',
          l10n: l10n,
        );
      } else {
        path = await ExportService.exportOrderListToCsv(
          products,
          orderQtys,
          l10n.lowStockTitle,
        );
      }
    } catch (e) {
      path = null;
    }

    if (!mounted) return;

    if (path != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.exportSuccess),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.open,
            onPressed: () => OpenFile.open(path),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.exportFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showOrderQtyModal(List<Product> products) {
    final Map<String, int> orderQtys = {};
    for (var p in products) {
      final deficit = p.minStockLevel - p.stockStrips;
      final boxes = p.stripsPerBox > 0 ? (deficit / p.stripsPerBox).ceil() : deficit;
      orderQtys[p.id] = boxes > 0 ? boxes : 1;
    }

    showDialog(
      context: context,
      builder: (context) {
        final l10n = context.read<LanguageProvider>().strings;
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(l10n.confirmOrderQuantities),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (c, i) {
                final p = products[i];
                final unitLabels = MedTypeUnits.getLabels(p.medType, l10n);
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(l10n.deficitUnits(p.minStockLevel - p.stockStrips, (unitLabels['unit2'] ?? 'strips').toLowerCase())),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: '${orderQtys[p.id]}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(suffixText: (unitLabels['unit1'] ?? unitLabels['unit2'] ?? 'bx').toLowerCase().substring(0, 2)),
                      onChanged: (v) {
                        orderQtys[p.id] = int.tryParse(v) ?? 1;
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelBtn),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _doExport(products, orderQtys, isPdf: false);
              },
              icon: const Icon(LucideIcons.fileSpreadsheet),
              label: Text(l10n.exportCsv),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _doExport(products, orderQtys, isPdf: true);
              },
              icon: const Icon(LucideIcons.fileText),
              label: Text(l10n.exportPdf),
            ),
          ],
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final allLowStock = admin.lowStockProducts;
    final filtered = _applyFilters(allLowStock).where((p) {
      if (_selectedCompanies.isEmpty) return true;
      return p.companyName != null && _selectedCompanies.contains(p.companyName);
    }).toList();
    final showSupplierInfo = admin.showSupplierInfo;

    final allCompanies = allLowStock
        .map((p) => p.companyName)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final hasCompanies = allCompanies.isNotEmpty;

    if (allLowStock.isEmpty) {
      final l10n = context.watch<LanguageProvider>().strings;
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(l10n.lowStockTitle),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(
                      _isSearchVisible ? LucideIcons.x : LucideIcons.search,
                    ),
                    onPressed: _toggleSearch,
                    tooltip: _isSearchVisible
                        ? l10n.closeSearchTooltip
                        : l10n.searchTooltip,
                  ),
                ],
              )
            : null,
        backgroundColor: AppColors.background,
        body: EmptyStateWidget(
          title: l10n.allStockGood,
          message: l10n.noLowStock,
          icon: LucideIcons.checkCircle2,
        ),
      );
    }

    final l10n = context.watch<LanguageProvider>().strings;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.lowStockTitle),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    _isSearchVisible ? LucideIcons.x : LucideIcons.search,
                  ),
                  onPressed: _toggleSearch,
                  tooltip: _isSearchVisible
                      ? l10n.closeSearchTooltip
                      : l10n.searchTooltip,
                ),
              ],
            )
          : null,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _LowStockExpandableSearchBar(
            isVisible:
                widget.externalSearchVisible ??
                (widget.showAppBar ? _isSearchVisible : false),
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            onClose: _toggleSearch,
          ),
          // ── Filter controls ──────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    if (compact) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSortActionTile(l10n, expand: false),
                            const SizedBox(width: 8),
                            adminActionTileButton(
                              icon: LucideIcons.listFilter,
                              label: 'Filter',
                              tooltip: l10n.filterByStockStatus,
                              activeCount: _filter == 'All' ? 0 : 1,
                              minWidth: 74,
                              onPressed: () =>
                                  _showStockStatusFilterPanel(l10n),
                            ),
                            if (hasCompanies) ...[
                              const SizedBox(width: 8),
                              adminActionTileButton(
                                icon: LucideIcons.building2,
                                label: 'Company',
                                tooltip: l10n.filterByCompany,
                                activeCount: _selectedCompanies.length,
                                minWidth: 74,
                                onPressed: () =>
                                    _showCompanySheet(allCompanies, l10n),
                              ),
                            ],
                            if (filtered.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              adminActionTileButton(
                                icon: LucideIcons.download,
                                label: 'Export',
                                tooltip: l10n.exportOrderList,
                                activeCount: 0,
                                minWidth: 74,
                                onPressed: () => _showOrderQtyModal(filtered),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return Row(
                      children: [
                        _buildSortActionTile(l10n, expand: true),
                        const SizedBox(width: 8),
                        adminActionTileButton(
                          icon: LucideIcons.listFilter,
                          label: 'Filter',
                          tooltip: l10n.filterByStockStatus,
                          activeCount: _filter == 'All' ? 0 : 1,
                          expand: true,
                          onPressed: () => _showStockStatusFilterPanel(l10n),
                        ),
                        if (hasCompanies) ...[
                          const SizedBox(width: 8),
                          adminActionTileButton(
                            icon: LucideIcons.building2,
                            label: 'Company',
                            tooltip: l10n.filterByCompany,
                            activeCount: _selectedCompanies.length,
                            expand: true,
                            onPressed: () =>
                                _showCompanySheet(allCompanies, l10n),
                          ),
                        ],
                        if (filtered.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          adminActionTileButton(
                            icon: LucideIcons.download,
                            label: 'Export',
                            tooltip: l10n.exportOrderList,
                            activeCount: 0,
                            expand: true,
                            onPressed: () => _showOrderQtyModal(filtered),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l10n.productsCount(filtered.length),
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // List results
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateWidget(
                    title: l10n.noResultsFound,
                    message: l10n.noProductsMatchCriteria,
                    icon: LucideIcons.searchX,
                    onAction: () {
                      setState(() {
                        _searchCtrl.clear();
                        _searchQuery = '';
                        _isSearchVisible = false;
                        _selectedCompanies.clear();
                        _filter = 'All';
                        _sortBy = 'Most Urgent';
                      });
                    },
                    actionLabel: l10n.clearAllFilters,
                  )
                : ListView.separated(
                    padding: ResponsiveHelper.screenPadding(context),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final l10n = context.read<LanguageProvider>().strings;
                      final product = filtered[index];
                      final unitLabels = MedTypeUnits.getLabels(product.medType, l10n);
                      final tier = admin.lowStockTierFor(product);
                      final accent = tier.accentColor;
                      final percentage = (product.stockStrips / product.minStockLevel).clamp(0.0, 1.0);
                      final minBoxes = product.stripsPerBox > 0
                          ? (product.minStockLevel / product.stripsPerBox).ceil()
                          : product.minStockLevel;
                      final supplierPhone = showSupplierInfo ? product.supplierPhone?.trim() : null;
                      final hasSupplierPhone = supplierPhone != null && supplierPhone.isNotEmpty;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          final iconBox = Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(LucideIcons.alertTriangle, color: accent, size: 20),
                          );

                          final nameColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 14 : 16,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                product.companyName != null && product.companyName!.isNotEmpty
                                    ? '${product.generic} • ${product.companyName}'
                                    : product.generic,
                                style: const TextStyle(
                                  color: AppColors.secondaryAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );

                          final medTypeBadge = product.medType != null
                              ? Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        MedTypeIcons.getIcon(product.medType),
                                        size: 10,
                                        color: MedTypeIcons.getColor(product.medType),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        product.medType!,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: MedTypeIcons.getColor(product.medType),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink();

                          final phoneBtn = hasSupplierPhone
                              ? IconButton(
                                  tooltip: l10n.callSupplier,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  onPressed: () => tryDialPhone(context, supplierPhone),
                                  icon: const Icon(LucideIcons.phoneCall, color: AppColors.primaryDark, size: 20),
                                )
                              : null;

                          final statRow = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statBox(
                                label: l10n.inStock.toUpperCase(),
                                value: '${product.stockBoxes} ${(unitLabels['unit1'] ?? 'bx').toLowerCase()}',
                                bg: accent.withValues(alpha: 0.08),
                                fg: accent,
                                compact: isNarrow,
                              ),
                              const SizedBox(width: 8),
                              _statBox(
                                label: l10n.minStock.toUpperCase(),
                                value: '$minBoxes ${(unitLabels['unit1'] ?? 'bx').toLowerCase()}',
                                bg: AppColors.primaryDark.withValues(alpha: 0.06),
                                fg: AppColors.primaryDark,
                                compact: isNarrow,
                              ),
                            ],
                          );

                          final extraInfo = Text(
                            '${l10n.remainingUnits(product.remainingStrips, (unitLabels['unit2'] ?? 'strips').toLowerCase())} • ${l10n.extraUnits(product.stockPcs, (unitLabels['unit3'] ?? 'pcs').toLowerCase())}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: AppColors.secondaryAccent,
                            ),
                          );

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RestockScreen(product: product),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      iconBox,
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            nameColumn,
                                            medTypeBadge,
                                          ],
                                        ),
                                      ),
                                      phoneBtn ?? const SizedBox.shrink(),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          statRow,
                                          const SizedBox(height: 8),
                                          extraInfo,
                                        ],
                                      ),
                                      SizedBox(
                                        width: isNarrow ? 80 : 120,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: percentage,
                                                backgroundColor: accent.withValues(alpha: 0.1),
                                                valueColor: AlwaysStoppedAnimation(accent),
                                                minHeight: 6,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.stockLevelPercent((percentage * 100).toInt()),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: accent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LowStockExpandableSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _LowStockExpandableSearchBar({
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: isVisible ? 60.0 : 0.0,
      color: AppColors.primaryDark,
      child: isVisible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.highlightActive.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: TextStyle(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      color: AppColors.secondaryAccent,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 16,
                        color: AppColors.secondaryAccent,
                      ),
                      onPressed: onClose,
                      tooltip: l10n.closeSearchTooltip,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
