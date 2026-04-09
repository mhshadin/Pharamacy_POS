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
import '../../widgets/shared/empty_state_widget.dart';
import '../../utils/med_type_icons.dart';

class ProductListScreen extends StatefulWidget {
  final bool isAdmin;
  /// When set (e.g. from [AdminDashboardScreen]), switches to Add Product in-shell
  /// instead of pushing a new route (avoids missing [Material] / wrong theme).
  final VoidCallback? onOpenAddProduct;
  final bool? externalSearchVisible;
  final ValueChanged<bool>? onSearchVisibilityChanged;

  const ProductListScreen({
    super.key,
    required this.isAdmin,
    this.onOpenAddProduct,
    this.externalSearchVisible,
    this.onSearchVisibilityChanged,
  });

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
  void initState() {
    super.initState();
    if (widget.externalSearchVisible != null) {
      _isSearchVisible = widget.externalSearchVisible!;
    }
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ext = widget.externalSearchVisible;
    if (ext != null && ext != _isSearchVisible) {
      setState(() {
        _isSearchVisible = ext;
        if (!_isSearchVisible) {
          _searchController.clear();
          _searchFocus.unfocus();
        }
      });
    }
  }

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
    widget.onSearchVisibilityChanged?.call(_isSearchVisible);
  }

  Widget _buildFilterChipList(AppStrings l10n) {
    if (_selectedCompanies.isEmpty && _selectedGenericNames.isEmpty && _selectedMedTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
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
                  style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)
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
        label: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
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
                          fontSize: 14,
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
                        fontSize: 13,
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
                          fontSize: 14,
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
                        fontSize: 13,
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

  Widget _buildUnifiedFilterBar({
    required AppStrings l10n,
    required List<String> allCompanies,
    required List<String> allGenerics,
    required AdminProvider admin,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sort
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: l10n.sort,
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) => setState(() => _sortBy = v),
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.2)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(LucideIcons.arrowUpDown, color: AppColors.primaryDark, size: 18),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 7,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              itemBuilder: (_) => _sortOptions
                  .map(
                    (o) => PopupMenuItem(
                  value: o,
                  child: Row(
                    children: [
                      Icon(
                        _sortBy == o ? LucideIcons.checkCircle2 : LucideIcons.circle,
                        size: 16,
                        color: _sortBy == o ? AppColors.primaryDark : AppColors.secondaryAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.sortOption(o)),
                    ],
                  ),
                ),
              )
                  .toList(),
            ),
          ),

          // Company
          Expanded(
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(LucideIcons.building2, color: _selectedCompanies.isNotEmpty ? AppColors.primaryDark : Colors.grey.shade500),
                  if (_selectedCompanies.isNotEmpty)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
                        child: Text('${_selectedCompanies.length}', style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showCompanySheet(allCompanies, l10n),
            ),
          ),

          // Generic
          Expanded(
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(LucideIcons.flaskConical, color: _selectedGenericNames.isNotEmpty ? AppColors.primaryDark : Colors.grey.shade500),
                  if (_selectedGenericNames.isNotEmpty)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
                        child: Text('${_selectedGenericNames.length}', style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showGenericSheet(allGenerics, l10n),
            ),
          ),

          // Type
          Expanded(
            child: IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(LucideIcons.layers, color: _selectedMedTypes.isNotEmpty ? AppColors.primaryDark : Colors.grey.shade500),
                  if (_selectedMedTypes.isNotEmpty)
                    Positioned(
                      top: -4, right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
                        child: Text('${_selectedMedTypes.length}', style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showMedTypeSheet(admin.medicineTypes, l10n),
            ),
          ),

          // Divider
          if (widget.isAdmin)
            Container(
              height: 32,
              width: 1.5,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),

          // Add Product Button
          if (widget.isAdmin)
            Expanded(
              flex: 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: Colors.blue.shade50,
                  onTap: () {
                    final open = widget.onOpenAddProduct;
                    if (open != null) {
                      open();
                      return;
                    }
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(LucideIcons.plusSquare, color: AppColors.primaryDark),
                  ),
                ),
              ),
            ),

          // Delete Selected Button (Only shows if in selection mode)
          if (widget.isAdmin && _isSelectionMode)
            Expanded(
              child: IconButton(
                onPressed: _selectedIds.isNotEmpty ? () => _deleteSelected(l10n) : null,
                icon: Icon(LucideIcons.trash2, color: _selectedIds.isNotEmpty ? AppColors.error : Colors.grey.shade400),
              ),
            )
        ],
      ),
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

        // Unified Filter Bar
        _buildUnifiedFilterBar(
            l10n: l10n,
            allCompanies: allCompanies,
            allGenerics: allGenerics,
            admin: admin
        ),

        // Active Filter Chips
        _buildFilterChipList(l10n),

        if (_isSelectionMode && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                    fontSize: 10,
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
                _selectedMedTypes.clear();
              });
            }
                : null,
            actionLabel: l10n.clearAllFilters,
          )
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (ctx, index) {
              final product = filtered[index];
              final isSelected = _selectedIds.contains(product.id);
              final lowAccent = admin.isProductLowStock(product)
                  ? admin.lowStockTierFor(product).accentColor
                  : null;
              final minL = product.minStockLevel;
              final stockRatio = minL > 0
                  ? (product.stockStrips / minL).clamp(0.0, 1.0)
                  : 1.0;
              final stockPercent = (stockRatio * 100).round();

              final medColor = product.medType != null ? MedTypeIcons.getColor(product.medType) : AppColors.primaryDark;
              final stockBarColor = lowAccent ?? Colors.green.shade500;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : Colors.grey.shade100,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
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
                            builder: (_) => EditProductScreen(product: product),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Icon, Titles, Status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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

                              // Med Icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: medColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    product.medType != null ? MedTypeIcons.getIcon(product.medType) : LucideIcons.pill,
                                    color: medColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      product.companyName != null && product.companyName!.isNotEmpty
                                          ? '${product.generic} • ${product.companyName}'
                                          : product.generic,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Status & Progress
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: lowAccent != null ? lowAccent.withValues(alpha: 0.1) : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: lowAccent != null ? lowAccent.withValues(alpha: 0.2) : Colors.green.shade100,
                                        ),
                                      ),
                                      child: Text(
                                        lowAccent != null ? l10n.lowStockBadge : l10n.inStock,
                                        style: TextStyle(
                                          color: lowAccent ?? Colors.green.shade600,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$stockPercent%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (product.medType != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: medColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(MedTypeIcons.getIcon(product.medType), size: 8, color: medColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  product.medType!,
                                                  style: TextStyle(fontSize: 8, color: medColor, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (product.power != null &&
                                            product.power!.trim().isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.deepPurple.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              product.power!,
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: stockRatio,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor: AlwaysStoppedAnimation<Color>(stockBarColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 4-Column Stats Grid
                          Row(
                            children: [
                              Expanded(child: _StatBox(value: '${product.stockBoxes}', label: l10n.boxes)),
                              const SizedBox(width: 8),
                              Expanded(child: _StatBox(value: '${product.remainingStrips}', label: l10n.strips)),
                              const SizedBox(width: 8),
                              Expanded(child: _StatBox(value: '${product.totalPieces}', label: l10n.pcs)),
                              const SizedBox(width: 8),
                              Expanded(child: _StatBox(value: product.priceStrip.toStringAsFixed(2), label: l10n.stripPrice, isPrice: true)),
                            ],
                          ),

                          // Action Buttons
                          if (widget.isAdmin) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
                                      ).then((_) => setState(() {}));
                                    },
                                    icon: const Icon(LucideIcons.edit, size: 16),
                                    label: Text(l10n.editBtn),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                      side: BorderSide(color: Colors.grey.shade200),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => RestockScreen(product: product)),
                                      ).then((_) => setState(() {}));
                                    },
                                    icon: const Icon(LucideIcons.packagePlus, size: 16),
                                    label: Text(l10n.restockBtn),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryDark,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 4,
                                      shadowColor: AppColors.primaryDark.withValues(alpha: 0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
        backgroundColor: const Color(0xFFF7F8F2), // Matching the HTML body background
        drawer: const PosDrawer(),
        appBar: AppBar(
          toolbarHeight: 64,
          backgroundColor: AppColors.primaryDark,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          foregroundColor: AppColors.white,
          leading: IconButton(
            icon: const Icon(LucideIcons.menu, color: AppColors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: l10n.menuTooltip,
          ),
          title: Text(
            l10n.productList,
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isSearchVisible ? LucideIcons.x : LucideIcons.search,
                color: AppColors.white,
              ),
              onPressed: _toggleProductListSearch,
              tooltip: _isSearchVisible ? l10n.closeSearchTooltip : l10n.searchTooltip,
            ),
          ],
        ),
        body: body,
      );
    }

    return Container(
      color: const Color(0xFFF7F8F2),
      child: body,
    );
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
                          fontSize: 14,
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
                        fontSize: 13,
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

/// Expandable bar under the app bar.
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
              prefixIcon: Icon(
                LucideIcons.search,
                color: Colors.grey.shade400,
                size: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                onPressed: controller.text.isEmpty
                    ? null
                    : () {
                        controller.clear();
                        onChanged('');
                      },
                tooltip: closeTooltip,
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

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final bool isPrice;

  const _StatBox({
    required this.value,
    required this.label,
    this.isPrice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isPrice ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPrice ? Colors.blue.shade100 : Colors.grey.shade100,
        ),
        boxShadow: isPrice
            ? [
          BoxShadow(
            color: Colors.blue.shade50,
            spreadRadius: 1,
            blurRadius: 0,
          )
        ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPrice)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: TakaSymbol(size: 12),
                ),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}