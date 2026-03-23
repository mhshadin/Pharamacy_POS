import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../services/database_helper.dart';
import '../../models/sale_record.dart';
import '../../providers/pos_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/taka_symbol.dart';
import '../../widgets/drawer/pos_drawer.dart';
import '../home_screen.dart';

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

  Widget _buildReturnStepperRow({
    required String label,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required bool minusEnabled,
    required bool plusEnabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryAccent,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: minusEnabled ? onMinus : null,
                  icon: Icon(
                    LucideIcons.minusCircle,
                    color: minusEnabled
                        ? AppColors.primaryDark
                        : AppColors.divider,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: plusEnabled ? onPlus : null,
                  icon: Icon(
                    LucideIcons.plusCircle,
                    color: plusEnabled
                        ? AppColors.primaryDark
                        : AppColors.divider,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Loads invoice line items into the POS cart and opens the home screen so
  /// the user can adjust quantities or complete a new sale.
  Future<void> _loadInvoiceIntoCart(List<SaleRecord> sales) async {
    final qtyByName = <String, int>{};
    for (final s in sales) {
      final q = s.effectiveQuantity;
      if (q <= 0) continue;
      qtyByName[s.productName] = (qtyByName[s.productName] ?? 0) + q;
    }
    if (qtyByName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No items to load from this invoice.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final pos = context.read<POSProvider>();
    pos.clearCart();
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
        pos.setQuantities(product, strips, pcs);
      } else {
        pos.setQuantities(product, 0, totalPcs);
      }
      addedAny = true;
    }

    if (!mounted) return;

    if (!addedAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not find product(s): ${missing.join(', ')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some products were skipped: ${missing.join(', ')}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
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

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
            final viewInsets = MediaQuery.viewInsetsOf(context);
            final maxH = MediaQuery.sizeOf(context).height * 0.85;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Material(
                    color: AppColors.background,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Text(
                              'Return items for $invoiceNumber',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                8,
                              ),
                              itemCount: returnableSales.length,
                              itemBuilder: (context, index) {
                                final sale = returnableSales[index];
                                final maxQty =
                                    sale.quantity - sale.returnedQuantity;
                                final currentPcs = returnPcs[sale.id] ?? 0;
                                final currentStrips =
                                    returnStrips[sale.id] ?? 0;
                                final pcsPerStrip =
                                    pcsPerStripByName[sale.productName] ?? 0;
                                final totalRequestedPcs =
                                    requestedPcsForSale(sale);
                                final canUseStrips = pcsPerStrip > 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  color: AppColors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          sale.productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          canUseStrips
                                              ? 'Max returnable: $maxQty pcs • 1 strip = $pcsPerStrip pcs'
                                              : 'Max returnable: $maxQty pcs',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.secondaryAccent,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                        if (canUseStrips)
                                          _buildReturnStepperRow(
                                            label: 'Strips',
                                            value: currentStrips,
                                            minusEnabled: currentStrips > 0,
                                            plusEnabled: totalRequestedPcs +
                                                    pcsPerStrip <=
                                                maxQty,
                                            onMinus: () {
                                              if (currentStrips > 0) {
                                                setState(() {
                                                  returnStrips[sale.id] =
                                                      currentStrips - 1;
                                                });
                                              }
                                            },
                                            onPlus: () {
                                              if (totalRequestedPcs +
                                                      pcsPerStrip <=
                                                  maxQty) {
                                                setState(() {
                                                  returnStrips[sale.id] =
                                                      currentStrips + 1;
                                                });
                                              }
                                            },
                                          ),
                                        _buildReturnStepperRow(
                                          label: 'Pcs',
                                          value: currentPcs,
                                          minusEnabled: currentPcs > 0,
                                          plusEnabled:
                                              totalRequestedPcs + 1 <= maxQty,
                                          onMinus: () {
                                            if (currentPcs > 0) {
                                              setState(() {
                                                returnPcs[sale.id] =
                                                    currentPcs - 1;
                                              });
                                            }
                                          },
                                          onPlus: () {
                                            if (totalRequestedPcs + 1 <=
                                                maxQty) {
                                              setState(() {
                                                returnPcs[sale.id] =
                                                    currentPcs + 1;
                                              });
                                            }
                                          },
                                        ),
                                        if (totalRequestedPcs > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              'Selected: $totalRequestedPcs pcs',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primaryDark,
                                                fontWeight: FontWeight.w600,
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
                          ColoredBox(
                            color: AppColors.white,
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ElevatedButton(
                                      onPressed: hasReturns
                                          ? () => Navigator.pop(ctx, true)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Confirm Return',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        side: const BorderSide(
                                          color: AppColors.divider,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: AppColors.secondaryAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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

        // Filter & Sort Row
        Padding(
          padding: ResponsiveHelper.screenPadding(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const controlHeight = 40.0;
              final controlRadius = BorderRadius.circular(8);
              final hasActiveFilter =
                  _startDate != null || _minAmount != null || _maxAmount != null;

              final filterControl = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SizedBox(
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.calendar,
                                  size: 16,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 6),
                                if (hasActiveFilter)
                                  Flexible(
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
                  ),
                  if (hasActiveFilter)
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
              );

              final sortControl = Row(
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
                  Flexible(
                    child: Container(
                      height: controlHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: controlRadius,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ReturnSortOption>(
                          value: _currentSort,
                          icon: const Icon(LucideIcons.chevronDown, size: 16),
                          isExpanded: true,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          onChanged: (ReturnSortOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _currentSort = newValue;
                                _searchInvoice();
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
                              child: Text('Amt: High → Low'),
                            ),
                            DropdownMenuItem(
                              value: ReturnSortOption.amountLowToHigh,
                              child: Text('Amt: Low → High'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                          shape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.fileText,
                              color: AppColors.primaryDark,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            invoiceStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${salesForInvoice.first.date.day}/${salesForInvoice.first.date.month}/${salesForInvoice.first.date.year} • ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                                const TakaSymbol(
                                  size: 12,
                                  color: AppColors.secondaryAccent,
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
                                    fontSize: 12,
                                    color: AppColors.secondaryAccent,
                                  ),
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
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            _loadInvoiceIntoCart(
                                          salesForInvoice,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryDark,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isCompact ? 10 : 14,
                                            vertical: isCompact ? 6 : 8,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: isCompact
                                              ? VisualDensity.compact
                                              : VisualDensity.standard,
                                          side: const BorderSide(
                                            color: AppColors.divider,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Change',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _processInvoiceReturn(
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
                                          style: const TextStyle(
                                            color: AppColors.white,
                                          ),
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
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
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
                                              'Batch: ${sale.batchNumber}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.secondaryAccent,
                                              ),
                                            ),
                                          if (sale.effectiveQuantity <= 0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                'Fully returned',
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
                                            ? 'Qty: ${sale.effectiveQuantity}\n(Ret: ${sale.returnedQuantity})'
                                            : 'Qty: ${sale.effectiveQuantity}',
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
                                        mainAxisAlignment: MainAxisAlignment.end,
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
