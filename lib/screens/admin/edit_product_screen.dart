import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/product.dart';
import '../../models/stock_batch.dart';
import '../../utils/med_type_units.dart';
import '../scanner_screen.dart';
import '../../services/mobile_scanner_bridge.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _genericCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _supplierNameCtrl;
  late TextEditingController _supplierPhoneCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _priceBoxCtrl;
  late TextEditingController _priceStripCtrl;
  late TextEditingController _pricePcCtrl;
  late TextEditingController _pcsPerStripCtrl;
  late TextEditingController _stripsPerBoxCtrl;
  late TextEditingController _buyingPriceBoxCtrl;
  late TextEditingController _buyingPriceStripCtrl;
  late TextEditingController _lowStockWarningCtrl;
  late TextEditingController _powerCtrl;
  DateTime? _selectedExpiryDate;
  String? _selectedMedType;

  List<StockBatch>? _batches;
  bool _isLoadingBatches = true;

  @override
  void initState() {
    super.initState();
    _selectedExpiryDate = widget.product.expiryDate;
    _selectedMedType = widget.product.medType ?? 'Tablet';
    _nameCtrl = TextEditingController(text: widget.product.name);
    _genericCtrl = TextEditingController(text: widget.product.generic);
    _companyCtrl = TextEditingController(text: widget.product.companyName ?? '');
    _supplierNameCtrl =
        TextEditingController(text: widget.product.supplierName ?? '');
    _supplierPhoneCtrl =
        TextEditingController(text: widget.product.supplierPhone ?? '');
    _powerCtrl = TextEditingController(text: widget.product.power ?? '');
    _barcodeCtrl = TextEditingController(text: widget.product.barcode ?? '');
    _priceStripCtrl = TextEditingController(
      text: widget.product.priceStrip.toStringAsFixed(2),
    );
    _pricePcCtrl = TextEditingController(
      text: widget.product.pricePc.toStringAsFixed(2),
    );
    _pcsPerStripCtrl = TextEditingController(
      text: widget.product.pcsPerStrip.toString(),
    );
    _stripsPerBoxCtrl = TextEditingController(
      text: widget.product.stripsPerBox.toString(),
    );
    _priceBoxCtrl = TextEditingController(
      text: (widget.product.priceStrip * widget.product.stripsPerBox)
          .toStringAsFixed(2),
    );
    _buyingPriceBoxCtrl = TextEditingController();
    _buyingPriceStripCtrl = TextEditingController();

    // FIXED: Convert from total pieces correctly back to boxes for the UI display
    int spbInit = widget.product.stripsPerBox > 0 ? widget.product.stripsPerBox : 1;
    int ppsInit = widget.product.pcsPerStrip > 0 ? widget.product.pcsPerStrip : 1;
    int piecesPerBoxInit = spbInit * ppsInit;

    _lowStockWarningCtrl = TextEditingController(
      text: (widget.product.minStockLevel / piecesPerBoxInit).toStringAsFixed(0),
    );

    _loadBatchesAndInitialCost();
  }

  Future<void> _loadBatchesAndInitialCost() async {
    setState(() => _isLoadingBatches = true);
    final admin = context.read<AdminProvider>();

    // Load batches
    final batches = await admin.getBatchesForProduct(widget.product.id);

    // Load latest cost (this is fetched as Cost Per PC)
    final lastCostPerPc = await admin.getLastBatchCostPrice(widget.product.id);

    final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
    final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 1;

    if (!mounted) return;
    setState(() {
      _batches = batches;
      _isLoadingBatches = false;

      // FIXED: Multiply by pcsPerStrip to get the Cost Per Strip, and by stripsPerBox to get Cost Per Box
      final stripCost = lastCostPerPc * pps;
      final boxCost = stripCost * spb;

      _buyingPriceStripCtrl.text = stripCost.toStringAsFixed(2);
      _buyingPriceBoxCtrl.text = boxCost.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _companyCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceBoxCtrl.dispose();
    _priceStripCtrl.dispose();
    _pricePcCtrl.dispose();
    _pcsPerStripCtrl.dispose();
    _stripsPerBoxCtrl.dispose();
    _buyingPriceBoxCtrl.dispose();
    _buyingPriceStripCtrl.dispose();
    _lowStockWarningCtrl.dispose();
    _powerCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: AppColors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedExpiryDate) {
      if (!mounted) return;
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final admin = context.read<AdminProvider>();
    final showSupplierInfo = admin.showSupplierInfo;

    int pps = int.tryParse(_pcsPerStripCtrl.text) ?? 1;
    if (pps <= 0) pps = 1;

    int spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
    if (spb <= 0) spb = 1;

    final newCostStrip = double.tryParse(_buyingPriceStripCtrl.text) ?? 0.0;
    final newCostPerPc = newCostStrip / pps;

    final parsedLowStockBoxes = int.tryParse(_lowStockWarningCtrl.text) ?? admin.lowStockThreshold;
    final computedMinStockLevel = parsedLowStockBoxes * spb * pps;

    final updatedProduct = Product(
      id: widget.product.id,
      name: _nameCtrl.text.trim(),
      generic: _genericCtrl.text.trim(),
      priceStrip: double.tryParse(_priceStripCtrl.text) ?? 0,
      pricePc: double.tryParse(_pricePcCtrl.text) ?? 0,
      priceBox: double.tryParse(_priceBoxCtrl.text) ?? 0,
      pcsPerStrip: pps,
      stripsPerBox: spb,
      stockStrips: 0, // Not updated here
      stockPcs: 0,    // Not updated here
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      expiryDate: _selectedExpiryDate,
      minStockLevel: computedMinStockLevel,
      companyName: _companyCtrl.text.trim().isEmpty
          ? null
          : _companyCtrl.text.trim(),
      supplierName: showSupplierInfo
          ? (_supplierNameCtrl.text.trim().isEmpty
          ? null
          : _supplierNameCtrl.text.trim())
          : widget.product.supplierName,
      supplierPhone: showSupplierInfo
          ? (_supplierPhoneCtrl.text.trim().isEmpty
          ? null
          : _supplierPhoneCtrl.text.trim())
          : widget.product.supplierPhone,
      medType: _selectedMedType,
      power: _powerCtrl.text.trim().isEmpty ? null : _powerCtrl.text.trim(),
      costPricePerPc: newCostPerPc,
    );

    // Active stock batches override product.expiryDate on load; sync them first so the new date sticks.
    if (_selectedExpiryDate != null) {
      await admin.updateActiveBatchesExpiry(widget.product.id, _selectedExpiryDate!);
    }

    // 1. Update product metadata
    await admin.updateProduct(updatedProduct);

    // 2. Update active batches cost if buying price is set
    if (newCostPerPc > 0) {
      await admin.updateProductCostPrice(widget.product.id, newCostPerPc);
    }

    if (!mounted) return;
    await context.read<POSProvider>().loadProducts();

    if (!mounted) return;
    final l10n = context.read<LanguageProvider>().strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.productUpdated,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final showSupplierInfo = context.watch<AdminProvider>().showSupplierInfo;
    final unitLabels = MedTypeUnits.getLabels(_selectedMedType, l10n);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        title: Text(
          l10n.editProductTitle(widget.product.name),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: GENERAL INFO
              _buildSection(
                title: l10n.generalInfo,
                icon: LucideIcons.info,
                child: Column(
                  children: [
                    _buildField(
                      controller: _nameCtrl,
                      label: l10n.productName,
                      icon: LucideIcons.pill,
                      validator: (v) =>
                      v == null || v.isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _genericCtrl,
                      label: l10n.genericDescription,
                      icon: LucideIcons.fileText,
                      validator: (v) =>
                      v == null || v.isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _companyCtrl,
                      label: l10n.companyNameOptional,
                      icon: LucideIcons.building2,
                    ),
                    const SizedBox(height: 12),
                    _buildMedTypeDropdown(l10n),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _powerCtrl,
                      label: '${l10n.powerLabel} (${l10n.powerHint})',
                      icon: LucideIcons.flaskConical,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scanButton = SizedBox(
                          height: 58,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await MobileScannerBridge.beforePushOverlayScanner();
                              String? scannedCode;
                              try {
                                scannedCode = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ScannerScreen(),
                                  ),
                                );
                              } finally {
                                MobileScannerBridge.afterPopOverlayScanner();
                              }
                              if (!mounted) return;
                              if (scannedCode != null &&
                                  scannedCode.isNotEmpty) {
                                final code = scannedCode;
                                setState(() {
                                  _barcodeCtrl.text = code;
                                });
                              }
                            },
                            icon: const Icon(LucideIcons.scan, color: AppColors.white, size: 20),
                            label: Text(l10n.scan,
                                style: const TextStyle(
                                    color: AppColors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        );
                        final barcodeField = _buildField(
                          controller: _barcodeCtrl,
                          label: l10n.barcodeLabelOptional,
                          icon: LucideIcons.scanLine,
                        );
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: barcodeField),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: scanButton,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // SECTION 2: PACKAGING
              _buildSection(
                title: l10n.packaging,
                icon: LucideIcons.package2,
                child: LayoutBuilder(
                  builder: (context, constraints) => ResponsiveHelper.responsiveRow(
                    constraints: constraints,
                    left: _buildField(
                      controller: _stripsPerBoxCtrl,
                      label: unitLabels['unit1'] != null
                          ? '${unitLabels['unit2'] ?? l10n.strips} / ${unitLabels['unit1']}'
                          : l10n.stripsPerBox,
                      icon: LucideIcons.layers,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        if (val.isEmpty) return;
                        final spb = int.tryParse(val) ?? 1;
                        final stripPrice = double.tryParse(_priceStripCtrl.text) ?? 0;
                        final stripCost = double.tryParse(_buyingPriceStripCtrl.text) ?? 0;
                        if (spb > 0) {
                          _priceBoxCtrl.text = (stripPrice * spb).toStringAsFixed(2);
                          _buyingPriceBoxCtrl.text = (stripCost * spb).toStringAsFixed(2);
                        }
                      },
                    ),
                    right: _buildField(
                      controller: _pcsPerStripCtrl,
                      label: unitLabels['unit3'] != null
                          ? '${unitLabels['unit3']} / ${unitLabels['unit2'] ?? l10n.strips}'
                          : l10n.pcsPerStrip,
                      icon: LucideIcons.boxes,
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? l10n.required : null,
                      onChanged: (val) {
                        if (val.isEmpty) return;
                        final pps = int.tryParse(val) ?? 1;
                        final stripPrice = double.tryParse(_priceStripCtrl.text) ?? 0;
                        if (pps > 0) {
                          _pricePcCtrl.text = (stripPrice / pps).toStringAsFixed(2);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // SECTION 3: SELLING PRICE
              _buildSection(
                title: l10n.pricing,
                icon: LucideIcons.circleDollarSign,
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      if (MedTypeUnits.hasUnit1(_selectedMedType))
                        Expanded(
                          child: _buildField(
                            controller: _priceBoxCtrl,
                            label: '${l10n.price} / ${unitLabels['unit1'] ?? l10n.boxes}',
                            icon: LucideIcons.shoppingCart,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              if (val.isEmpty) return;
                              final boxPrice = double.tryParse(val);
                              final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                              if (boxPrice != null && spb > 0) {
                                _priceStripCtrl.text = (boxPrice / spb).toStringAsFixed(2);
                                final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 1;
                                _pricePcCtrl.text = (boxPrice / (spb * pps)).toStringAsFixed(2);
                              }
                            },
                          ),
                        ),
                      if (MedTypeUnits.hasUnit1(_selectedMedType)) const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _priceStripCtrl,
                          label: '${l10n.price} / ${unitLabels['unit2'] ?? l10n.strips}',
                          icon: LucideIcons.dollarSign,
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? l10n.required : null,
                          onChanged: (val) {
                            if (val.isEmpty) return;
                            final stripPrice = double.tryParse(val);
                            final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                            final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 1;
                            if (stripPrice != null) {
                              if (spb > 0) _priceBoxCtrl.text = (stripPrice * spb).toStringAsFixed(2);
                              if (pps > 0) _pricePcCtrl.text = (stripPrice / pps).toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SECTION 4: BUYING PRICE (COST)
              _buildSection(
                title: l10n.buyingPriceSection,
                icon: LucideIcons.tag,
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (MedTypeUnits.hasUnit1(_selectedMedType)) ...[
                          Expanded(
                            child: _buildField(
                              controller: _buyingPriceBoxCtrl,
                              label: '${l10n.price} / ${unitLabels['unit1'] ?? l10n.boxes}',
                              icon: LucideIcons.tag,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                if (val.isEmpty) return;
                                final boxCost = double.tryParse(val);
                                final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                                if (boxCost != null && spb > 0) {
                                  _buyingPriceStripCtrl.text = (boxCost / spb).toStringAsFixed(2);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _buildField(
                            controller: _buyingPriceStripCtrl,
                            label: '${l10n.price} / ${unitLabels['unit2'] ?? l10n.strips}',
                            icon: LucideIcons.tag,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              if (val.isEmpty) return;
                              final stripCost = double.tryParse(val);
                              final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                              if (stripCost != null && spb > 0) {
                                _buyingPriceBoxCtrl.text = (stripCost * spb).toStringAsFixed(2);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Live profit preview: Now listening to both Buying Price and Selling Price
                    AnimatedBuilder(
                      animation: Listenable.merge([_buyingPriceStripCtrl, _priceStripCtrl]),
                      builder: (context, child) {
                        final cost = double.tryParse(_buyingPriceStripCtrl.text) ?? 0.0;
                        final sell = double.tryParse(_priceStripCtrl.text) ?? 0.0;
                        if (cost <= 0 || sell <= 0) return const SizedBox.shrink();
                        final profit = sell - cost;
                        final margin = sell > 0 ? ((profit / sell) * 100).toStringAsFixed(1) : '0.0';
                        final isLoss = profit < 0;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isLoss ? AppColors.error : AppColors.success).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (isLoss ? AppColors.error : AppColors.success).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(isLoss ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                                  size: 16, color: isLoss ? AppColors.error : AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.profitPreview(profit.abs().toStringAsFixed(2), margin, isLoss),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isLoss ? AppColors.error : AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // SECTION 5: STOCK & EXPIRY
              _buildSection(
                title: l10n.inventory,
                icon: LucideIcons.clipboardList,
                child: Column(
                  children: [
                    _buildField(
                      controller: _lowStockWarningCtrl,
                      label: '${l10n.minStockLevel} (${unitLabels['unit1'] ?? unitLabels['unit2'] ?? l10n.boxes})',
                      icon: LucideIcons.alertTriangle,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectExpiryDate(context),
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: _buildField(
                          controller: TextEditingController(
                            text: _selectedExpiryDate != null
                                ? '${_selectedExpiryDate!.year}-${_selectedExpiryDate!.month.toString().padLeft(2, '0')}-${_selectedExpiryDate!.day.toString().padLeft(2, '0')}'
                                : '',
                          ),
                          label: l10n.expiryDateOptional,
                          icon: LucideIcons.calendar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // SECTION 6: SUPPLIER (if enabled)
              if (showSupplierInfo)
                _buildSection(
                  title: l10n.supplierInfo,
                  icon: LucideIcons.truck,
                  child: Column(
                    children: [
                      _buildSupplierAutocomplete(l10n),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _supplierPhoneCtrl,
                        label: l10n.supplierPhoneOptional,
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),

              // SECTION 7: ACTIVE BATCHES
              _buildSection(
                title: l10n.activeBatches,
                icon: LucideIcons.boxes,
                child: _isLoadingBatches
                    ? const Center(child: CircularProgressIndicator())
                    : (_batches == null || _batches!.isEmpty)
                    ? Center(child: Text(l10n.noActiveBatches, style: const TextStyle(color: AppColors.textSecondary)))
                    : Column(
                  children: _batches!.map((batch) {
                    final isExpired = batch.isExpired;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isExpired ? AppColors.error.withValues(alpha: 0.05) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isExpired ? AppColors.error.withValues(alpha: 0.3) : AppColors.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.batchNumber}: ${batch.batchNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.expiresDate(batch.expiryDate),
                                  style: TextStyle(
                                    color: isExpired
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cost: ৳${batch.costPricePerPc.toStringAsFixed(2)}/pc',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  l10n.pcsSuffixCount(batch.remainingPieces),
                                  textAlign: TextAlign.end,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                if (widget.product.pcsPerStrip > 0)
                                  Text(
                                    l10n.batchRemaining(
                                      batch.remainingPieces ~/
                                          widget.product.pcsPerStrip,
                                      batch.remainingPieces %
                                          widget.product.pcsPerStrip,
                                    ),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: Text(
                    l10n.saveChanges,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierAutocomplete(AppStrings l10n) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
        final lowerQuery = textEditingValue.text.toLowerCase();
        final suppliers = context
            .read<AdminProvider>()
            .allProducts
            .map((p) => p.supplierName)
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toSet();
        return suppliers.where((s) => s.toLowerCase().contains(lowerQuery));
      },
      onSelected: (String selection) {
        _supplierNameCtrl.text = selection;
        final productWithSupplier = context
            .read<AdminProvider>()
            .allProducts
            .firstWhere((p) => p.supplierName == selection);
        if (productWithSupplier.supplierPhone != null) {
          _supplierPhoneCtrl.text = productWithSupplier.supplierPhone!;
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (controller.text.isEmpty && _supplierNameCtrl.text.isNotEmpty) {
          controller.text = _supplierNameCtrl.text;
        }
        controller.addListener(() {
          _supplierNameCtrl.text = controller.text;
        });
        return _buildField(
          controller: controller,
          label: l10n.supplierNameOptional,
          icon: LucideIcons.user,
          focusNode: focusNode,
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.secondaryAccent, fontWeight: FontWeight.w600, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.secondaryAccent, size: 18),
        filled: true,
        fillColor: AppColors.surfaceLight,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryDark, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      ),
    );
  }

  Widget _buildMedTypeDropdown(AppStrings l10n) {
    final admin = context.watch<AdminProvider>();
    return DropdownButtonFormField<String>(
      initialValue: _selectedMedType,
      style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 15),
      decoration: InputDecoration(
        labelText: l10n.medicineType,
        labelStyle: const TextStyle(color: AppColors.secondaryAccent, fontWeight: FontWeight.w600, fontSize: 13),
        prefixIcon: const Icon(LucideIcons.shapes, color: AppColors.secondaryAccent, size: 18),
        filled: true,
        fillColor: AppColors.surfaceLight,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryDark, width: 2)),
      ),
      items: admin.medicineTypes.map((type) {
        return DropdownMenuItem(value: type, child: Text(type));
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedMedType = val);
      },
    );
  }
}