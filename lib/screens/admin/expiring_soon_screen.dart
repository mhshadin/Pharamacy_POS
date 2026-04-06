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
import '../../widgets/shared/empty_state_widget.dart';
import '../../widgets/shared/right_filter_panel.dart';
import '../../l10n/app_strings.dart';
import 'restock_screen.dart';

class ExpiringSoonScreen extends StatefulWidget {
  const ExpiringSoonScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<ExpiringSoonScreen> createState() => _ExpiringSoonScreenState();
}

class _ExpiringSoonScreenState extends State<ExpiringSoonScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearchVisible = false;
  String _searchQuery = '';
  String _filter = 'All'; // Using keys for logic
  String _sortBy = 'Soonest First';
  final Set<String> _selectedCompanies = {};

  // Note: These are logic values that map to l10n keys in the UI
  static const _sortOptions = [
    'Soonest First',
    'Latest First',
    'A \u2192 Z',
    'Z \u2192 A',
  ];

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

  void _showExpiryUrgencyFilterPanel(AppStrings l10n) {
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
                    l10n.filterByExpiryUrgency,
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
                  ('Critical', l10n.filterCritical),
                  ('Warning', l10n.filterWarning),
                  ('Notice', l10n.filterNotice),
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
        title: Text(
          context.read<LanguageProvider>().strings.setOrderQuantities,
          style: const TextStyle(
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
              Text(
                context.read<LanguageProvider>().strings.enterBoxesToOrder,
                style: const TextStyle(
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
                                labelText: context.read<LanguageProvider>().strings.boxes,
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
            child: Text(
              context.read<LanguageProvider>().strings.cancelBtn,
              style: const TextStyle(color: AppColors.secondaryAccent),
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
            label: Text(
              context.read<LanguageProvider>().strings.next,
              style: const TextStyle(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.read<LanguageProvider>().strings.exportOrderList,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.fileText, color: Colors.red),
            title: Text(
              context.read<LanguageProvider>().strings.exportPdf,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
            title: Text(
              context.read<LanguageProvider>().strings.exportCsv,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
          title: l10n.expiringSoonTitle,
          l10n: l10n,
        );
      } else {
        path = await ExportService.exportOrderListToCsv(
          products,
          orderQtys,
          l10n.expiringSoonTitle,
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
      final l10n = context.watch<LanguageProvider>().strings;
      return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(l10n.expiringSoonTitle),
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
          title: l10n.noExpiringSoon,
          message: l10n.allProductsValidForDays(admin.expiringSoonDays),
          icon: LucideIcons.checkCircle2,
        ),
      );
    }

    final l10n = context.watch<LanguageProvider>().strings;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.expiringSoonTitle),
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
          _ExpiringSoonExpandableSearchBar(
            isVisible: widget.showAppBar ? _isSearchVisible : true,
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
                // Sort + filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: l10n.sortBtn,
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
                                  Text(
                                    o == 'Soonest First'
                                        ? l10n.sortSoonestFirst
                                        : o == 'Latest First'
                                            ? l10n.sortLatestFirst
                                            : o == 'A \u2192 Z'
                                                ? l10n.sortNameAZ
                                                : l10n.sortNameZA,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      adminFilterIconButton(
                        icon: LucideIcons.listFilter,
                        tooltip: l10n.filterByExpiryUrgency,
                        activeCount: _filter == 'All' ? 0 : 1,
                        onPressed: () => _showExpiryUrgencyFilterPanel(l10n),
                      ),
                      if (hasCompanies) ...[
                        const SizedBox(width: 8),
                        adminFilterIconButton(
                          icon: LucideIcons.building2,
                          tooltip: l10n.filterByCompany,
                          activeCount: _selectedCompanies.length,
                          onPressed: () =>
                              _showCompanySheet(allCompanies, l10n),
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
                      l10n.productsCount(filtered.length),
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
                        label: Text(
                          l10n.exportOrderList,
                          style: const TextStyle(
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
                        _sortBy = 'Soonest First';
                      });
                    },
                    actionLabel: l10n.clearAllFilters,
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

class _ExpiringSoonExpandableSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _ExpiringSoonExpandableSearchBar({
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
