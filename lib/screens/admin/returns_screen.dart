import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../services/database_helper.dart';
import '../../models/sale_record.dart';
import '../../providers/pos_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/taka_symbol.dart';
import '../../widgets/drawer/pos_drawer.dart';
import '../../providers/language_provider.dart';
import '../../widgets/shared/empty_state_widget.dart';

class ReturnsScreen extends StatefulWidget {
  final bool isStandalone;
  final bool? externalSearchVisible;
  final ValueChanged<bool>? onSearchVisibilityChanged;

  const ReturnsScreen({
    super.key,
    this.isStandalone = false,
    this.externalSearchVisible,
    this.onSearchVisibilityChanged,
  });

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

enum ReturnSortOption { newest, oldest, amountHighToLow, amountLowToHigh }

class _ReturnsScreenState extends State<ReturnsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseHelper _db = DatabaseHelper();
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Map<String, List<SaleRecord>> _groupedSales = {};
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _isSearchVisible = false;
  ReturnSortOption _currentSort = ReturnSortOption.newest;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.externalSearchVisible != null) {
      _isSearchVisible = widget.externalSearchVisible!;
    }
    _searchInvoice();
  }

  @override
  void didUpdateWidget(covariant ReturnsScreen oldWidget) {
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
      _searchInvoice();
    }
  }

  void _toggleSearch() {
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
    } else {
      _searchInvoice();
    }
    widget.onSearchVisibilityChanged?.call(_isSearchVisible);
  }

  Future<void> _searchInvoice() async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _db.getSalesByInvoice(query);

    // Keep all sales visible in returns history, including fully returned ones.
    var filtered = List<SaleRecord>.from(results);
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((s) {
        final date = s.date;
        var start = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        var end = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );

        if (_startTime != null) {
          start = DateTime(
            start.year,
            start.month,
            start.day,
            _startTime!.hour,
            _startTime!.minute,
          );
        }
        if (_endTime != null) {
          end = DateTime(
            end.year,
            end.month,
            end.day,
            _endTime!.hour,
            _endTime!.minute,
          );
        }

        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_currentSort) {
      case ReturnSortOption.newest:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case ReturnSortOption.oldest:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case ReturnSortOption.amountHighToLow:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ReturnSortOption.amountLowToHigh:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    final grouped = <String, List<SaleRecord>>{};
    if (!mounted) return;
    final l10n = context.read<LanguageProvider>().strings;
    for (var s in filtered) {
      final key = s.invoiceNumber ?? l10n.unknownInvoice;
      grouped.putIfAbsent(key, () => []).add(s);
    }

    if (_minAmount != null || _maxAmount != null) {
      grouped.removeWhere((key, sales) {
        final totalAmount = sales.fold(
          0.0,
          (sum, s) => sum + s.effectiveAmount,
        );
        if (_minAmount != null && totalAmount < _minAmount!) return true;
        if (_maxAmount != null && totalAmount > _maxAmount!) return true;
        return false;
      });
    }

    setState(() {
      _groupedSales = grouped;
      _isLoading = false;
    });
  }

  Future<void> _showFilterDialog() async {
    DateTime tempStart = _startDate ?? DateTime.now();
    DateTime tempEnd = _endDate ?? DateTime.now();
    TimeOfDay? tempStartTime = _startTime;
    TimeOfDay? tempEndTime = _endTime;
    final l10n = context.read<LanguageProvider>().strings;
    TextEditingController minAmountCtrl = TextEditingController(
      text: _minAmount?.toStringAsFixed(0) ?? '',
    );
    TextEditingController maxAmountCtrl = TextEditingController(
      text: _maxAmount?.toStringAsFixed(0) ?? '',
    );

    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              title: Text(
                l10n.filterReturns,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dateRange,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          initialDateRange: DateTimeRange(
                            start: tempStart,
                            end: tempEnd,
                          ),
                          builder: (ctx, child) {
                            return Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primaryDark,
                                  onPrimary: AppColors.white,
                                  surface: AppColors.background,
                                  onSurface: AppColors.primaryDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempStart = picked.start;
                            tempEnd = picked.end;
                          });
                        }
                      },
                      icon: const Icon(LucideIcons.calendar, size: 16),
                      label: Text(
                        '${DateFormat('dd MMM yyyy').format(tempStart)} ${l10n.toLabel} ${DateFormat('dd MMM yyyy').format(tempEnd)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.amountRange,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.minAmount,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(l10n.toLabel),
                      ),
                      Expanded(
                        child: TextField(
                          controller: maxAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.maxAmount,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.timeRange,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: tempStartTime ?? TimeOfDay.now(),
                            );
                            if (t != null) {
                              setState(
                                () => tempStartTime = TimeOfDay(
                                  hour: t.hour,
                                  minute: 0,
                                ),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: Text(
                            tempStartTime?.format(context) ?? l10n.anyTime,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(l10n.toLabel),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: tempEndTime ?? TimeOfDay.now(),
                            );
                            if (t != null) {
                              setState(
                                () => tempEndTime = TimeOfDay(
                                  hour: t.hour,
                                  minute: 0,
                                ),
                              );
                            }
                          },
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: Text(
                            tempEndTime?.format(context) ?? l10n.anyTime,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    l10n.cancelBtn,
                    style: const TextStyle(color: AppColors.secondaryAccent),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      tempStartTime = null;
                      tempEndTime = null;
                    });
                  },
                  child: Text(
                    l10n.clearTime,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    l10n.apply,
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied == true) {
      // Avoid backward date ranges
      if (tempEnd.isBefore(tempStart)) {
        final t = tempStart;
        tempStart = tempEnd;
        tempEnd = t;
      }

      setState(() {
        _startDate = tempStart;
        _endDate = tempEnd;
        _startTime = tempStartTime;
        _endTime = tempEndTime;
        _minAmount = double.tryParse(minAmountCtrl.text);
        _maxAmount = double.tryParse(maxAmountCtrl.text);
      });
      _searchInvoice();
    }
  }

  /// Loads invoice items into the POS cart so the user can make corrections and
  /// complete a replacement sale. The original invoice is committed/deleted only
  /// after successful checkout from HomeScreen.
  Future<void> _loadInvoiceIntoCart(List<SaleRecord> sales) async {
    final l10n = context.read<LanguageProvider>().strings;
    final posProvider = context.read<POSProvider>();

    // Only consider items that still have unreturned qty
    final activeItems = sales.where((s) => s.effectiveQuantity > 0).toList();
    if (activeItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noItemsInvoice),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Build qty-by-name map from active (non-returned) items.
    final qtyByName = <String, int>{};
    for (final s in activeItems) {
      final q = s.effectiveQuantity;
      if (q <= 0) continue;
      qtyByName[s.productName] = (qtyByName[s.productName] ?? 0) + q;
    }

    posProvider.clearCart();
    final missing = <String>[];
    var addedAny = false;

    for (final entry in qtyByName.entries) {
      final product = await _db.getProductByName(entry.key);
      if (product == null) {
        missing.add(entry.key);
        continue;
      }
      final totalPcs = entry.value;
      final pps = product.pcsPerStrip;
      if (pps > 0) {
        final strips = totalPcs ~/ pps;
        final pcs = totalPcs % pps;
        posProvider.setQuantities(product, strips, pcs);
      } else {
        posProvider.setQuantities(product, 0, totalPcs);
      }
      addedAny = true;
    }

    if (!mounted) return;

    if (!addedAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.couldNotFindProducts}: ${missing.join(', ')}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.someProductsSkipped}: ${missing.join(', ')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }

    // Reuse the existing bottom Home route (single MobileScanner). Pushing a
    // second HomeScreen left two cameras and triggered "already running" errors.
    final sourceInvoice = activeItems.first.invoiceNumber?.trim();
    if (sourceInvoice == null || sourceInvoice.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unknownInvoice),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    posProvider.setReplacementSourceInvoiceNumber(sourceInvoice);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<LanguageProvider>().strings;
    final isSearchBarVisible =
        widget.externalSearchVisible ??
        (widget.isStandalone ? _isSearchVisible : false);
    final body = Column(
      children: [
        _ReturnsExpandableSearchBar(
          isVisible: isSearchBarVisible,
          controller: _searchController,
          focusNode: _searchFocus,
          onSubmitted: _searchInvoice,
          onClose: _toggleSearch,
        ),

        // Filter & Sort Row
        Padding(
          padding: ResponsiveHelper.screenPadding(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const controlHeight = 44.0;
              final controlRadius = BorderRadius.circular(10);
              final showSortLabel = constraints.maxWidth >= 390;

              final filterControl = Material(
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: controlRadius,
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: InkWell(
                  borderRadius: controlRadius,
                  onTap: _showFilterDialog,
                  child: SizedBox(
                    height: controlHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.calendar,
                          size: 14,
                          color: AppColors.secondaryAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.filters,
                          style: const TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final sortControl = Container(
                height: controlHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    if (showSortLabel) ...[
                      Text(
                        '${l10n.sortBy}:',
                        style: const TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ReturnSortOption>(
                          isExpanded: true,
                          value: _currentSort,
                          icon: const Icon(LucideIcons.chevronDown, size: 14),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          selectedItemBuilder: (_) => [
                            Center(
                              child: Text(
                                l10n.sortNewest,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Center(
                              child: Text(
                                l10n.sortOldest,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Center(
                              child: Text(
                                l10n.sortAmountHigh,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Center(
                              child: Text(
                                l10n.sortAmountLow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (ReturnSortOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _currentSort = newValue;
                                _searchInvoice();
                              });
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: ReturnSortOption.newest,
                              child: Text(l10n.sortNewest),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.oldest,
                              child: Text(l10n.sortOldest),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.amountHighToLow,
                              child: Text(l10n.sortAmountHigh),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.amountLowToHigh,
                              child: Text(l10n.sortAmountLow),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );

              return Row(
                children: [
                  Expanded(child: filterControl),
                  const SizedBox(width: 8),
                  Expanded(child: sortControl),
                ],
              );
            },
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasSearched
              ? EmptyStateWidget(
                  title: l10n.returns,
                  message: l10n.searchHelpText,
                  icon: LucideIcons.receipt,
                )
              : _groupedSales.isEmpty
              ? EmptyStateWidget(
                  title: l10n.noResults,
                  message: l10n.noProductsMatchCriteria,
                  icon: LucideIcons.searchX,
                  onAction: () {
                    setState(() {
                      _searchController.clear();
                      _isSearchVisible = false;
                      _searchFocus.unfocus();
                      _startDate = null;
                      _endDate = null;
                      _startTime = null;
                      _endTime = null;
                      _minAmount = null;
                      _maxAmount = null;
                    });
                    _searchInvoice();
                  },
                  actionLabel: l10n.clearAllFilters,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupedSales.keys.length,
                  itemBuilder: (ctx, index) {
                    final invoiceStr = _groupedSales.keys.elementAt(index);
                    final salesForInvoice = _groupedSales[invoiceStr]!;
                    final bool allReturned = salesForInvoice.every(
                      (s) => (s.quantity - s.returnedQuantity) <= 0,
                    );
                    final tileWidth = MediaQuery.sizeOf(ctx).width;
                    final bool isVeryCompact = tileWidth < 480;

                    return Card(
                      color: AppColors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shadowColor: AppColors.primaryDark.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: allReturned
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.divider,
                          width: allReturned ? 2 : 1,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  (allReturned
                                          ? AppColors.success
                                          : AppColors.primaryDark)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              allReturned
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.fileText,
                              color: allReturned
                                  ? AppColors.success
                                  : AppColors.primaryDark,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            invoiceStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.calendar,
                                      size: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                      ).format(salesForInvoice.first.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const TakaSymbol(
                                      size: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      salesForInvoice
                                          .fold(
                                            0.0,
                                            (sum, s) => sum + s.effectiveAmount,
                                          )
                                          .toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                                if (allReturned)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l10n.fullyReturned,
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!allReturned && isVeryCompact)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _loadInvoiceIntoCart(
                                              salesForInvoice,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                          foregroundColor: AppColors.white,
                                          padding: EdgeInsets.zero,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.returnItems,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: (allReturned || isVeryCompact)
                              ? const SizedBox.shrink()
                              : SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () => _loadInvoiceIntoCart(
                                      salesForInvoice,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.returnItems,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                          children: [
                            const Divider(height: 1),
                            ...salesForInvoice.map(
                              (sale) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sale.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (sale.batchNumber != null)
                                            Text(
                                              '${l10n.batchLabel}: ${sale.batchNumber}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.secondaryAccent,
                                              ),
                                            ),
                                          if (sale.effectiveQuantity <= 0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                l10n.fullyReturned,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.9),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        sale.returnedQuantity > 0
                                            ? '${l10n.qtyLabel}: ${sale.effectiveQuantity}\n(${l10n.retLabel}: ${sale.returnedQuantity})'
                                            : '${l10n.qtyLabel}: ${sale.effectiveQuantity}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: sale.effectiveQuantity <= 0
                                              ? AppColors.secondaryAccent
                                              : AppColors.primaryDark,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TakaSymbol(
                                            size: 13,
                                            color: sale.effectiveQuantity <= 0
                                                ? AppColors.secondaryAccent
                                                : AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            sale.effectiveAmount
                                                .toStringAsFixed(2),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: sale.effectiveQuantity <= 0
                                                  ? AppColors.secondaryAccent
                                                  : AppColors.success,
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

    if (widget.isStandalone) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: const PosDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          leading: IconButton(
            icon: const Icon(LucideIcons.menu, color: AppColors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            l10n.returns,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearchVisible ? LucideIcons.x : LucideIcons.search,
                color: AppColors.white,
              ),
              onPressed: _toggleSearch,
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
}

class _ReturnsExpandableSearchBar extends StatelessWidget {
  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onClose;

  const _ReturnsExpandableSearchBar({
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
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
      clipBehavior: Clip.hardEdge,
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
                  onSubmitted: (_) => onSubmitted(),
                  textInputAction: TextInputAction.search,
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
