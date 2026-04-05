import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/inventory_alert_tiers.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/product.dart';
import '../../widgets/drawer/pos_drawer.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'restock_screen.dart';
import '../../widgets/taka_symbol.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/shared/empty_state_widget.dart';
import '../../utils/med_type_icons.dart';

class ProductListScreen extends StatefulWidget {
  final bool isAdmin;
  const ProductListScreen({super.key, required this.isAdmin});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _sortBy = 'Urgency (Recommended)';
  final Set<String> _selectedCompanies = {};
  final Set<String> _selectedGenericNames = {};
  final Set<String> _selectedMedTypes = {};
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleProductListSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchFocus.unfocus();
      }
    });
    if (_isSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  Widget _buildFilterChipList(AppStrings l10n) {
    if (_selectedCompanies.isEmpty && _selectedGenericNames.isEmpty && _selectedMedTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._selectedCompanies.map((c) => _buildChip(c, () => setState(() => _selectedCompanies.remove(c)))),
            ..._selectedGenericNames.map((g) => _buildChip(g, () => setState(() => _selectedGenericNames.remove(g)))),
            ..._selectedMedTypes.map((t) => _buildChip(t, () => setState(() => _selectedMedTypes.remove(t)))),
            TextButton(
              onPressed: () => setState(() {
                _selectedCompanies.clear();
                _selectedGenericNames.clear();
                _selectedMedTypes.clear();
              }),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.clearAllFilters, 
                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryDark.withValues(alpha: 0.08),
        side: BorderSide(color: AppColors.primaryDark.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        deleteIcon: const Icon(LucideIcons.x, size: 14, color: AppColors.primaryDark),
        onDeleted: onRemove,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  static const _sortOptions = [
    'Urgency (Recommended)',
    'Expiry: Soonest First',
    'Name: A → Z',
    'Price: High → Low',
    'Price: Low → High',
  ];

  List<Product> _applyFiltersAndSort({
    required List<Product> source,
    required AdminProvider admin,
  }) {
    var list = List<Product>.from(source);

    // Search
    final searchText = _searchController.text;
    if (searchText.isNotEmpty) {
      final q = searchText.toLowerCase();
      list = list.where((p) {
        final name = p.name.toLowerCase();
        final generic = p.generic.toLowerCase();
        final company = p.companyName?.toLowerCase() ?? '';
        return name.contains(q) || generic.contains(q) || company.contains(q);
      }).toList();
    }

    // Company filter
    if (_selectedCompanies.isNotEmpty) {
      list =
          list.where((p) => _selectedCompanies.contains(p.companyName)).toList();
    }

    // Generic filter
    if (_selectedGenericNames.isNotEmpty) {
      list = list
          .where((p) => _selectedGenericNames.contains(p.generic))
          .toList();
    }

    // MedType filter
    if (_selectedMedTypes.isNotEmpty) {
      list = list.where((p) => _selectedMedTypes.contains(p.medType)).toList();
    }

    int urgencyRank(Product p) {
      final days = p.daysUntilExpiry;
      if (days < 0) return 0;
      if (admin.isProductExpiringCritical(p)) return 1;
      if (admin.isProductExpiringSoon(p)) return 2;
      if (admin.isProductLowStock(p)) return 3;
      return 4;
    }

    int compareText(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    switch (_sortBy) {
      case 'Urgency (Recommended)':
        list.sort((a, b) {
          final rankA = urgencyRank(a);
          final rankB = urgencyRank(b);
          if (rankA != rankB) return rankA.compareTo(rankB);

          if (rankA <= 2) {
            final cmpDays = a.daysUntilExpiry.compareTo(b.daysUntilExpiry);
            if (cmpDays != 0) return cmpDays;
          } else if (rankA == 3) {
            final minA = a.minStockLevel;
            final minB = b.minStockLevel;
            final ratioA = minA > 0 ? a.stockStrips / minA : 0.0;
            final ratioB = minB > 0 ? b.stockStrips / minB : 0.0;
            final cmpRatio = ratioA.compareTo(ratioB);
            if (cmpRatio != 0) return cmpRatio;
            final cmpDef =
                (minB - b.stockStrips).compareTo(minA - a.stockStrips);
            if (cmpDef != 0) return cmpDef;
          }

          return compareText(a.name, b.name);
        });
        break;

      case 'Expiry: Soonest First':
        list.sort((a, b) {
          final cmp = a.daysUntilExpiry.compareTo(b.daysUntilExpiry);
          return cmp != 0 ? cmp : compareText(a.name, b.name);
        });
        break;

      case 'Name: A → Z':
        list.sort((a, b) => compareText(a.name, b.name));
        break;

      case 'Price: High → Low':
        list.sort((a, b) {
          final cmp = b.priceBox.compareTo(a.priceBox);
          return cmp != 0 ? cmp : compareText(a.name, b.name);
        });
        break;

      case 'Price: Low → High':
        list.sort((a, b) {
          final cmp = a.priceBox.compareTo(b.priceBox);
          return cmp != 0 ? cmp : compareText(a.name, b.name);
        });
        break;
    }

    return list;
  }

  void _showRightFilterPanel(Widget Function(BuildContext dialogContext) body) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(dialogContext);
        final panelWidth = min(size.width * 0.88, 420.0);
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: AppColors.background,
            elevation: 12,
            shadowColor: AppColors.primaryDark.withValues(alpha: 0.15),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: panelWidth,
              height: size.height,
              child: SafeArea(
                left: false,
                child: body(dialogContext),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        );
      },
    );
  }

  void _showCompanySheet(List<String> allCompanies, AppStrings l10n) {
    _showRightFilterPanel((dialogContext) {
      String sheetSearch = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visible = sheetSearch.isEmpty
              ? allCompanies
              : allCompanies
                  .where((c) =>
                      c.toLowerCase().contains(sheetSearch.toLowerCase()))
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
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: AppColors.secondaryAccent),
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

  void _showGenericSheet(List<String> allGenerics, AppStrings l10n) {
    _showRightFilterPanel((dialogContext) {
      String sheetSearch = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visible = sheetSearch.isEmpty
              ? allGenerics
              : allGenerics
                  .where((g) =>
                      g.toLowerCase().contains(sheetSearch.toLowerCase()))
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
                        l10n.filterByGeneric,
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
                        setState(() => _selectedGenericNames.clear());
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: AppColors.secondaryAccent),
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
                      hintText: l10n.searchGenerics,
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
                          l10n.noGenericsFound,
                          style: const TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView(
                        children: visible.map((generic) {
                          final isSelected =
                              _selectedGenericNames.contains(generic);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(
                              generic,
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: AppColors.primaryDark,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  _selectedGenericNames.add(generic);
                                } else {
                                  _selectedGenericNames.remove(generic);
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

  void _toggleSelectAll(List<Product> filteredProducts) {
    setState(() {
      if (_selectedIds.length == filteredProducts.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds = filteredProducts.map((p) => p.id).toSet();
      }
    });
  }

  void _deleteSelected(AppStrings l10n) async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.secondaryAccent, width: 2),
        ),
        title: const Text(
          'Delete Products',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} products?',
          style: const TextStyle(color: AppColors.secondaryAccent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AdminProvider>().deleteProducts(_selectedIds.toList());
      if (mounted) {
        await context.read<POSProvider>().loadProducts();
      }
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  Widget _filterButton({
    required IconData icon,
    required String tooltip,
    required int activeCount,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 48,
          width: 48,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? AppColors.primaryDark.withValues(alpha: 0.08)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: activeCount > 0
                      ? AppColors.primaryDark.withValues(alpha: 0.4)
                      : AppColors.divider,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: activeCount > 0
                      ? AppColors.primaryDark
                      : AppColors.secondaryAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (activeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = Provider.of<LanguageProvider>(context).strings;
    final products = context.watch<POSProvider>().products;
    final admin = context.watch<AdminProvider>();
    final filtered = _applyFiltersAndSort(source: products, admin: admin);

    final allCompanies = products
        .map((p) => p.companyName)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final allGenerics = products
        .map((p) => p.generic)
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // If accessed from POS 3-dot menu (not inside admin dashboard),
    // show its own Scaffold with AppBar
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductListExpandableSearchBar(
          isVisible: _isSearchVisible,
          controller: _searchController,
          focusNode: _searchFocus,
          hintText: l10n.searchProducts,
          closeTooltip: l10n.closeSearchTooltip,
          onChanged: (_) => setState(() {}),
          onClose: _toggleProductListSearch,
        ),
        // Filter controls (fixed above list; divider separates from scrolling products)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final filterButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isAdmin)
                    _filterButton(
                      icon: LucideIcons.search,
                      tooltip: _isSearchVisible
                          ? l10n.closeSearchTooltip
                          : l10n.searchTooltip,
                      activeCount: _isSearchVisible ? 1 : 0,
                      onPressed: _toggleProductListSearch,
                    ),
                  if (widget.isAdmin) const SizedBox(width: 8),
                  // Sort button
                  PopupMenuButton<String>(
                    tooltip: l10n.sort,
                    icon: SizedBox(
                      height: 48,
                      width: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.arrowUpDown,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
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
                                  _sortBy == o
                                      ? LucideIcons.checkCircle2
                                      : LucideIcons.circle,
                                  size: 16,
                                  color: _sortBy == o
                                      ? AppColors.primaryDark
                                      : AppColors.secondaryAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(l10n.sortOption(o)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  // Company filter button
                  _filterButton(
                    icon: LucideIcons.building2,
                    tooltip: l10n.filterByCompany,
                    activeCount: _selectedCompanies.length,
                    onPressed: () => _showCompanySheet(allCompanies, l10n),
                  ),
                  const SizedBox(width: 8),
                  // Generic filter button
                  _filterButton(
                    icon: LucideIcons.flaskConical,
                    tooltip: l10n.filterByGeneric,
                    activeCount: _selectedGenericNames.length,
                    onPressed: () => _showGenericSheet(allGenerics, l10n),
                  ),
                  const SizedBox(width: 8),
                  // MedType filter button
                  _filterButton(
                    icon: LucideIcons.layers,
                    tooltip: l10n.filterByType,
                    activeCount: _selectedMedTypes.length,
                    onPressed: () => _showMedTypeSheet(admin.medicineTypes, l10n),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    _filterButton(
                      icon: LucideIcons.plus,
                      tooltip: l10n.addProduct,
                      activeCount: 0,
                      onPressed: () {
                        final pos = context.read<POSProvider>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        ).then((_) async {
                          if (!mounted) return;
                          await pos.loadProducts();
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    if (_isSelectionMode)
                      IconButton(
                        onPressed: _selectedIds.isNotEmpty
                            ? () => _deleteSelected(l10n)
                            : null,
                        icon: Icon(
                          LucideIcons.trash2,
                          color: _selectedIds.isNotEmpty
                              ? AppColors.error
                              : AppColors.secondaryAccent
                                  .withValues(alpha: 0.5),
                        ),
                        tooltip: l10n.deleteSelectedTooltip,
                      ),
                  ],
                ],
              );

              final filterRow = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filterButtons,
              );

              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    filterRow,
                    _buildFilterChipList(l10n),
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filterRow,
                    _buildFilterChipList(l10n),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        if (_isSelectionMode && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Checkbox(
                  value: _selectedIds.length == filtered.length,
                  onChanged: (val) => _toggleSelectAll(filtered),
                  activeColor: AppColors.primaryDark,
                ),
                Text(
                  _selectedIds.length == filtered.length
                      ? l10n.deselectAll
                      : l10n.selectAll,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.selectedCount(_selectedIds.length),
                  style: const TextStyle(
                    color: AppColors.secondaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: filtered.isEmpty
              ? EmptyStateWidget(
                  title: l10n.noProductsFound,
                  message: _searchController.text.isEmpty
                      ? l10n.productListEmpty
                      : l10n.noProductsMatchCriteria,
                  icon: LucideIcons.searchX,
                  onAction: _searchController.text.isNotEmpty
                      ? () {
                          setState(() {
                            _searchController.clear();
                            _isSearchVisible = false;
                            _selectedCompanies.clear();
                            _selectedGenericNames.clear();
                          });
                        }
                      : null,
                  actionLabel: l10n.clearAllFilters,
                )
              : ListView.separated(
                  padding: ResponsiveHelper.screenPadding(context),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final product = filtered[index];
                    final isSelected = _selectedIds.contains(product.id);
                    final lowAccent = admin.isProductLowStock(product)
                        ? admin.lowStockTierFor(product).accentColor
                        : null;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryDark.withValues(alpha: 0.05)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : lowAccent != null
                                  ? lowAccent.withValues(alpha: 0.3)
                                  : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onLongPress: widget.isAdmin && !_isSelectionMode
                              ? () {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedIds.add(product.id);
                                  });
                                }
                              : null,
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(product.id);
                                } else {
                                  _selectedIds.add(product.id);
                                }
                                if (_selectedIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              });
                            } else if (widget.isAdmin) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditProductScreen(product: product),
                                ),
                              ).then((_) {
                                setState(() {});
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedIds.add(product.id);
                                          } else {
                                            _selectedIds.remove(product.id);
                                          }
                                          if (_selectedIds.isEmpty) {
                                            _isSelectionMode = false;
                                          }
                                        });
                                      },
                                      activeColor: AppColors.primaryDark,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    product.medType != null ? MedTypeIcons.getIcon(product.medType) : LucideIcons.pill,
                                    color: product.medType != null ? MedTypeIcons.getColor(product.medType) : AppColors.secondaryAccent,
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
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.companyName != null &&
                                                product.companyName!.isNotEmpty
                                            ? '${product.generic} • ${product.companyName}'
                                            : product.generic,
                                        style: const TextStyle(
                                          color: AppColors.secondaryAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: lowAccent != null ? lowAccent.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: lowAccent != null ? lowAccent.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        lowAccent != null ? l10n.lowStockBadge : l10n.inStock,
                                        style: TextStyle(
                                          color: lowAccent ?? AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    if (product.medType != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              MedTypeIcons.getIcon(product.medType),
                                              size: 12,
                                              color: MedTypeIcons.getColor(product.medType),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              product.medType!,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: MedTypeIcons.getColor(product.medType),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StockBadge(
                                  label: l10n.boxes,
                                  value: '${product.stockBoxes}',
                                  lowStockAccent: lowAccent,
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: l10n.strips,
                                  value: '${product.remainingStrips}',
                                  lowStockAccent: lowAccent,
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: l10n.pcs,
                                  value: '${product.totalPieces}',
                                  lowStockAccent: null,
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: l10n.stripPrice,
                                  value: product.priceStrip.toStringAsFixed(2),
                                  isTaka: true,
                                  lowStockAccent: null,
                                ),
                              ],
                            ),
                            if (widget.isAdmin) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditProductScreen(product: product),
                                          ),
                                        ).then((_) => setState(() {}));
                                      },
                                      icon: const Icon(LucideIcons.edit, size: 16, color: AppColors.primaryDark),
                                      label: Text(
                                        l10n.editBtn,
                                        style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.surfaceLight,
                                        elevation: 0,
                                        side: const BorderSide(color: AppColors.divider),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RestockScreen(product: product),
                                          ),
                                        ).then((_) => setState(() {}));
                                      },
                                      icon: const Icon(LucideIcons.packagePlus, size: 16, color: AppColors.white),
                                      label: Text(
                                        l10n.restockBtn,
                                        style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryDark,
                                        elevation: 2,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    // Wrap with Scaffold only when accessed standalone (not inside admin dashboard)
    if (!widget.isAdmin) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: const PosDrawer(),
        appBar: AppBar(
          toolbarHeight: 64,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.secondaryAccent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              LucideIcons.menu,
              color: AppColors.white,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: l10n.menuTooltip,
          ),
          title: Text(
            l10n.productList,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isSearchVisible ? LucideIcons.x : LucideIcons.search,
                color: AppColors.white,
              ),
              onPressed: _toggleProductListSearch,
              tooltip: _isSearchVisible
                  ? l10n.closeSearchTooltip
                  : l10n.searchTooltip,
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  void _showMedTypeSheet(List<String> types, AppStrings l10n) {
    _showRightFilterPanel((dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                        l10n.filterByType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() => _selectedMedTypes.clear());
                        setState(() {});
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: AppColors.secondaryAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView(
                  children: types.map((type) {
                    final isSelected = _selectedMedTypes.contains(type);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        type,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      activeColor: AppColors.primaryDark,
                      onChanged: (val) {
                        setSheetState(() {
                          if (val == true) {
                            _selectedMedTypes.add(type);
                          } else {
                            _selectedMedTypes.remove(type);
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
}

/// Expandable bar under the app bar, matching [HomeScreen] search UX.
class _ProductListExpandableSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String closeTooltip;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _ProductListExpandableSearchBar({
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.closeTooltip,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: isVisible ? 60.0 : 0.0,
      color: AppColors.primaryDark,
      clipBehavior: Clip.hardEdge,
      child: isVisible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        AppColors.highlightActive.withValues(alpha: 0.6),
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
                    hintText: hintText,
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
                      tooltip: closeTooltip,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final String value;
  /// When set, product is low stock and this color reflects severity (green/amber/red).
  final Color? lowStockAccent;
  final bool isTaka;

  const _StockBadge({
    required this.label,
    required this.value,
    required this.lowStockAccent,
    this.isTaka = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = lowStockAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent != null
            ? accent.withValues(alpha: 0.08)
            : (isTaka ? AppColors.secondaryAccent.withValues(alpha: 0.05) : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent != null
              ? accent.withValues(alpha: 0.2)
              : (isTaka ? AppColors.secondaryAccent.withValues(alpha: 0.2) : AppColors.divider),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTaka)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: TakaSymbol(size: 12),
                ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: accent ?? AppColors.primaryDark,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryAccent,
            ),
          ),
        ],
      ),
    );
  }
}
