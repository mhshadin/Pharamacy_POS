import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pharmacy_pos/screens/admin/bulk_import_screen.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';
import '../../providers/language_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/product.dart';
import '../../utils/med_type_icons.dart';
import '../../l10n/app_strings.dart';
import '../scanner_screen.dart';
import '../../services/mobile_scanner_bridge.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();
  int _currentStep = 0;
  TextEditingController? _nameCtrl;
  TextEditingController? _genericCtrl;
  TextEditingController? _companyCtrl;
  final _barcodeCtrl = TextEditingController();
  final _priceBoxCtrl = TextEditingController();
  final _priceStripCtrl = TextEditingController();
  final _buyingPriceBoxCtrl = TextEditingController();
  final _buyingPriceStripCtrl = TextEditingController();
  final _stripsPerBoxCtrl = TextEditingController(text: '10');
  final _pcsPerStripCtrl = TextEditingController(text: '10');
  final _stockBoxesCtrl = TextEditingController();
  final _stockStripsCtrl = TextEditingController();
  final _lowStockWarningCtrl = TextEditingController(); // New field
  final _batchCtrl = TextEditingController();
  final _powerCtrl = TextEditingController();
  TextEditingController? _supplierNameCtrl;
  final _supplierPhoneCtrl = TextEditingController();
  DateTime? _expiryDate;
  String? _selectedMedType = 'Tablet';
  bool? _useStepperOverride;

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
    _buyingPriceBoxCtrl.dispose();
    _buyingPriceStripCtrl.dispose();
    _stripsPerBoxCtrl.dispose();
    _pcsPerStripCtrl.dispose();
    _stockBoxesCtrl.dispose();
    _stockStripsCtrl.dispose();
    _lowStockWarningCtrl.dispose();
    _batchCtrl.dispose();
    _powerCtrl.dispose();
    _supplierNameCtrl?.dispose();
    _supplierPhoneCtrl.dispose();
    super.dispose();
  }

  void _loadProductInfo(Product selection) {
    final pps = selection.pcsPerStrip > 0 ? selection.pcsPerStrip : 10;
    final spb = selection.stripsPerBox > 0 ? selection.stripsPerBox : 1;
    final stripCost = selection.costPricePerPc * pps;
    final boxCost = stripCost * spb;

    setState(() {
      _nameCtrl?.text = selection.name;
      _genericCtrl?.text = selection.generic;
      _companyCtrl?.text = selection.companyName ?? '';
      _barcodeCtrl.text = selection.barcode ?? '';
      _priceBoxCtrl.text = selection.priceBox.toStringAsFixed(2);
      _priceStripCtrl.text = selection.priceStrip.toStringAsFixed(2);
      _buyingPriceBoxCtrl.text = boxCost.toStringAsFixed(2);
      _buyingPriceStripCtrl.text = stripCost.toStringAsFixed(2);
      _stripsPerBoxCtrl.text = selection.stripsPerBox.toString();
      _pcsPerStripCtrl.text = selection.pcsPerStrip.toString();
      _lowStockWarningCtrl.text =
          (selection.minStockLevel / selection.stripsPerBox).toStringAsFixed(0);
      _supplierNameCtrl?.text = selection.supplierName ?? '';
      _supplierPhoneCtrl.text = selection.supplierPhone ?? '';
      _selectedMedType = selection.medType ?? 'Tablet';
      _powerCtrl.text = selection.power ?? '';
    });
  }

  String _normalizedPower(String? value) => value?.trim().toLowerCase() ?? '';

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
    if (!_formKeyStep1.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_formKeyStep2.currentState!.validate()) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!_formKeyStep3.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().strings.selectExpiryDate,
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    int spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
    int pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
    if (spb <= 0) spb = 1;
    if (pps <= 0) pps = 10;

    int stripsInput = int.tryParse(_stockStripsCtrl.text) ?? 0;
    int boxesInput = int.tryParse(_stockBoxesCtrl.text) ?? 0;
    int pcsInput = 0;
    if (_stockStripsCtrl.text.isNotEmpty) {
      pcsInput = stripsInput * pps;
    } else if (_stockBoxesCtrl.text.isNotEmpty) {
      pcsInput = boxesInput * spb * pps;
    }

    final totalPcs = pcsInput;
    final finalStrips = totalPcs ~/ pps;
    final finalPcs = totalPcs % pps;

    final productName = _nameCtrl?.text.trim() ?? '';
    if (productName.isEmpty) return;
    final powerInput = _powerCtrl.text.trim();
    final normalizedPower = _normalizedPower(powerInput);

    final allProducts = context.read<AdminProvider>().allProducts;
    final existingProduct = allProducts
        .where(
          (p) =>
              p.name.toLowerCase() == productName.toLowerCase() &&
              (p.medType ?? 'Tablet') == _selectedMedType &&
              _normalizedPower(p.power) == normalizedPower,
        )
        .firstOrNull;

    final stripPrice = double.tryParse(_priceStripCtrl.text) ?? 0;
    final pricePc = pps > 0 ? stripPrice / pps : 0.0;

    final costPricePerPc = _buyingPriceStripCtrl.text.isNotEmpty
        ? (double.tryParse(_buyingPriceStripCtrl.text) ?? 0.0) /
              (pps > 0 ? pps : 1)
        : (_buyingPriceBoxCtrl.text.isNotEmpty
              ? (double.tryParse(_buyingPriceBoxCtrl.text) ?? 0.0) /
                    ((spb > 0 ? spb : 1) * (pps > 0 ? pps : 1))
              : 0.0);

    try {
      if (existingProduct != null) {
        final updatedProduct = Product(
          id: existingProduct.id,
          name: existingProduct.name,
          generic: _genericCtrl?.text.trim() ?? '',
          priceBox: double.tryParse(_priceBoxCtrl.text) ?? 0,
          priceStrip: stripPrice,
          pricePc: pricePc,
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
          medType: _selectedMedType,
          power: powerInput.isEmpty ? null : powerInput,
          costPricePerPc: costPricePerPc,
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
            costPricePerPc: costPricePerPc,
          );
        }
      } else {
        final newProduct = Product(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: productName,
          generic: _genericCtrl?.text.trim() ?? '',
          priceBox: double.tryParse(_priceBoxCtrl.text) ?? 0,
          priceStrip: stripPrice,
          pricePc: pricePc,
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
          medType: _selectedMedType,
          power: powerInput.isEmpty ? null : powerInput,
          costPricePerPc: costPricePerPc,
        );

        await context.read<AdminProvider>().addProduct(
          newProduct,
          initialBatchNumber: _batchCtrl.text.trim(),
          costPricePerPc: costPricePerPc,
        );
      }

      // Refresh products so POS screen picks up the new product
      if (mounted) {
        await context.read<POSProvider>().loadProducts();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().strings.failedToSaveProduct,
          ),
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
    _buyingPriceBoxCtrl.clear();
    _buyingPriceStripCtrl.clear();
    _stripsPerBoxCtrl.text = '1';
    _pcsPerStripCtrl.text = '10';
    _stockBoxesCtrl.clear();
    _stockStripsCtrl.clear();
    if (mounted) {
      _lowStockWarningCtrl.text = context
          .read<AdminProvider>()
          .lowStockThreshold
          .toString();
    }
    _batchCtrl.clear();
    _powerCtrl.clear();
    _supplierNameCtrl?.clear();
    _supplierPhoneCtrl.clear();
    setState(() {
      _expiryDate = null;
      _selectedMedType = 'Tablet';
      _currentStep = 0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(
              LucideIcons.checkCircle2,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              existingProduct != null
                  ? context.read<LanguageProvider>().strings.productUpdated
                  : context.read<LanguageProvider>().strings.productSaved,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalStepper(AppStrings l10n) {
    String labelFor(int i) {
      switch (i) {
        case 0:
          return l10n.generalInfo;
        case 1:
          return l10n.pricing;
        default:
          return l10n.inventory;
      }
    }

    Widget circle(int index) {
      const size = 28.0;
      if (_currentStep > index) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.check,
            color: AppColors.white,
            size: 16,
          ),
        );
      }
      if (_currentStep == index) {
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryDark, width: 2),
            color: AppColors.white,
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
              fontSize: 14,
            ),
          ),
        );
      }
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.divider.withValues(alpha: 0.35),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryAccent,
            fontSize: 14,
          ),
        ),
      );
    }

    Widget connector(bool done) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Divider(
            thickness: 2,
            color: done ? AppColors.primaryDark : AppColors.divider,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                circle(0),
                const SizedBox(height: 6),
                Text(
                  labelFor(0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _currentStep >= 0
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent,
                  ),
                ),
              ],
            ),
          ),
          connector(_currentStep > 0),
          Expanded(
            child: Column(
              children: [
                circle(1),
                const SizedBox(height: 6),
                Text(
                  labelFor(1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _currentStep >= 1
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent,
                  ),
                ),
              ],
            ),
          ),
          connector(_currentStep > 1),
          Expanded(
            child: Column(
              children: [
                circle(2),
                const SizedBox(height: 6),
                Text(
                  labelFor(2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _currentStep >= 2
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardFooter(
    AppStrings l10n,
    double maxWidth, {
    required bool useStepperMode,
  }) {
    final narrow = maxWidth < 380;
    final outlined = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      side: const BorderSide(color: AppColors.primaryDark, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final elevated = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    List<Widget> rowPair(
      Widget left,
      Widget right, {
      bool equalWidths = false,
    }) {
      if (narrow) {
        return [left, const SizedBox(height: 12), right];
      }
      if (equalWidths) {
        return [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ];
      }
      return [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: right),
      ];
    }

    if (!useStepperMode) {
      final bulk = OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BulkImportScreen()),
          );
        },
        icon: const Icon(
          LucideIcons.fileSpreadsheet,
          color: AppColors.primaryDark,
        ),
        label: Text(
          l10n.bulkImport,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: outlined,
      );
      final save = ElevatedButton.icon(
        onPressed: _submitForm,
        icon: const Icon(LucideIcons.plus, color: AppColors.white),
        label: Text(
          l10n.addProduct,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: elevated,
      );
      return narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowPair(bulk, save, equalWidths: true),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowPair(bulk, save, equalWidths: true),
            );
    }

    if (_currentStep == 0) {
      final bulk = OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BulkImportScreen()),
          );
        },
        icon: const Icon(
          LucideIcons.fileSpreadsheet,
          color: AppColors.primaryDark,
        ),
        label: Text(
          l10n.bulkImport,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: outlined,
      );
      final cont = ElevatedButton.icon(
        onPressed: () {
          if (_formKeyStep1.currentState!.validate()) {
            setState(() => _currentStep = 1);
          }
        },
        icon: const Icon(
          LucideIcons.arrowRight,
          color: AppColors.white,
          size: 20,
        ),
        label: Text(
          l10n.wizardContinue,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: elevated,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: bulk),
          const SizedBox(width: 12),
          Expanded(child: cont),
        ],
      );
    }
    if (_currentStep == 1) {
      final back = OutlinedButton.icon(
        onPressed: () => setState(() => _currentStep = 0),
        icon: const Icon(
          LucideIcons.arrowLeft,
          color: AppColors.primaryDark,
          size: 20,
        ),
        label: Text(
          l10n.wizardBack,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: outlined,
      );
      final cont = ElevatedButton.icon(
        onPressed: () {
          if (_formKeyStep2.currentState!.validate()) {
            setState(() => _currentStep = 2);
          }
        },
        icon: const Icon(
          LucideIcons.arrowRight,
          color: AppColors.white,
          size: 20,
        ),
        label: Text(
          l10n.wizardContinue,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: elevated,
      );
      return narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowPair(back, cont),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowPair(back, cont),
            );
    }
    final back = OutlinedButton.icon(
      onPressed: () => setState(() => _currentStep = 1),
      icon: const Icon(
        LucideIcons.arrowLeft,
        color: AppColors.primaryDark,
        size: 20,
      ),
      label: Text(
        l10n.wizardBack,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      style: outlined,
    );
    final save = ElevatedButton.icon(
      onPressed: _submitForm,
      icon: const Icon(LucideIcons.plus, color: AppColors.white),
      label: Text(
        l10n.addProduct,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      style: elevated,
    );
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowPair(back, save),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowPair(back, save),
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
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.watch<AdminProvider>();
    final showSupplierInfo = admin.showSupplierInfo;
    final useStepperMode =
        _useStepperOverride ?? admin.addProductUseStepperDefault;
    final pad = ResponsiveHelper.screenPadding(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.addProduct,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: constraints.maxWidth < 360 ? 19 : 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.addProductStepperModeToggle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.secondaryAccent,
                                    fontSize: constraints.maxWidth < 360
                                        ? 11
                                        : 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.scale(
                                  scale: constraints.maxWidth < 360 ? 0.88 : 1,
                                  child: Switch.adaptive(
                                    value: useStepperMode,
                                    activeThumbColor: AppColors.primaryDark,
                                    onChanged: (value) {
                                      setState(() {
                                        _useStepperOverride = value;
                                        _currentStep = 0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (useStepperMode) _buildHorizontalStepper(l10n),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad.left, 4, pad.right, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Offstage(
                        offstage: useStepperMode && _currentStep != 0,
                        child: Form(
                          key: _formKeyStep1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 1: GENERAL INFORMATION
                              _buildSection(
                                title: l10n.generalInfo,
                                icon: LucideIcons.info,
                                child: Column(
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Autocomplete<Product>(
                                          optionsBuilder:
                                              (
                                                TextEditingValue
                                                textEditingValue,
                                              ) {
                                                if (textEditingValue.text
                                                    .trim()
                                                    .isEmpty) {
                                                  return const Iterable<
                                                    Product
                                                  >.empty();
                                                }
                                                final lowerQuery =
                                                    textEditingValue.text
                                                        .toLowerCase();
                                                final seenNames = <String>{};
                                                final uniqueMatches = context
                                                    .read<AdminProvider>()
                                                    .allProducts
                                                    .where((p) {
                                                      return p.name
                                                              .toLowerCase()
                                                              .contains(
                                                                lowerQuery,
                                                              ) ||
                                                          p.generic
                                                              .toLowerCase()
                                                              .contains(
                                                                lowerQuery,
                                                              );
                                                    })
                                                    .where((p) {
                                                      final name = p.name.trim();
                                                      if (name.isEmpty) return false;
                                                      final key =
                                                          name.toLowerCase();
                                                      if (seenNames.contains(
                                                        key,
                                                      )) {
                                                        return false;
                                                      }
                                                      seenNames.add(key);
                                                      return true;
                                                    })
                                                    .toList();
                                                return uniqueMatches;
                                              },
                                          displayStringForOption:
                                              (Product option) => option.name,
                                          onSelected: (Product selection) {
                                            _loadProductInfo(selection);
                                            FocusScope.of(context).unfocus();
                                          },
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
                                                  label: l10n.productName,
                                                  icon: LucideIcons.pill,
                                                  focusNode: focusNode,
                                                  onEditingComplete:
                                                      onEditingComplete,
                                                  validator: (v) =>
                                                      v == null || v.isEmpty
                                                      ? 'Required'
                                                      : null,
                                                );
                                              },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4.0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: 200,
                                                    maxWidth:
                                                        constraints.maxWidth,
                                                  ),
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    itemBuilder:
                                                        (
                                                          BuildContext context,
                                                          int index,
                                                        ) {
                                                          final Product option =
                                                              options.elementAt(
                                                                index,
                                                              );
                                                          return InkWell(
                                                            onTap: () =>
                                                                onSelected(
                                                                  option,
                                                                ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    16.0,
                                                                  ),
                                                              child: Text(
                                                                option.name,
                                                                style: const TextStyle(
                                                                  color: AppColors
                                                                      .primaryDark,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
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
                                    _buildMedTypeDropdown(),
                                    const SizedBox(height: 12),
                                    _buildField(
                                      controller: _powerCtrl,
                                      label: l10n.powerLabel,
                                      icon: LucideIcons.flaskConical,
                                      hintText: l10n.powerHint,
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        Widget scanButton() {
                                          final btn = ElevatedButton.icon(
                                            onPressed: () async {
                                              await MobileScannerBridge
                                                  .beforePushOverlayScanner();
                                              if (!context.mounted) return;
                                              String? scannedCode;
                                              try {
                                                scannedCode =
                                                    await Navigator.push<String>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ScannerScreen(),
                                                  ),
                                                );
                                              } finally {
                                                MobileScannerBridge
                                                    .afterPopOverlayScanner();
                                              }
                                              if (!context.mounted) return;
                                              if (scannedCode != null &&
                                                  scannedCode.isNotEmpty) {
                                                final code = scannedCode;
                                                setState(() {
                                                  _barcodeCtrl.text = code;
                                                });
                                                // Auto-load if product exists
                                                final admin = context
                                                    .read<AdminProvider>();
                                                final existing = admin
                                                    .allProducts
                                                    .where(
                                                      (p) =>
                                                          p.barcode == code,
                                                    )
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
                                            label: Text(
                                              l10n.scanBtn,
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryDark,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              alignment: Alignment.center,
                                            ),
                                          );
                                          return btn;
                                        }

                                        final barcodeField = _buildField(
                                          controller: _barcodeCtrl,
                                          label: l10n.barcodeLabel,
                                          icon: LucideIcons.scanLine,
                                          keyboardType: TextInputType.number,
                                        );
                                        return IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(child: barcodeField),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width:
                                                    110, // Slightly wider for l10n.scanBtn
                                                child: scanButton(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const SizedBox(height: 12),
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return Autocomplete<String>(
                                                      optionsBuilder:
                                                          (
                                                            TextEditingValue
                                                            textEditingValue,
                                                          ) {
                                                            if (textEditingValue
                                                                .text
                                                                .trim()
                                                                .isEmpty) {
                                                              return const Iterable<
                                                                String
                                                              >.empty();
                                                            }
                                                            final lowerQuery =
                                                                textEditingValue
                                                                    .text
                                                                    .toLowerCase();
                                                            final allGenerics = context
                                                                .read<
                                                                  AdminProvider
                                                                >()
                                                                .allProducts
                                                                .map(
                                                                  (p) =>
                                                                      p.generic,
                                                                )
                                                                .where(
                                                                  (g) => g
                                                                      .isNotEmpty,
                                                                )
                                                                .toSet();
                                                            return allGenerics.where((
                                                              g,
                                                            ) {
                                                              return g
                                                                  .toLowerCase()
                                                                  .contains(
                                                                    lowerQuery,
                                                                  );
                                                            });
                                                          },
                                                      onSelected:
                                                          (String selection) {
                                                            _genericCtrl?.text =
                                                                selection;
                                                          },
                                                      fieldViewBuilder:
                                                          (
                                                            context,
                                                            controller,
                                                            focusNode,
                                                            onEditingComplete,
                                                          ) {
                                                            _genericCtrl =
                                                                controller;
                                                            return _buildField(
                                                              controller:
                                                                  controller,
                                                              label: l10n
                                                                  .genericName,
                                                              icon: LucideIcons
                                                                  .fileText,
                                                              focusNode:
                                                                  focusNode,
                                                              onEditingComplete:
                                                                  onEditingComplete,
                                                              validator: (v) =>
                                                                  v == null ||
                                                                      v.isEmpty
                                                                  ? 'Required'
                                                                  : null,
                                                            );
                                                          },
                                                      optionsViewBuilder:
                                                          (
                                                            context,
                                                            onSelected,
                                                            options,
                                                          ) {
                                                            return Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topLeft,
                                                              child: Material(
                                                                elevation: 4.0,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: ConstrainedBox(
                                                                  constraints: BoxConstraints(
                                                                    maxHeight:
                                                                        200,
                                                                    maxWidth:
                                                                        constraints
                                                                            .maxWidth,
                                                                  ),
                                                                  child: ListView.builder(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        options
                                                                            .length,
                                                                    itemBuilder:
                                                                        (
                                                                          BuildContext
                                                                          context,
                                                                          int
                                                                          index,
                                                                        ) {
                                                                          final String
                                                                          option = options.elementAt(
                                                                            index,
                                                                          );
                                                                          return InkWell(
                                                                            onTap: () => onSelected(
                                                                              option,
                                                                            ),
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
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return Autocomplete<String>(
                                                      optionsBuilder:
                                                          (
                                                            TextEditingValue
                                                            textEditingValue,
                                                          ) {
                                                            if (textEditingValue
                                                                .text
                                                                .trim()
                                                                .isEmpty) {
                                                              return const Iterable<
                                                                String
                                                              >.empty();
                                                            }
                                                            final lowerQuery =
                                                                textEditingValue
                                                                    .text
                                                                    .toLowerCase();
                                                            final allCompanies = context
                                                                .read<
                                                                  AdminProvider
                                                                >()
                                                                .allProducts
                                                                .map(
                                                                  (p) => p
                                                                      .companyName,
                                                                )
                                                                .where(
                                                                  (c) =>
                                                                      c !=
                                                                          null &&
                                                                      c.isNotEmpty,
                                                                )
                                                                .cast<String>()
                                                                .toSet();
                                                            return allCompanies.where(
                                                              (c) => c
                                                                  .toLowerCase()
                                                                  .contains(
                                                                    lowerQuery,
                                                                  ),
                                                            );
                                                          },
                                                      onSelected:
                                                          (String selection) {
                                                            _companyCtrl?.text =
                                                                selection;
                                                          },
                                                      fieldViewBuilder:
                                                          (
                                                            context,
                                                            controller,
                                                            focusNode,
                                                            onEditingComplete,
                                                          ) {
                                                            _companyCtrl =
                                                                controller;
                                                            return _buildField(
                                                              controller:
                                                                  controller,
                                                              label: l10n
                                                                  .companyName,
                                                              icon: LucideIcons
                                                                  .building2,
                                                              focusNode:
                                                                  focusNode,
                                                              onEditingComplete:
                                                                  onEditingComplete,
                                                            );
                                                          },
                                                      optionsViewBuilder:
                                                          (
                                                            context,
                                                            onSelected,
                                                            options,
                                                          ) {
                                                            return Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topLeft,
                                                              child: Material(
                                                                elevation: 4.0,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: ConstrainedBox(
                                                                  constraints: BoxConstraints(
                                                                    maxHeight:
                                                                        200,
                                                                    maxWidth:
                                                                        constraints
                                                                            .maxWidth,
                                                                  ),
                                                                  child: ListView.builder(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        options
                                                                            .length,
                                                                    itemBuilder:
                                                                        (
                                                                          BuildContext
                                                                          context,
                                                                          int
                                                                          index,
                                                                        ) {
                                                                          final String
                                                                          option = options.elementAt(
                                                                            index,
                                                                          );
                                                                          return InkWell(
                                                                            onTap: () => onSelected(
                                                                              option,
                                                                            ),
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
                                                if (showSupplierInfo) ...[
                                                  const Divider(height: 32),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          LucideIcons.truck,
                                                          size: 18,
                                                          color: AppColors
                                                              .primaryDark,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          l10n.supplierInfo,
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: AppColors
                                                                .primaryDark,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  LayoutBuilder(
                                                    builder: (context, constraints) {
                                                      return Autocomplete<
                                                        String
                                                      >(
                                                        optionsBuilder:
                                                            (
                                                              TextEditingValue
                                                              textEditingValue,
                                                            ) {
                                                              if (textEditingValue
                                                                  .text
                                                                  .trim()
                                                                  .isEmpty) {
                                                                return const Iterable<
                                                                  String
                                                                >.empty();
                                                              }
                                                              final lowerQuery =
                                                                  textEditingValue
                                                                      .text
                                                                      .toLowerCase();
                                                              final allSuppliers = context
                                                                  .read<
                                                                    AdminProvider
                                                                  >()
                                                                  .allProducts
                                                                  .map(
                                                                    (p) => p
                                                                        .supplierName,
                                                                  )
                                                                  .where(
                                                                    (s) =>
                                                                        s !=
                                                                            null &&
                                                                        s.isNotEmpty,
                                                                  )
                                                                  .cast<
                                                                    String
                                                                  >()
                                                                  .toSet();
                                                              return allSuppliers.where(
                                                                (s) => s
                                                                    .toLowerCase()
                                                                    .contains(
                                                                      lowerQuery,
                                                                    ),
                                                              );
                                                            },
                                                        onSelected: (String selection) {
                                                          _supplierNameCtrl
                                                                  ?.text =
                                                              selection;
                                                          final productWithSupplier =
                                                              context
                                                                  .read<
                                                                    AdminProvider
                                                                  >()
                                                                  .allProducts
                                                                  .where(
                                                                    (p) =>
                                                                        p.supplierName ==
                                                                        selection,
                                                                  )
                                                                  .firstOrNull;
                                                          if (productWithSupplier !=
                                                                  null &&
                                                              productWithSupplier
                                                                      .supplierPhone !=
                                                                  null) {
                                                            _supplierPhoneCtrl
                                                                    .text =
                                                                productWithSupplier
                                                                    .supplierPhone!;
                                                          }
                                                        },
                                                        fieldViewBuilder:
                                                            (
                                                              context,
                                                              controller,
                                                              focusNode,
                                                              onEditingComplete,
                                                            ) {
                                                              _supplierNameCtrl =
                                                                  controller;
                                                              return _buildField(
                                                                controller:
                                                                    controller,
                                                                label: l10n
                                                                    .supplierName,
                                                                icon:
                                                                    LucideIcons
                                                                        .user,
                                                                focusNode:
                                                                    focusNode,
                                                                onEditingComplete:
                                                                    onEditingComplete,
                                                              );
                                                            },
                                                        optionsViewBuilder:
                                                            (
                                                              context,
                                                              onSelected,
                                                              options,
                                                            ) {
                                                              return Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topLeft,
                                                                child: Material(
                                                                  elevation:
                                                                      4.0,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: ConstrainedBox(
                                                                    constraints: BoxConstraints(
                                                                      maxHeight:
                                                                          200,
                                                                      maxWidth:
                                                                          constraints
                                                                              .maxWidth,
                                                                    ),
                                                                    child: ListView.builder(
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      shrinkWrap:
                                                                          true,
                                                                      itemCount:
                                                                          options
                                                                              .length,
                                                                      itemBuilder:
                                                                          (
                                                                            BuildContext
                                                                            context,
                                                                            int
                                                                            index,
                                                                          ) {
                                                                            final String
                                                                            option = options.elementAt(
                                                                              index,
                                                                            );
                                                                            return InkWell(
                                                                              onTap: () => onSelected(
                                                                                option,
                                                                              ),
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
                                                    controller:
                                                        _supplierPhoneCtrl,
                                                    label: l10n.supplierPhone,
                                                    icon: LucideIcons.phone,
                                                    keyboardType:
                                                        TextInputType.phone,
                                                  ),
                                                ],
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Offstage(
                        offstage: useStepperMode && _currentStep != 1,
                        child: Form(
                          key: _formKeyStep2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 2a: PACKAGING
                              _buildSection(
                                title: l10n.packaging,
                                icon: LucideIcons.package,
                                child: LayoutBuilder(
                                  builder: (context, constraints) => Row(
                                    children: [
                                      Expanded(
                                        child: _buildField(
                                          controller: _stripsPerBoxCtrl,
                                          label: l10n.stripsPerBox,
                                          icon: LucideIcons.package,
                                          keyboardType: TextInputType.number,
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                              ? l10n.requiredField
                                              : null,
                                          onChanged: (val) {
                                            if (val.isEmpty) return;
                                            final spb = int.tryParse(val) ?? 1;
                                            if (spb > 0) {
                                              final boxP = double.tryParse(
                                                _priceBoxCtrl.text,
                                              );
                                              if (boxP != null) {
                                                _priceStripCtrl.text =
                                                    (boxP / spb)
                                                        .toStringAsFixed(2);
                                              }
                                              final boxes = int.tryParse(
                                                _stockBoxesCtrl.text,
                                              );
                                              if (boxes != null) {
                                                _stockStripsCtrl.text =
                                                    (boxes * spb).toString();
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildField(
                                          controller: _pcsPerStripCtrl,
                                          label: l10n.pcsPerStrip,
                                          icon: LucideIcons.boxes,
                                          keyboardType: TextInputType.number,
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                              ? l10n.requiredField
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              _buildSection(
                                title: l10n.pricing,
                                icon: LucideIcons.circleDollarSign,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildField(
                                            controller: _priceBoxCtrl,
                                            label:
                                                '${l10n.pricePerPc.split(' ').first} / ${l10n.boxes}',
                                            icon: LucideIcons.shoppingCart,
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) {
                                              if (val.isEmpty) return;
                                              final boxPrice =
                                                  double.tryParse(val);
                                              final spb =
                                                  int.tryParse(
                                                    _stripsPerBoxCtrl.text,
                                                  ) ??
                                                  1;
                                              if (boxPrice != null &&
                                                  spb > 0) {
                                                _priceStripCtrl.text =
                                                    (boxPrice / spb)
                                                        .toStringAsFixed(2);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildField(
                                            controller: _priceStripCtrl,
                                            label:
                                                '${l10n.pricePerPc.split(' ').first} / ${l10n.strips}',
                                            icon: LucideIcons.dollarSign,
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                v == null || v.isEmpty
                                                ? 'Required'
                                                : null,
                                            onChanged: (val) {
                                              if (val.isEmpty) return;
                                              final stripPrice =
                                                  double.tryParse(val);
                                              final spb =
                                                  int.tryParse(
                                                    _stripsPerBoxCtrl.text,
                                                  ) ??
                                                  1;
                                              if (stripPrice != null &&
                                                  spb > 0) {
                                                _priceBoxCtrl.text =
                                                    (stripPrice * spb)
                                                        .toStringAsFixed(2);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildField(
                                            controller: _buyingPriceBoxCtrl,
                                            label: 'Cost / ${l10n.boxes}',
                                            icon: LucideIcons.tag,
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) {
                                              if (val.isEmpty) return;
                                              final boxCost = double.tryParse(
                                                val,
                                              );
                                              final spb =
                                                  int.tryParse(
                                                    _stripsPerBoxCtrl.text,
                                                  ) ??
                                                  1;
                                              if (boxCost != null &&
                                                  spb > 0) {
                                                _buyingPriceStripCtrl.text =
                                                    (boxCost / spb)
                                                        .toStringAsFixed(2);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildField(
                                            controller: _buyingPriceStripCtrl,
                                            label: 'Cost / ${l10n.strips}',
                                            icon: LucideIcons.tag,
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) {
                                              if (val.isEmpty) return;
                                              final stripCost = double.tryParse(
                                                val,
                                              );
                                              final spb =
                                                  int.tryParse(
                                                    _stripsPerBoxCtrl.text,
                                                  ) ??
                                                  1;
                                              if (stripCost != null &&
                                                  spb > 0) {
                                                _buyingPriceBoxCtrl.text =
                                                    (stripCost * spb)
                                                        .toStringAsFixed(2);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ListenableBuilder(
                                      listenable: Listenable.merge([
                                        _buyingPriceStripCtrl,
                                        _priceStripCtrl,
                                      ]),
                                      builder: (context, _) {
                                        final cost =
                                            double.tryParse(
                                              _buyingPriceStripCtrl.text,
                                            ) ??
                                            0.0;
                                        final sell =
                                            double.tryParse(
                                              _priceStripCtrl.text,
                                            ) ??
                                            0.0;
                                        if (cost <= 0 || sell <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        final profit = sell - cost;
                                        final margin = sell > 0
                                            ? ((profit / sell) * 100)
                                                  .toStringAsFixed(1)
                                            : '0.0';
                                        final isLoss = profit < 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (isLoss
                                                        ? AppColors.error
                                                        : AppColors.success)
                                                    .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isLoss
                                                          ? AppColors.error
                                                          : AppColors.success)
                                                      .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isLoss
                                                    ? LucideIcons.trendingDown
                                                    : LucideIcons.trendingUp,
                                                size: 16,
                                                color: isLoss
                                                    ? AppColors.error
                                                    : AppColors.success,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  l10n.profitPreview(
                                                    profit
                                                        .abs()
                                                        .toStringAsFixed(2),
                                                    margin,
                                                    isLoss,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isLoss
                                                        ? AppColors.error
                                                        : AppColors.success,
                                                  ),
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
                            ],
                          ),
                        ),
                      ),
                      Offstage(
                        offstage: useStepperMode && _currentStep != 2,
                        child: Form(
                          key: _formKeyStep3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 3: INVENTORY TRACKING
                              _buildSection(
                                title: l10n.inventory,
                                icon: LucideIcons.clipboardList,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildField(
                                        controller: _stockBoxesCtrl,
                                        label:
                                            '${l10n.inventory} (${l10n.boxes})',
                                        icon: LucideIcons.box,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          if (val.isEmpty) return;
                                          final boxes = int.tryParse(val);
                                          final spb =
                                              int.tryParse(
                                                _stripsPerBoxCtrl.text,
                                              ) ??
                                              1;
                                          if (boxes != null && spb > 0) {
                                            _stockStripsCtrl.text =
                                                (boxes * spb).toString();
                                          }
                                        },
                                      ),
                                    ),
                                    _buildField(
                                      controller: _stockStripsCtrl,
                                      label:
                                          '${l10n.inventory} (${l10n.strips})',
                                      icon: LucideIcons.layers,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        if (val.isEmpty) return;
                                        final strips = int.tryParse(val);
                                        final spb =
                                            int.tryParse(
                                              _stripsPerBoxCtrl.text,
                                            ) ??
                                            1;
                                        if (strips != null && spb > 0) {
                                          _stockBoxesCtrl.text = (strips ~/ spb)
                                              .toString();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildField(
                                      controller: _lowStockWarningCtrl,
                                      label:
                                          '${l10n.minStockLevel} (${l10n.boxes})',
                                      icon: LucideIcons.alertTriangle,
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final expiryWidget = GestureDetector(
                                          onTap: _pickExpiryDate,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color:
                                                    AppColors.secondaryAccent,
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              color: AppColors.surfaceLight,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  LucideIcons.calendar,
                                                  color:
                                                      AppColors.secondaryAccent,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _expiryDate != null
                                                        ? 'Exp: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                                        : l10n.expiryDate,
                                                    style: TextStyle(
                                                      color: _expiryDate != null
                                                          ? AppColors
                                                                .primaryDark
                                                          : AppColors
                                                                .secondaryAccent,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        return ResponsiveHelper.responsiveRow(
                                          constraints: constraints,
                                          left: _buildField(
                                            controller: _batchCtrl,
                                            label: l10n.batchNumber,
                                            icon: LucideIcons.hash,
                                            keyboardType: TextInputType.text,
                                          ),
                                          right: expiryWidget,
                                        );
                                      },
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
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad.left,
                  4,
                  pad.right,
                  pad.bottom + MediaQuery.paddingOf(context).bottom,
                ),
                child: _buildWizardFooter(
                  l10n,
                  constraints.maxWidth,
                  useStepperMode: useStepperMode,
                ),
              ),
            ],
            );
          },
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
    String? hintText,
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
        hintText: hintText,
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

  void _showMedTypePicker() {
    final admin = context.read<AdminProvider>();
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = ctx.read<LanguageProvider>().strings;
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.changeMedType,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: admin.medicineTypes.length,
              itemBuilder: (c, i) {
                final t = admin.medicineTypes[i];
                final isSelected = t == _selectedMedType;
                return ListTile(
                  leading: Icon(
                    MedTypeIcons.getIcon(t),
                    color: MedTypeIcons.getColor(t),
                    size: 20,
                  ),
                  title: Text(
                    t,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: MedTypeIcons.getColor(
                    t,
                  ).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedMedType = t;
                    });
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedTypeDropdown() {
    final l10n = context.read<LanguageProvider>().strings;
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        _showMedTypePicker();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.secondaryAccent, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.layers,
              color: AppColors.secondaryAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.category,
                    style: const TextStyle(
                      color: AppColors.secondaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _selectedMedType ?? l10n.category,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              color: AppColors.secondaryAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
