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

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All'; // 'All' | 'Out of Stock' | 'Low Stock'
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

  static const _sortOptions = [
    'Most Urgent',
    'Biggest Deficit',
    'A \u2192 Z',
    'Z \u2192 A',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  void _showCompanySheet(List<String> allCompanies) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter by Company',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: allCompanies.map((c) {
                    final isSelected = _selectedCompanies.contains(c);
                    return CheckboxListTile(
                      title: Text(c),
                      value: isSelected,
                      activeColor: AppColors.primaryDark,
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            _selectedCompanies.add(c);
                          } else {
                            _selectedCompanies.remove(c);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() => _selectedCompanies.clear());
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport(
    List<Product> products,
    Map<String, int> orderQtys, {
    required bool isPdf,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    String? path;
    try {
      if (isPdf) {
        path = await ExportService.exportOrderListToPdf(
          products: products,
          orderQtys: orderQtys,
          title: 'Low Stock',
        );
      } else {
        path = await ExportService.exportOrderListToCsv(
          products,
          orderQtys,
          'Low Stock',
        );
      }
    } catch (e) {
      path = null;
    }

    if (!mounted) return;

    if (path != null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Order list exported successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(path),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to export order list.'),
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
      builder: (context) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Confirm Order Quantities'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (c, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('Deficit: ${p.minStockLevel - p.stockStrips} ${(p.unitLabels['unit2'] ?? 'strips').toLowerCase()}'),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: '${orderQtys[p.id]}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(suffixText: (p.unitLabels['unit1'] ?? p.unitLabels['unit2'] ?? 'bx').toLowerCase().substring(0, 2)),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _doExport(products, orderQtys, isPdf: false);
              },
              icon: const Icon(LucideIcons.fileSpreadsheet),
              label: const Text('CSV'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _doExport(products, orderQtys, isPdf: true);
              },
              icon: const Icon(LucideIcons.fileText),
              label: const Text('PDF'),
            ),
          ],
        ),
      ),
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
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(title: const Text('Low Stock Alerts'), centerTitle: true)
            : null,
        backgroundColor: AppColors.background,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.checkCircle2, size: 56, color: AppColors.success),
              SizedBox(height: 16),
              Text(
                'All products well stocked!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'No products below minimum stock level.',
                style: TextStyle(
                  color: AppColors.secondaryAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Low Stock Alerts'), centerTitle: true)
          : null,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Filter controls ──────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search + Sort
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim()),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search name, generic, company…',
                            hintStyle: TextStyle(
                              color: AppColors.secondaryAccent.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              color: AppColors.secondaryAccent,
                              size: 18,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      LucideIcons.x,
                                      size: 16,
                                      color: AppColors.secondaryAccent,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
                const SizedBox(height: 8),
                // Severity chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in ['All', 'Out of Stock', 'Low Stock'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == label,
                            onSelected: (_) =>
                                setState(() => _filter = label),
                            selectedColor:
                                AppColors.primaryDark.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _filter == label
                                  ? AppColors.primaryDark
                                  : AppColors.secondaryAccent,
                              fontWeight: _filter == label
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: _filter == label
                                  ? AppColors.primaryDark
                                  : AppColors.divider,
                            ),
                            backgroundColor: AppColors.surfaceLight,
                            showCheckmark: false,
                          ),
                        ),
                      if (hasCompanies) ...[
                        const SizedBox(
                          height: 24,
                          child: VerticalDivider(
                            width: 16,
                            color: AppColors.divider,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showCompanySheet(allCompanies),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedCompanies.isNotEmpty
                                  ? AppColors.primaryDark.withValues(alpha: 0.12)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedCompanies.isNotEmpty
                                    ? AppColors.primaryDark
                                    : AppColors.divider,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.building2,
                                  size: 14,
                                  color: _selectedCompanies.isNotEmpty
                                      ? AppColors.primaryDark
                                      : AppColors.secondaryAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCompanies.isEmpty
                                      ? 'All Companies'
                                      : _selectedCompanies.length == 1
                                          ? _selectedCompanies.first
                                          : '${_selectedCompanies.length} Companies',
                                  style: TextStyle(
                                    color: _selectedCompanies.isNotEmpty
                                        ? AppColors.primaryDark
                                        : AppColors.secondaryAccent,
                                    fontWeight: _selectedCompanies.isNotEmpty
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  LucideIcons.chevronDown,
                                  size: 14,
                                  color: _selectedCompanies.isNotEmpty
                                      ? AppColors.primaryDark
                                      : AppColors.secondaryAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Result count + Export
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} product${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (filtered.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _showOrderQtyModal(filtered),
                        icon: const Icon(
                          LucideIcons.download,
                          size: 15,
                          color: AppColors.primaryDark,
                        ),
                        label: const Text(
                          'Export',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          backgroundColor: AppColors.primaryDark.withValues(
                            alpha: 0.08,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.searchX,
                          size: 48,
                          color: AppColors.secondaryAccent,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No products match your filters.',
                          style: TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                              _filter = 'All';
                              _selectedCompanies.clear();
                            });
                          },
                          child: const Text(
                            'Clear Filters',
                            style: TextStyle(color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: ResponsiveHelper.screenPadding(context),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final product = filtered[index];
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
                                  tooltip: 'Call supplier',
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
                                label: 'IN STOCK',
                                value: '${product.stockBoxes} ${(product.unitLabels['unit1'] ?? 'bx').toLowerCase()}',
                                bg: accent.withValues(alpha: 0.08),
                                fg: accent,
                                compact: isNarrow,
                              ),
                              const SizedBox(width: 8),
                              _statBox(
                                label: 'MIN',
                                value: '$minBoxes ${(product.unitLabels['unit1'] ?? 'bx').toLowerCase()}',
                                bg: AppColors.primaryDark.withValues(alpha: 0.06),
                                fg: AppColors.primaryDark,
                                compact: isNarrow,
                              ),
                            ],
                          );

                          final extraInfo = Text(
                            '${product.remainingStrips} ${(product.unitLabels['unit2'] ?? 'strips').toLowerCase()} • ${product.stockPcs} ${(product.unitLabels['unit3'] ?? 'pcs').toLowerCase()} extra',
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
                                      if (phoneBtn != null) phoneBtn,
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
                                              '${(percentage * 100).toInt()}% level',
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
