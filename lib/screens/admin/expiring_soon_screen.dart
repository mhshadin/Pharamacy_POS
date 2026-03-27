import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/inventory_alert_tiers.dart';
import '../../utils/med_type_icons.dart';
import '../../providers/language_provider.dart';
import '../../utils/med_type_units.dart';
import '../../utils/phone_launcher.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../../services/export_service.dart';
import 'restock_screen.dart';

class ExpiringSoonScreen extends StatefulWidget {
  const ExpiringSoonScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<ExpiringSoonScreen> createState() => _ExpiringSoonScreenState();
}

class _ExpiringSoonScreenState extends State<ExpiringSoonScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All'; // 'All' | 'Critical' | 'Warning' | 'Notice'
  String _sortBy = 'Soonest First';
  final Set<String> _selectedCompanies = {};

  static const _sortOptions = [
    'Soonest First',
    'Latest First',
    'A \u2192 Z',
    'Z \u2192 A',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> source, AdminProvider admin) {
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

    // Urgency chip (matches traffic-light tiers)
    if (_filter == 'Critical') {
      list = list
          .where(
            (p) => admin.expiryTierFor(p) == InventoryAlertTier.critical,
          )
          .toList();
    } else if (_filter == 'Warning') {
      list = list
          .where(
            (p) => admin.expiryTierFor(p) == InventoryAlertTier.moderate,
          )
          .toList();
    } else if (_filter == 'Notice') {
      list = list
          .where((p) => admin.expiryTierFor(p) == InventoryAlertTier.mild)
          .toList();
    }

    // Multi-company
    if (_selectedCompanies.isNotEmpty) {
      list = list
          .where((p) => _selectedCompanies.contains(p.companyName))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Soonest First':
        list.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
        break;
      case 'Latest First':
        list.sort((a, b) => b.daysUntilExpiry.compareTo(a.daysUntilExpiry));
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                  const Divider(height: 1, color: AppColors.divider),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: allCompanies.map((company) {
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

  void _showOrderQtyModal(List<Product> filtered) {
    final defaultBoxes = context.read<AdminProvider>().defaultOrderBoxes;
    final controllers = {
      for (var p in filtered)
        p.id: TextEditingController(text: '$defaultBoxes'),
    };

    showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Set Order Quantities',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter how many boxes to order for each product.',
                style: TextStyle(
                  color: AppColors.secondaryAccent,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, idx) {
                    final p = filtered[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                    fontSize: 13,
                                  ),
                                ),
                                if (p.companyName != null &&
                                    p.companyName!.isNotEmpty)
                                  Text(
                                    p.companyName!,
                                    style: const TextStyle(
                                      color: AppColors.secondaryAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              controller: controllers[p.id],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Boxes',
                                labelStyle: const TextStyle(
                                  color: AppColors.secondaryAccent,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryDark,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop<Map<String, int>?>(ctx, null);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryAccent),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final orderQtys = {
                for (var p in filtered)
                  p.id: int.tryParse(controllers[p.id]?.text ?? '0') ?? 0,
              };
              Navigator.pop<Map<String, int>?>(ctx, orderQtys);
            },
            icon: const Icon(
              LucideIcons.arrowRight,
              color: AppColors.white,
              size: 18,
            ),
            label: const Text(
              'Next',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ).then((orderQtys) {
      for (var c in controllers.values) {
        c.dispose();
      }
      if (!mounted) return;
      if (orderQtys == null) return;
      _showFormatSheet(filtered, orderQtys);
    });
  }

  void _showFormatSheet(List<Product> products, Map<String, int> orderQtys) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Export Order List',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.fileText, color: Colors.red),
            title: const Text(
              'Export to PDF',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _doExport(products, orderQtys, isPdf: true);
            },
          ),
          ListTile(
            leading: const Icon(
              LucideIcons.fileSpreadsheet,
              color: Colors.green,
            ),
            title: const Text(
              'Export to CSV',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _doExport(products, orderQtys, isPdf: false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
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
          title: 'Expiring Soon',
          l10n: l10n,
        );
      } else {
        path = await ExportService.exportOrderListToCsv(
          products,
          orderQtys,
          'Expiring Soon',
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

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final allExpiring = admin.expiringSoonProducts;
    final filtered = _applyFilters(allExpiring, admin);
    final showSupplierInfo = admin.showSupplierInfo;

    final allCompanies = allExpiring
        .map((p) => p.companyName)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final hasCompanies = allCompanies.isNotEmpty;

    if (allExpiring.isEmpty) {
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(title: const Text('Expiring Soon Alerts'), centerTitle: true)
            : null,
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle2, size: 56, color: AppColors.success),
              const SizedBox(height: 16),
              const Text(
                'No products expiring soon!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All products have more than ${admin.expiringSoonDays} days until expiry.',
                style: const TextStyle(
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
          ? AppBar(title: const Text('Expiring Soon Alerts'), centerTitle: true)
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
                // Urgency chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in ['All', 'Critical', 'Warning', 'Notice'])
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
                    ],
                  ),
                ),
                // Company chip (only if products have company names)
                if (hasCompanies) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showCompanySheet(allCompanies),
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

          // ── List ─────────────────────────────────────────────
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
                    itemBuilder: (_, idx) {
                      final l10n = context.read<LanguageProvider>().strings;
                      final product = filtered[idx];
                      final unitLabels = MedTypeUnits.getLabels(product.medType, l10n);
                      final days = product.daysUntilExpiry;
                      final tier = admin.expiryTierFor(product);
                      final accent = tier.accentColor;
                      final iconData = switch (tier) {
                        InventoryAlertTier.critical => LucideIcons.alertOctagon,
                        InventoryAlertTier.moderate => LucideIcons.clock,
                        InventoryAlertTier.mild => LucideIcons.calendarDays,
                      };
                      final supplierPhone =
                          showSupplierInfo ? product.supplierPhone?.trim() : null;
                      final hasSupplierPhone =
                          supplierPhone != null && supplierPhone.isNotEmpty;

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RestockScreen(product: product),
                            ),
                          );
                        },
                        child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                iconData,
                                color: accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (product.medType != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4, bottom: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: MedTypeIcons.getColor(product.medType).withValues(alpha: 0.24),
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
                                    ),
                                  Text(
                                    '${l10n.inventory}: ${product.stockBoxes} ${unitLabels['unit1']?.toLowerCase() ?? 'boxes'} • ${product.remainingStrips} ${unitLabels['unit2']?.toLowerCase() ?? 'strips'} • ${product.totalPieces} ${unitLabels['unit3']?.toLowerCase() ?? 'pcs'}',
                                    style: const TextStyle(
                                      color: AppColors.secondaryAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Expires: ${product.expiryDate!.day}/${product.expiryDate!.month}/${product.expiryDate!.year}',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasSupplierPhone)
                                  IconButton(
                                    tooltip: 'Call supplier',
                                    onPressed: () =>
                                        tryDialPhone(context, supplierPhone),
                                    icon: const Icon(
                                      LucideIcons.phoneCall,
                                      color: AppColors.primaryDark,
                                      size: 20,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$days',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: accent,
                                        ),
                                      ),
                                      Text(
                                        'days',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: accent,
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
                ),
          ),
        ],
      ),
    );
  }
}
