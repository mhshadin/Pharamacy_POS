import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../../models/stock_batch.dart';
import '../scanner_screen.dart';

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
  late TextEditingController _priceStripCtrl;
  late TextEditingController _pricePcCtrl;
  late TextEditingController _pcsPerStripCtrl;
  late TextEditingController _lowStockWarningCtrl; // New field
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
    _lowStockWarningCtrl = TextEditingController(
      text: (widget.product.minStockLevel / widget.product.stripsPerBox)
          .toStringAsFixed(0),
    );
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoadingBatches = true);
    final batches = await context.read<AdminProvider>().getBatchesForProduct(
      widget.product.id,
    );
    if (!mounted) return;
    setState(() {
      _batches = batches;
      _isLoadingBatches = false;
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
    _priceStripCtrl.dispose();
    _pricePcCtrl.dispose();
    _pcsPerStripCtrl.dispose();
    _lowStockWarningCtrl.dispose();
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

    final showSupplierInfo = context.read<AdminProvider>().showSupplierInfo;
    int pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
    if (pps <= 0) pps = 10;

    final updatedProduct = Product(
      id: widget.product.id,
      name: _nameCtrl.text.trim(),
      generic: _genericCtrl.text.trim(),
      priceStrip: double.tryParse(_priceStripCtrl.text) ?? 0,
      pricePc: double.tryParse(_pricePcCtrl.text) ?? 0,
      pcsPerStrip: pps,
      stockStrips: 0,
      stockPcs: 0,
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      expiryDate: _selectedExpiryDate,
      minStockLevel:
          (int.tryParse(_lowStockWarningCtrl.text) ??
              context.read<AdminProvider>().lowStockThreshold) *
          pps,
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
    );

    // Update product info
    await context.read<AdminProvider>().updateProduct(updatedProduct);

    if (!mounted) return;
    await context.read<POSProvider>().loadProducts();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: const [
            Icon(LucideIcons.checkCircle2, color: AppColors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Product updated successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final showSupplierInfo = context.watch<AdminProvider>().showSupplierInfo;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          'Edit: ${widget.product.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.edit3,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Product Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _nameCtrl,
                        label: 'Product Name',
                        icon: LucideIcons.pill,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _genericCtrl,
                        label: 'Generic / Description',
                        icon: LucideIcons.fileText,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _companyCtrl,
                        label: 'Company Name (optional)',
                        icon: LucideIcons.building2,
                      ),
                      const SizedBox(height: 12),
                      _buildMedTypeDropdown(),
                      if (showSupplierInfo) ...[
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _supplierNameCtrl,
                          label: 'Supplier Name (optional)',
                          icon: LucideIcons.user,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _supplierPhoneCtrl,
                          label: 'Supplier Phone (optional)',
                          icon: LucideIcons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scanButton = SizedBox(
                            height: 58,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final scannedCode =
                                    await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ScannerScreen(),
                                      ),
                                    );
                                if (!mounted) return;
                                if (scannedCode != null &&
                                    scannedCode.isNotEmpty) {
                                  setState(() {
                                    _barcodeCtrl.text = scannedCode;
                                  });
                                }
                              },
                              icon: const Icon(
                                LucideIcons.scan,
                                color: AppColors.white,
                                size: 20,
                              ),
                              label: const Text(
                                'Scan',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          );
                          final barcodeField = _buildField(
                            controller: _barcodeCtrl,
                            label: 'Barcode (optional)',
                            icon: LucideIcons.scanLine,
                            keyboardType: TextInputType.number,
                          );
                          if (constraints.maxWidth < 380) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                barcodeField,
                                const SizedBox(height: 12),
                                scanButton,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: barcodeField),
                              const SizedBox(width: 12),
                              Expanded(flex: 4, child: scanButton),
                            ],
                          );
                        },
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
                            label: 'Expiry Date (optional)',
                            icon: LucideIcons.calendar,
                            keyboardType: TextInputType.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            ResponsiveHelper.responsiveRow(
                          constraints: constraints,
                          left: _buildField(
                            controller: _priceStripCtrl,
                            label: 'Price / Strip',
                            icon: LucideIcons.dollarSign,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                            onChanged: (val) {
                              if (val.isEmpty) return;
                              final stripPrice = double.tryParse(val);
                              final pps =
                                  int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                              if (stripPrice != null && pps > 0) {
                                _pricePcCtrl.text = (stripPrice / pps)
                                    .toStringAsFixed(2);
                              }
                            },
                          ),
                          right: _buildField(
                            controller: _pricePcCtrl,
                            label: 'Price / Pc',
                            icon: LucideIcons.dollarSign,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                            onChanged: (val) {
                              if (val.isEmpty) return;
                              final pcPrice = double.tryParse(val);
                              final pps =
                                  int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                              if (pcPrice != null && pps > 0) {
                                _priceStripCtrl.text = (pcPrice * pps)
                                    .toStringAsFixed(2);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _pcsPerStripCtrl,
                        label: 'Pieces per Strip',
                        icon: LucideIcons.boxes,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                        onChanged: (val) {
                          if (val.isEmpty) return;
                          final pps = int.tryParse(val) ?? 10;
                          if (pps > 0) {
                            final stripP = double.tryParse(
                              _priceStripCtrl.text,
                            );
                            if (stripP != null) {
                              _pricePcCtrl.text = (stripP / pps)
                                  .toStringAsFixed(2);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _lowStockWarningCtrl,
                        label: 'Low Stock Warning (Box)',
                        icon: LucideIcons.alertTriangle,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      // ─── ACTIVE BATCHES SECTION ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Batches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      if (_isLoadingBatches)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_batches == null || _batches!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No active batches. Stock is 0.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _batches!.length,
                          itemBuilder: (context, index) {
                            final batch = _batches![index];
                            final isExpired = batch.isExpired;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isExpired
                                      ? AppColors.error
                                      : AppColors.divider,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Batch: ${batch.batchNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Exp: ${batch.expiryDate.year}-${batch.expiryDate.month.toString().padLeft(2, '0')}-${batch.expiryDate.day.toString().padLeft(2, '0')}",
                                        style: TextStyle(
                                          color: isExpired
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${batch.remainingPieces} pcs',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      if (widget.product.pcsPerStrip > 0)
                                        Text(
                                          '(${batch.remainingPieces ~/ widget.product.pcsPerStrip} str + ${batch.remainingPieces % widget.product.pcsPerStrip})',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(
                            LucideIcons.save,
                            color: AppColors.white,
                          ),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.secondaryAccent,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppColors.secondaryAccent, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.secondaryAccent,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.secondaryAccent,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
      ),
    );
  }

  Widget _buildMedTypeDropdown() {
    final admin = context.watch<AdminProvider>();
    return DropdownButtonFormField<String>(
      initialValue: _selectedMedType,
      decoration: InputDecoration(
        labelText: 'Medicine Type',
        labelStyle: const TextStyle(
          color: AppColors.secondaryAccent,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(LucideIcons.layers, color: AppColors.secondaryAccent, size: 20),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.secondaryAccent, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.secondaryAccent, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
      ),
      items: admin.medicineTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(
            type,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedMedType = val);
      },
    );
  }
}
