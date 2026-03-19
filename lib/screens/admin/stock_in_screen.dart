import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pharmacy_pos/screens/admin/bulk_import_screen.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../scanner_screen.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _nameCtrl;
  TextEditingController? _genericCtrl;
  TextEditingController? _companyCtrl;
  final _barcodeCtrl = TextEditingController();
  final _priceBoxCtrl = TextEditingController();
  final _priceStripCtrl = TextEditingController();
  final _pricePcCtrl = TextEditingController();
  final _stripsPerBoxCtrl = TextEditingController(text: '10');
  final _pcsPerStripCtrl = TextEditingController(text: '10');
  final _stockBoxesCtrl = TextEditingController();
  final _stockStripsCtrl = TextEditingController();
  final _stockPcsCtrl = TextEditingController();
  final _lowStockWarningCtrl = TextEditingController(); // New field
  final _batchCtrl = TextEditingController();
  TextEditingController? _supplierNameCtrl;
  final _supplierPhoneCtrl = TextEditingController();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final admin = context.read<AdminProvider>();
        setState(() {
          _lowStockWarningCtrl.text = admin.lowStockThreshold.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl?.dispose();
    _genericCtrl?.dispose();
    _companyCtrl?.dispose();
    _barcodeCtrl.dispose();
    _priceBoxCtrl.dispose();
    _priceStripCtrl.dispose();
    _pricePcCtrl.dispose();
    _stripsPerBoxCtrl.dispose();
    _pcsPerStripCtrl.dispose();
    _stockBoxesCtrl.dispose();
    _stockStripsCtrl.dispose();
    _stockPcsCtrl.dispose();
    _lowStockWarningCtrl.dispose();
    _batchCtrl.dispose();
    _supplierNameCtrl?.dispose();
    _supplierPhoneCtrl.dispose();
    super.dispose();
  }

  void _loadProductInfo(Product selection) {
    setState(() {
      _nameCtrl?.text = selection.name;
      _genericCtrl?.text = selection.generic;
      _companyCtrl?.text = selection.companyName ?? '';
      _barcodeCtrl.text = selection.barcode ?? '';
      _priceBoxCtrl.text = selection.priceBox.toStringAsFixed(2);
      _priceStripCtrl.text = selection.priceStrip.toStringAsFixed(2);
      _pricePcCtrl.text = selection.pricePc.toStringAsFixed(2);
      _stripsPerBoxCtrl.text = selection.stripsPerBox.toString();
      _pcsPerStripCtrl.text = selection.pcsPerStrip.toString();
      _lowStockWarningCtrl.text =
          (selection.minStockLevel / selection.stripsPerBox).toStringAsFixed(0);
      _supplierNameCtrl?.text = selection.supplierName ?? '';
      _supplierPhoneCtrl.text = selection.supplierPhone ?? '';
    });
  }

  void _pickExpiryDate({bool forDialog = false}) async {
    final admin = context.read<AdminProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(
        Duration(days: admin.expiryDelayMonths * 30),
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
      if (forDialog) {
        // managed inside dialog directly
      } else {
        setState(() => _expiryDate = picked);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date for trackable stock.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    int boxesInput = int.tryParse(_stockBoxesCtrl.text) ?? 0;
    int stripsInput = int.tryParse(_stockStripsCtrl.text) ?? 0;
    int pcsInput = int.tryParse(_stockPcsCtrl.text) ?? 0;
    int spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
    int pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
    if (spb <= 0) spb = 1;
    if (pps <= 0) pps = 10;

    // Preference hierarchy for total calculation: Pcs > Strips > Boxes
    if (_stockPcsCtrl.text.isEmpty) {
      if (_stockStripsCtrl.text.isNotEmpty) {
        pcsInput = stripsInput * pps;
      } else if (_stockBoxesCtrl.text.isNotEmpty) {
        pcsInput = boxesInput * spb * pps;
      }
    }

    // Since Strips and Pcs fields auto-update to represent the EXACT SAME total amount,
    // we use pcsInput as the definitive total.
    final totalPcs = pcsInput;
    final finalStrips = totalPcs ~/ pps;
    final finalPcs = totalPcs % pps;

    final productName = _nameCtrl?.text.trim() ?? '';
    if (productName.isEmpty) return;

    final allProducts = context.read<AdminProvider>().allProducts;
    final existingProduct = allProducts
        .where((p) => p.name.toLowerCase() == productName.toLowerCase())
        .firstOrNull;

    try {
      if (existingProduct != null) {
        final updatedProduct = Product(
          id: existingProduct.id,
          name: existingProduct.name,
          generic: _genericCtrl?.text.trim() ?? '',
          priceBox: double.tryParse(_priceBoxCtrl.text) ?? 0,
          priceStrip: double.tryParse(_priceStripCtrl.text) ?? 0,
          pricePc: double.tryParse(_pricePcCtrl.text) ?? 0,
          stripsPerBox: spb,
          pcsPerStrip: pps,
          stockStrips: existingProduct.stockStrips,
          stockPcs: existingProduct.stockPcs,
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          expiryDate: _expiryDate,
          minStockLevel:
              (int.tryParse(_lowStockWarningCtrl.text) ??
                  context.read<AdminProvider>().lowStockThreshold) *
              spb,
          companyName: _companyCtrl?.text.trim().isEmpty ?? true
              ? null
              : _companyCtrl?.text.trim(),
          supplierName: _supplierNameCtrl?.text.trim().isEmpty ?? true
              ? null
              : _supplierNameCtrl?.text.trim(),
          supplierPhone: _supplierPhoneCtrl.text.trim().isEmpty
              ? null
              : _supplierPhoneCtrl.text.trim(),
        );
        await context.read<AdminProvider>().updateProduct(updatedProduct);
        if (!mounted) return;
        if (finalStrips > 0 || finalPcs > 0) {
          await context.read<AdminProvider>().addBatch(
            productId: updatedProduct.id,
            batchNumber: _batchCtrl.text.trim(),
            expiryDate: _expiryDate!,
            strips: finalStrips,
            pcs: finalPcs,
            pcsPerStrip: pps,
          );
        }
      } else {
        final newProduct = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: productName,
          generic: _genericCtrl?.text.trim() ?? '',
          priceBox: double.tryParse(_priceBoxCtrl.text) ?? 0,
          priceStrip: double.tryParse(_priceStripCtrl.text) ?? 0,
          pricePc: double.tryParse(_pricePcCtrl.text) ?? 0,
          stripsPerBox: spb,
          pcsPerStrip: pps,
          stockStrips: finalStrips,
          stockPcs: finalPcs,
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          expiryDate: _expiryDate,
          minStockLevel:
              (int.tryParse(_lowStockWarningCtrl.text) ??
                  context.read<AdminProvider>().lowStockThreshold) *
              spb,
          companyName: _companyCtrl?.text.trim().isEmpty ?? true
              ? null
              : _companyCtrl?.text.trim(),
          supplierName: _supplierNameCtrl?.text.trim().isEmpty ?? true
              ? null
              : _supplierNameCtrl?.text.trim(),
          supplierPhone: _supplierPhoneCtrl.text.trim().isEmpty
              ? null
              : _supplierPhoneCtrl.text.trim(),
        );

        await context.read<AdminProvider>().addProduct(
          newProduct,
          initialBatchNumber: _batchCtrl.text.trim(),
        );
      }

      // Refresh products so POS screen picks up the new product
      if (mounted) {
        await context.read<POSProvider>().loadProducts();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save product. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Clear form
    _nameCtrl?.clear();
    _genericCtrl?.clear();
    _companyCtrl?.clear();
    _barcodeCtrl.clear();
    _priceBoxCtrl.clear();
    _priceStripCtrl.clear();
    _pricePcCtrl.clear();
    _stripsPerBoxCtrl.text = '1';
    _pcsPerStripCtrl.text = '10';
    _stockBoxesCtrl.clear();
    _stockStripsCtrl.clear();
    _stockPcsCtrl.clear();
    if (mounted) {
      _lowStockWarningCtrl.text = context
          .read<AdminProvider>()
          .lowStockThreshold
          .toString();
    }
    _batchCtrl.clear();
    _supplierNameCtrl?.clear();
    _supplierPhoneCtrl.clear();
    setState(() => _expiryDate = null);

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
              'Product added successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build visually distinct section containers
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                'Add New Product',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),

            // SECTION 1: GENERAL INFORMATION
            _buildSection(
              title: 'General Information',
              icon: LucideIcons.info,
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<Product>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.trim().isEmpty) {
                            return const Iterable<Product>.empty();
                          }
                          final lowerQuery = textEditingValue.text
                              .toLowerCase();
                          return context
                              .read<AdminProvider>()
                              .allProducts
                              .where((p) {
                                return p.name.toLowerCase().contains(
                                      lowerQuery,
                                    ) ||
                                    p.generic.toLowerCase().contains(
                                      lowerQuery,
                                    );
                              });
                        },
                        displayStringForOption: (Product option) => option.name,
                        onSelected: _loadProductInfo,
                        fieldViewBuilder:
                            (
                              context,
                              controller,
                              focusNode,
                              onEditingComplete,
                            ) {
                              _nameCtrl = controller;
                              return _buildField(
                                controller: controller,
                                label: 'Product Name',
                                icon: LucideIcons.pill,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final Product option = options
                                            .elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              option.name,
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.trim().isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          final lowerQuery = textEditingValue.text
                              .toLowerCase();
                          final allGenerics = context
                              .read<AdminProvider>()
                              .allProducts
                              .map((p) => p.generic)
                              .where((g) => g.isNotEmpty)
                              .toSet();
                          return allGenerics.where((g) {
                            return g.toLowerCase().contains(lowerQuery);
                          });
                        },
                        onSelected: (String selection) {
                          _genericCtrl?.text = selection;
                        },
                        fieldViewBuilder:
                            (
                              context,
                              controller,
                              focusNode,
                              onEditingComplete,
                            ) {
                              _genericCtrl = controller;
                              return _buildField(
                                controller: controller,
                                label: 'Generic / Description',
                                icon: LucideIcons.fileText,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final String option = options.elementAt(
                                          index,
                                        );
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              option,
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.trim().isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          final lowerQuery = textEditingValue.text.toLowerCase();
                          final allCompanies = context
                              .read<AdminProvider>()
                              .allProducts
                              .map((p) => p.companyName)
                              .where((c) => c != null && c.isNotEmpty)
                              .cast<String>()
                              .toSet();
                          return allCompanies.where(
                            (c) => c.toLowerCase().contains(lowerQuery),
                          );
                        },
                        onSelected: (String selection) {
                          _companyCtrl?.text = selection;
                        },
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onEditingComplete,
                        ) {
                          _companyCtrl = controller;
                          return _buildField(
                            controller: controller,
                            label: 'Company Name (optional)',
                            icon: LucideIcons.building2,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 200,
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          option,
                                          style: const TextStyle(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildField(
                          controller: _barcodeCtrl,
                          label: 'Barcode (optional)',
                          icon: LucideIcons.scanLine,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 58,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final scannedCode = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ScannerScreen(),
                                ),
                              );
                              if (!context.mounted) return;
                              if (scannedCode != null &&
                                  scannedCode.isNotEmpty) {
                                setState(() {
                                  _barcodeCtrl.text = scannedCode;
                                });
                                // Auto-load if product exists
                                final admin = context.read<AdminProvider>();
                                final existing = admin.allProducts
                                    .where((p) => p.barcode == scannedCode)
                                    .firstOrNull;
                                if (existing != null) {
                                  _loadProductInfo(existing);
                                }
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // SECTION 2: PRICING & PACKAGING
            _buildSection(
              title: 'Pricing & Packaging',
              icon: LucideIcons.circleDollarSign,
              child: Column(
                children: [
                  _buildField(
                    controller: _stripsPerBoxCtrl,
                    label: 'Strips per Box',
                    icon: LucideIcons.package,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                    onChanged: (val) {
                      if (val.isEmpty) return;
                      final spb = int.tryParse(val) ?? 1;
                      if (spb > 0) {
                        final boxP = double.tryParse(_priceBoxCtrl.text);
                        if (boxP != null) {
                          _priceStripCtrl.text = (boxP / spb).toStringAsFixed(
                            2,
                          );
                          final stripP = double.tryParse(_priceStripCtrl.text);
                          final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                          if (stripP != null && pps > 0) {
                            _pricePcCtrl.text = (stripP / pps).toStringAsFixed(
                              2,
                            );
                          }
                        }
                        final boxes = int.tryParse(_stockBoxesCtrl.text);
                        if (boxes != null) {
                          _stockStripsCtrl.text = (boxes * spb).toString();
                          final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                          _stockPcsCtrl.text = (boxes * spb * pps).toString();
                        }
                      }
                    },
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
                        final stripP = double.tryParse(_priceStripCtrl.text);
                        if (stripP != null) {
                          _pricePcCtrl.text = (stripP / pps).toStringAsFixed(2);
                        }
                        final strips = int.tryParse(_stockStripsCtrl.text);
                        if (strips != null) {
                          _stockPcsCtrl.text = (strips * pps).toString();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _priceBoxCtrl,
                          label: 'Price / Box',
                          icon: LucideIcons.shoppingCart,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            if (val.isEmpty) return;
                            final boxPrice = double.tryParse(val);
                            final spb =
                                int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                            final pps =
                                int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                            if (boxPrice != null && spb > 0) {
                              final stripP = boxPrice / spb;
                              _priceStripCtrl.text = stripP.toStringAsFixed(2);
                              if (pps > 0) {
                                _pricePcCtrl.text = (stripP / pps)
                                    .toStringAsFixed(2);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
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
                            final spb =
                                int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                            if (stripPrice != null) {
                              if (pps > 0) {
                                _pricePcCtrl.text = (stripPrice / pps)
                                    .toStringAsFixed(2);
                              }
                              _priceBoxCtrl.text = (stripPrice * spb)
                                  .toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _pricePcCtrl,
                    label: 'Price / Pc',
                    icon: LucideIcons.dollarSign,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                    onChanged: (val) {
                      if (val.isEmpty) return;
                      final pcPrice = double.tryParse(val);
                      final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                      final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                      if (pcPrice != null && pps > 0) {
                        final stripP = pcPrice * pps;
                        _priceStripCtrl.text = stripP.toStringAsFixed(2);
                        _priceBoxCtrl.text = (stripP * spb).toStringAsFixed(2);
                      }
                    },
                  ),
                ],
              ),
            ),

            // SECTION 3: INVENTORY TRACKING
            _buildSection(
              title: 'Inventory & Tracking',
              icon: LucideIcons.clipboardList,
              child: Column(
                children: [
                  _buildField(
                    controller: _stockBoxesCtrl,
                    label: 'Stock (Boxes)',
                    icon: LucideIcons.box,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (val.isEmpty) return;
                      final boxes = int.tryParse(val);
                      final spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                      final pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                      if (boxes != null && spb > 0) {
                        _stockStripsCtrl.text = (boxes * spb).toString();
                        if (pps > 0) {
                          _stockPcsCtrl.text = (boxes * spb * pps).toString();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _stockStripsCtrl,
                          label: 'Stock (Strips)',
                          icon: LucideIcons.layers,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            if (val.isEmpty) return;
                            final strips = int.tryParse(val);
                            final pps =
                                int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                            final spb =
                                int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                            if (strips != null && pps > 0) {
                              _stockPcsCtrl.text = (strips * pps).toString();
                              if (spb > 0) {
                                _stockBoxesCtrl.text = (strips ~/ spb)
                                    .toString();
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _stockPcsCtrl,
                          label: 'Stock (Pcs)',
                          icon: LucideIcons.layers,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            if (val.isEmpty) return;
                            final pcs = int.tryParse(val);
                            final pps =
                                int.tryParse(_pcsPerStripCtrl.text) ?? 10;
                            final spb =
                                int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
                            if (pcs != null && pps > 0) {
                              final strips = pcs ~/ pps;
                              _stockStripsCtrl.text = strips.toString();
                              if (spb > 0) {
                                _stockBoxesCtrl.text = (strips ~/ spb)
                                    .toString();
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _lowStockWarningCtrl,
                    label: 'Low Stock Warning (Box)',
                    icon: LucideIcons.alertTriangle,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _batchCtrl,
                          label: 'Batch No (optional)',
                          icon: LucideIcons.hash,
                          keyboardType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickExpiryDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.secondaryAccent,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.surfaceLight,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendar,
                                  color: AppColors.secondaryAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _expiryDate != null
                                        ? 'Exp: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                        : 'Select Expiry*',
                                    style: TextStyle(
                                      color: _expiryDate != null
                                          ? AppColors.primaryDark
                                          : AppColors.secondaryAccent,
                                      fontWeight: FontWeight.w600,
                                      overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),

            // SECTION 4: SUPPLIER INFORMATION
            if (context.watch<AdminProvider>().showSupplierInfo)
              _buildSection(
                title: 'Supplier Information',
                icon: LucideIcons.truck,
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.trim().isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final lowerQuery = textEditingValue.text
                                .toLowerCase();
                            final allSuppliers = context
                                .read<AdminProvider>()
                                .allProducts
                                .map((p) => p.supplierName)
                                .where((s) => s != null && s.isNotEmpty)
                                .cast<String>()
                                .toSet();
                            return allSuppliers.where(
                              (s) => s.toLowerCase().contains(lowerQuery),
                            );
                          },
                          onSelected: (String selection) {
                            _supplierNameCtrl?.text = selection;
                            final productWithSupplier = context
                                .read<AdminProvider>()
                                .allProducts
                                .where((p) => p.supplierName == selection)
                                .firstOrNull;
                            if (productWithSupplier != null &&
                                productWithSupplier.supplierPhone != null) {
                              _supplierPhoneCtrl.text =
                                  productWithSupplier.supplierPhone!;
                            }
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onEditingComplete,
                              ) {
                                _supplierNameCtrl = controller;
                                return _buildField(
                                  controller: controller,
                                  label: 'Supplier Name',
                                  icon: LucideIcons.user,
                                  focusNode: focusNode,
                                  onEditingComplete: onEditingComplete,
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final String option = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                16.0,
                                              ),
                                              child: Text(
                                                option,
                                                style: const TextStyle(
                                                  color: AppColors.primaryDark,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _supplierPhoneCtrl,
                      label: 'Supplier Phone',
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),

            // SUBMIT BUTTON
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(LucideIcons.plus, color: AppColors.white),
                label: const Text(
                  'Add Product',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // --- NEW BULK UPLOAD BUTTON ---
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BulkImportScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  LucideIcons.fileSpreadsheet,
                  color: AppColors.primaryDark,
                ),
                label: const Text(
                  'Bulk Import CSV',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(
                    color: AppColors.primaryDark,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // QUICK STOCK UPDATE SECTION
            Container(
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
                          LucideIcons.refreshCw,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Quick Stock Update',
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
                  Builder(
                    builder: (ctx) {
                      final sortedProducts = List<Product>.from(
                        ctx.watch<POSProvider>().products,
                      );
                      final admin = ctx.watch<AdminProvider>();
                      sortedProducts.sort((a, b) {
                        if (admin.isProductLowStock(a) &&
                            !admin.isProductLowStock(b)) {
                          return -1;
                        }
                        if (!admin.isProductLowStock(a) &&
                            admin.isProductLowStock(b)) {
                          return 1;
                        }
                        return a.name.compareTo(b.name);
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedProducts.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, idx) {
                          final product = sortedProducts[idx];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryAccent.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.pill,
                                color: AppColors.secondaryAccent,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${product.stockStrips} strips • ${product.totalPieces} pcs',
                              style: const TextStyle(
                                color: AppColors.secondaryAccent,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: admin.isProductLowStock(product)
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                admin.isProductLowStock(product) ? 'LOW' : 'OK',
                                style: TextStyle(
                                  color: admin.isProductLowStock(product)
                                      ? AppColors.error
                                      : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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
    FocusNode? focusNode,
    VoidCallback? onEditingComplete,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onEditingComplete: onEditingComplete,
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
}
