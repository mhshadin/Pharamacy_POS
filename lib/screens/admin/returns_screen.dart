import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../services/database_helper.dart';
import '../../models/sale_record.dart';
import '../../providers/admin_provider.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/taka_symbol.dart';
import '../../widgets/drawer/pos_drawer.dart';

class ReturnsScreen extends StatefulWidget {
  final bool isStandalone;
  const ReturnsScreen({super.key, this.isStandalone = false});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

enum ReturnSortOption { newest, oldest, amountHighToLow, amountLowToHigh }

class _ReturnsScreenState extends State<ReturnsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseHelper _db = DatabaseHelper();
  final _searchController = TextEditingController();

  Map<String, List<SaleRecord>> _groupedSales = {};
  bool _hasSearched = false;
  bool _isLoading = false;
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchInvoice();
  }

  Future<void> _searchInvoice() async {
    final query = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _db.getSalesByInvoice(query);

    var filtered = results.where((s) => s.quantity > 0).toList();
    if (_startDate != null && _endDate != null) {
      filtered = results.where((s) {
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
    for (var s in filtered) {
      final key = s.invoiceNumber ?? 'Unknown Invoice';
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
              title: const Text(
                'Filter Returns',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range',
                    style: TextStyle(
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
                            final d = await showDatePicker(
                              context: context,
                              initialDate: tempStart,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => tempStart = d);
                          },
                          icon: const Icon(LucideIcons.calendar, size: 16),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(tempStart),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: tempEnd,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => tempEnd = d);
                          },
                          icon: const Icon(LucideIcons.calendar, size: 16),
                          label: Text(
                            DateFormat('dd MMM yyyy').format(tempEnd),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amount Range (৳) (Optional)',
                    style: TextStyle(
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
                          decoration: const InputDecoration(
                            hintText: 'Min ৳',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: maxAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Max ৳',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Time Range (Optional)',
                    style: TextStyle(
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
                            if (t != null) setState(() => tempStartTime = t);
                          },
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: Text(
                            tempStartTime?.format(context) ?? 'Any time',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: tempEndTime ?? TimeOfDay.now(),
                            );
                            if (t != null) setState(() => tempEndTime = t);
                          },
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: Text(
                            tempEndTime?.format(context) ?? 'Any time',
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.secondaryAccent),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      tempStartTime = null;
                      tempEndTime = null;
                    });
                  },
                  child: const Text(
                    'Clear Time',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: AppColors.white),
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

  Future<void> _processInvoiceReturn(
    String invoiceNumber,
    List<SaleRecord> sales,
  ) async {
    final returnableSales = sales
        .where((s) => (s.quantity - s.returnedQuantity) > 0)
        .toList();

    if (returnableSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All items in this invoice are already returned.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uniqueNames = returnableSales.map((s) => s.productName).toSet();
    final Map<String, int> pcsPerStripByName = {};
    for (final name in uniqueNames) {
      final p = await _db.getProductByName(name);
      final v = p?.pcsPerStrip ?? 0;
      pcsPerStripByName[name] = v > 0 ? v : 0;
    }

    if (!mounted) return;

    Map<String, int> returnPcs = {for (var s in returnableSales) s.id: 0};
    Map<String, int> returnStrips = {for (var s in returnableSales) s.id: 0};

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            int requestedPcsForSale(SaleRecord sale) {
              final pcs = returnPcs[sale.id] ?? 0;
              final strips = returnStrips[sale.id] ?? 0;
              final pps = pcsPerStripByName[sale.productName] ?? 0;
              return pcs + (pps > 0 ? strips * pps : 0);
            }

            final hasReturns = returnableSales.any(
              (s) => requestedPcsForSale(s) > 0,
            );
            return AlertDialog(
              backgroundColor: AppColors.background,
              title: Text(
                'Return items for $invoiceNumber',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: returnableSales.length,
                  itemBuilder: (context, index) {
                    final sale = returnableSales[index];
                    final maxQty = sale.quantity - sale.returnedQuantity;
                    final currentPcs = returnPcs[sale.id] ?? 0;
                    final currentStrips = returnStrips[sale.id] ?? 0;
                    final pcsPerStrip = pcsPerStripByName[sale.productName] ?? 0;
                    final totalRequestedPcs = requestedPcsForSale(sale);
                    final canUseStrips = pcsPerStrip > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sale.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  canUseStrips
                                      ? 'Max returnable: $maxQty pcs • 1 strip = $pcsPerStrip pcs'
                                      : 'Max returnable: $maxQty pcs',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (canUseStrips)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Strips',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () {
                                        if (currentStrips > 0) {
                                          setState(() {
                                            returnStrips[sale.id] =
                                                currentStrips - 1;
                                          });
                                        }
                                      },
                                      icon:
                                          const Icon(LucideIcons.minusCircle),
                                      color: currentStrips > 0
                                          ? AppColors.primaryDark
                                          : AppColors.divider,
                                    ),
                                    SizedBox(
                                      width: 26,
                                      child: Text(
                                        '$currentStrips',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () {
                                        if (totalRequestedPcs + pcsPerStrip <=
                                            maxQty) {
                                          setState(() {
                                            returnStrips[sale.id] =
                                                currentStrips + 1;
                                          });
                                        }
                                      },
                                      icon: const Icon(LucideIcons.plusCircle),
                                      color: (totalRequestedPcs + pcsPerStrip <=
                                              maxQty)
                                          ? AppColors.primaryDark
                                          : AppColors.divider,
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Pcs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () {
                                      if (currentPcs > 0) {
                                        setState(() {
                                          returnPcs[sale.id] = currentPcs - 1;
                                        });
                                      }
                                    },
                                    icon: const Icon(LucideIcons.minusCircle),
                                    color: currentPcs > 0
                                        ? AppColors.primaryDark
                                        : AppColors.divider,
                                  ),
                                  SizedBox(
                                    width: 26,
                                    child: Text(
                                      '$currentPcs',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () {
                                      if (totalRequestedPcs + 1 <= maxQty) {
                                        setState(() {
                                          returnPcs[sale.id] = currentPcs + 1;
                                        });
                                      }
                                    },
                                    icon: const Icon(LucideIcons.plusCircle),
                                    color: (totalRequestedPcs + 1 <= maxQty)
                                        ? AppColors.primaryDark
                                        : AppColors.divider,
                                  ),
                                ],
                              ),
                              if (totalRequestedPcs > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Selected: $totalRequestedPcs pcs',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.secondaryAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: hasReturns ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: const Text(
                    'Confirm Return',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    for (var sale in returnableSales) {
      final pcs = returnPcs[sale.id] ?? 0;
      final strips = returnStrips[sale.id] ?? 0;
      final pps = pcsPerStripByName[sale.productName] ?? 0;
      final qty = pcs + (pps > 0 ? strips * pps : 0);
      if (qty > 0) await _db.returnSale(sale, qty);
    }

    await _searchInvoice();
    if (!mounted) return;
    await context.read<AdminProvider>().loadData();
    if (!mounted) return;
    await context.read<POSProvider>().loadProducts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Returns processed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPhoneNarrow = screenWidth < 420;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: isPhoneNarrow
              ? Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider, width: 2),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _searchInvoice(),
                        decoration: InputDecoration(
                          hintText: 'Search Invoice No. or Product Name...',
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.primaryDark,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _searchInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.divider, width: 2),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _searchInvoice(),
                          decoration: InputDecoration(
                            hintText: 'Search Invoice No. or Product Name...',
                            prefixIcon: const Icon(
                              LucideIcons.search,
                              color: AppColors.primaryDark,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _searchInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Sort Options Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactControls = constraints.maxWidth < 420;
              const controlHeight = 40.0;
              final controlRadius = BorderRadius.circular(8);
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Filter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Filter:',
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: controlHeight,
                        child: Material(
                          color: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: controlRadius,
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          child: InkWell(
                            borderRadius: controlRadius,
                            onTap: _showFilterDialog,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.calendar,
                                    size: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                  const SizedBox(width: 6),
                                  if (_startDate != null ||
                                      _minAmount != null ||
                                      _maxAmount != null)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: compactControls ? 180 : 260,
                                      ),
                                      child: Text(
                                        [
                                          if (_startDate != null)
                                            _startDate!.day == _endDate!.day &&
                                                    _startDate!.month ==
                                                        _endDate!.month &&
                                                    _startDate!.year ==
                                                        _endDate!.year
                                                ? DateFormat('dd MMM')
                                                        .format(_startDate!) +
                                                    (_startTime != null
                                                        ? ' (${_startTime!.format(context)} - ${_endTime?.format(context) ?? '*'})'
                                                        : '')
                                                : '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                                          if (_minAmount != null ||
                                              _maxAmount != null)
                                            '৳${_minAmount?.toStringAsFixed(0) ?? '0'} - ৳${_maxAmount?.toStringAsFixed(0) ?? '∞'}',
                                        ].join(' | '),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Filters',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_startDate != null ||
                          _minAmount != null ||
                          _maxAmount != null)
                        IconButton(
                          icon: const Icon(
                            LucideIcons.xCircle,
                            size: 18,
                            color: AppColors.error,
                          ),
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                              _startTime = null;
                              _endTime = null;
                              _minAmount = null;
                              _maxAmount = null;
                              _searchInvoice();
                            });
                          },
                          tooltip: 'Clear filters',
                        ),
                    ],
                  ),

                  // Sort
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sort By:',
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: controlHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: controlRadius,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButton<ReturnSortOption>(
                          value: _currentSort,
                          underline: const SizedBox(),
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (ReturnSortOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _currentSort = newValue;
                                _searchInvoice(); // Re-sort current results
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: ReturnSortOption.newest,
                              child: Text('Date: Newest'),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.oldest,
                              child: Text('Date: Oldest'),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.amountHighToLow,
                              child: Text('Amount: High to Low'),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.amountLowToHigh,
                              child: Text('Amount: Low to High'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasSearched
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.receipt,
                        size: 48,
                        color: AppColors.divider,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Search by Invoice No. or Product Name',
                        style: TextStyle(color: AppColors.secondaryAccent),
                      ),
                    ],
                  ),
                )
              : _groupedSales.isEmpty
              ? const Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                    final isCompact = tileWidth < 460;

                    return Card(
                      color: AppColors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: index == 0,
                          title: Row(
                            children: [
                              const Icon(
                                LucideIcons.fileText,
                                color: AppColors.primaryDark,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  invoiceStr,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4, left: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.clock,
                                      size: 14,
                                      color: AppColors.secondaryAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        DateFormat(
                                          'dd MMM yyyy, hh:mm a',
                                        ).format(salesForInvoice.first.date),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.secondaryAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const TakaSymbol(
                                      size: 14,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Total: ',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      salesForInvoice
                                          .fold(
                                            0.0,
                                            (sum, s) => sum + s.effectiveAmount,
                                          )
                                          .toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: allReturned
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Fully Returned',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _processInvoiceReturn(
                                      invoiceStr,
                                      salesForInvoice,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.rotateCcw,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                    label: Text(
                                      isCompact ? 'Return' : 'Return Items',
                                      style: const TextStyle(color: AppColors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      padding: isCompact
                                          ? const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            )
                                          : const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: isCompact
                                          ? VisualDensity.compact
                                          : VisualDensity.standard,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: salesForInvoice.map((sale) {
                                  final bool returned =
                                      sale.quantity > 0 &&
                                      (sale.isReturned ||
                                          sale.quantity ==
                                              sale.returnedQuantity);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: returned
                                            ? AppColors.surfaceLight
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: returned
                                              ? AppColors.success.withValues(
                                                  alpha: 0.5,
                                                )
                                              : AppColors.divider,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: returned
                                                  ? AppColors.success
                                                        .withValues(alpha: 0.1)
                                                  : AppColors.secondaryAccent
                                                        .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              returned
                                                  ? LucideIcons.checkCircle2
                                                  : LucideIcons.box,
                                              color: returned
                                                  ? AppColors.success
                                                  : AppColors.primaryDark,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sale.productName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  sale.returnedQuantity > 0
                                                      ? 'Qty: ${sale.quantity} pcs (Returned: ${sale.returnedQuantity}) • ৳${sale.amount.toStringAsFixed(2)}'
                                                      : 'Qty: ${sale.quantity} pcs • ৳${sale.amount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .secondaryAccent,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (sale.batchNumber != null)
                                                  Text(
                                                    'Batch: ${sale.batchNumber}',
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .secondaryAccent,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (returned)
                                            const Text(
                                              'Returned',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
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
            icon: const Icon(
              LucideIcons.menu,
              color: AppColors.white,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: const Text(
            'Returns',
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
