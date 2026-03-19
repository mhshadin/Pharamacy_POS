import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../../widgets/drawer/pos_drawer.dart';
import 'edit_product_screen.dart';
import '../../widgets/taka_symbol.dart';

class ProductListScreen extends StatefulWidget {
  final bool isAdmin;
  const ProductListScreen({super.key, required this.isAdmin});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  String _sortBy = 'Urgency (Recommended)';
  Set<String> _selectedCompanies = {};
  Set<String> _selectedGenericNames = {};
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  static const _sortOptions = [
    'Urgency (Recommended)',
    'Expiry: Soonest First',
    'Name: A → Z',
    'Price: High → Low',
    'Price: Low → High',
  ];

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  List<Product> _applyFiltersAndSort({
    required List<Product> source,
    required AdminProvider admin,
  }) {
    var list = List<Product>.from(source);

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
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

  void _showCompanySheet(List<String> allCompanies) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String sheetSearch = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final visible = sheetSearch.isEmpty
                ? allCompanies
                : allCompanies
                    .where((c) =>
                        c.toLowerCase().contains(sheetSearch.toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.85,
              minChildSize: 0.3,
              builder: (_, controller) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter by Company',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
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
                        onChanged: (v) =>
                            setSheetState(() => sheetSearch = v),
                        decoration: InputDecoration(
                          hintText: 'Search companies...',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryAccent
                                .withValues(alpha: 0.6),
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
                        ? const Center(
                            child: Text(
                              'No companies found',
                              style: TextStyle(
                                color: AppColors.secondaryAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView(
                            controller: controller,
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
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGenericSheet(List<String> allGenerics) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String sheetSearch = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final visible = sheetSearch.isEmpty
                ? allGenerics
                : allGenerics
                    .where((g) =>
                        g.toLowerCase().contains(sheetSearch.toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              maxChildSize: 0.85,
              minChildSize: 0.3,
              builder: (_, controller) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter by Generic',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
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
                        onChanged: (v) =>
                            setSheetState(() => sheetSearch = v),
                        decoration: InputDecoration(
                          hintText: 'Search generics...',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryAccent
                                .withValues(alpha: 0.6),
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
                        ? const Center(
                            child: Text(
                              'No generics found',
                              style: TextStyle(
                                color: AppColors.secondaryAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView(
                            controller: controller,
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
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleSelectAll(List<Product> filteredProducts) {
    setState(() {
      if (_selectedIds.length == filteredProducts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = filteredProducts.map((p) => p.id).toSet();
      }
    });
  }

  void _deleteSelected() async {
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
          height: 44,
          width: 44,
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
      children: [
        // Search + controls bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.secondaryAccent,
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: AppColors.secondaryAccent.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        color: AppColors.primaryDark,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort button
              PopupMenuButton<String>(
                tooltip: 'Sort',
                icon: SizedBox(
                  height: 44,
                  width: 44,
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
                            Text(o),
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
                tooltip: 'Filter by Company',
                activeCount: _selectedCompanies.length,
                onPressed: () => _showCompanySheet(allCompanies),
              ),
              const SizedBox(width: 8),

              // Generic filter button
              _filterButton(
                icon: LucideIcons.flaskConical,
                tooltip: 'Filter by Generic',
                activeCount: _selectedGenericNames.length,
                onPressed: () => _showGenericSheet(allGenerics),
              ),

              if (widget.isAdmin) ...[
                const SizedBox(width: 8),
                if (_isSelectionMode)
                  IconButton(
                    onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                    icon: Icon(
                      LucideIcons.trash2,
                      color: _selectedIds.isNotEmpty
                          ? AppColors.error
                          : AppColors.secondaryAccent.withValues(alpha: 0.5),
                    ),
                    tooltip: 'Delete Selected',
                  ),
                IconButton(
                  onPressed: _toggleSelectionMode,
                  icon: Icon(
                    _isSelectionMode
                        ? LucideIcons.xSquare
                        : LucideIcons.checkSquare,
                    color: AppColors.primaryDark,
                  ),
                  tooltip: _isSelectionMode
                      ? 'Cancel Selection'
                      : 'Select Items',
                ),
              ],
            ],
          ),
        ),
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
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedIds.length} Selected',
                  style: const TextStyle(
                    color: AppColors.secondaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.packageX,
                        size: 48,
                        color: AppColors.secondaryAccent,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No products found',
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final product = filtered[idx];
                    final isSelected = _selectedIds.contains(product.id);
                    return GestureDetector(
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
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryDark.withValues(alpha: 0.05)
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark
                                : admin.isProductLowStock(product)
                                ? AppColors.error.withValues(alpha: 0.3)
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
                                  child: const Icon(
                                    LucideIcons.pill,
                                    color: AppColors.secondaryAccent,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: admin.isProductLowStock(product)
                                        ? AppColors.error.withValues(alpha: 0.1)
                                        : AppColors.success.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: admin.isProductLowStock(product)
                                          ? AppColors.error.withValues(
                                              alpha: 0.3,
                                            )
                                          : AppColors.success.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    admin.isProductLowStock(product)
                                        ? 'Low Stock'
                                        : 'In Stock',
                                    style: TextStyle(
                                      color: admin.isProductLowStock(product)
                                          ? AppColors.error
                                          : AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StockBadge(
                                  label: 'Boxes',
                                  value: '${product.stockBoxes}',
                                  isLow: admin.isProductLowStock(product),
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: 'Strips',
                                  value: '${product.remainingStrips}',
                                  isLow: admin.isProductLowStock(product),
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: 'Pcs',
                                  value: '${product.totalPieces}',
                                  isLow: false,
                                ),
                                const SizedBox(width: 8),
                                _StockBadge(
                                  label: 'Strip ৳',
                                  value: product.priceStrip.toStringAsFixed(2),
                                  isTaka: true,
                                  isLow: false,
                                ),
                                const Spacer(),
                                if (widget.isAdmin)
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditProductScreen(
                                            product: product,
                                          ),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                    icon: const Icon(
                                      LucideIcons.edit,
                                      color: AppColors.secondaryAccent,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit Stock',
                                  ),
                              ],
                            ),
                          ],
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
          backgroundColor: AppColors.primaryDark,
          leading: IconButton(
            icon: const Icon(
              LucideIcons.menu,
              color: AppColors.white,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: const Text(
            'Product List',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        body: body,
      );
    }

    return body;
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isLow;
  final bool isTaka;

  const _StockBadge({
    required this.label,
    required this.value,
    required this.isLow,
    this.isTaka = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLow
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLow
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.divider,
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
                  color: isLow ? AppColors.error : AppColors.primaryDark,
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
