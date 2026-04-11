import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pharmacy_pos/models/product.dart';
import 'package:pharmacy_pos/providers/admin_provider.dart';
import 'package:pharmacy_pos/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:pharmacy_pos/providers/language_provider.dart';

class BulkImportEditForm extends StatefulWidget {
  final BulkImportRecord record;
  final AdminProvider admin;

  const BulkImportEditForm({
    super.key,
    required this.record,
    required this.admin,
  });

  @override
  State<BulkImportEditForm> createState() => _BulkImportEditFormState();
}

class _BulkImportEditFormState extends State<BulkImportEditForm> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _genericCtrl;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _priceBoxCtrl;
  late TextEditingController _stripsPerBoxCtrl;
  late TextEditingController _pcsPerStripCtrl;
  late TextEditingController _stockBoxesCtrl;
  late TextEditingController _minStockBoxesCtrl;
  late TextEditingController _batchCtrl;
  late TextEditingController _supplierNameCtrl;
  late TextEditingController _supplierPhoneCtrl;
  late TextEditingController _costPricePerPcCtrl;
  late TextEditingController _powerCtrl;

  DateTime? _expiryDate;
  String? _selectedMedType;

  @override
  void initState() {
    super.initState();
    final p = widget.record.product;
    final admin = widget.admin;

    final stockBoxes = p.stripsPerBox > 0 ? p.stockStrips ~/ p.stripsPerBox : 0;
    final minStockBoxes =
        p.stripsPerBox > 0 ? (p.minStockLevel ~/ p.stripsPerBox) : admin.lowStockThreshold;

    _nameCtrl = TextEditingController(text: p.name);
    _genericCtrl = TextEditingController(text: p.generic);
    _companyNameCtrl = TextEditingController(text: p.companyName ?? '');
    _barcodeCtrl = TextEditingController(text: p.barcode ?? '');
    _priceBoxCtrl = TextEditingController(text: p.priceBox.toStringAsFixed(2));
    _stripsPerBoxCtrl = TextEditingController(text: p.stripsPerBox.toString());
    _pcsPerStripCtrl = TextEditingController(text: p.pcsPerStrip.toString());
    _stockBoxesCtrl = TextEditingController(text: stockBoxes.toString());
    _minStockBoxesCtrl =
        TextEditingController(text: minStockBoxes.toString());
    _batchCtrl = TextEditingController(text: widget.record.batchNumber ?? '');
    _supplierNameCtrl =
        TextEditingController(text: p.supplierName ?? '');
    _supplierPhoneCtrl =
        TextEditingController(text: p.supplierPhone ?? '');
    _costPricePerPcCtrl =
        TextEditingController(text: widget.record.costPricePerPc.toStringAsFixed(2));
    _powerCtrl = TextEditingController(text: p.power ?? '');
    _expiryDate = widget.record.expiryDate;
    _selectedMedType = p.medType ?? 'Tablet';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _genericCtrl.dispose();
    _companyNameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceBoxCtrl.dispose();
    _stripsPerBoxCtrl.dispose();
    _pcsPerStripCtrl.dispose();
    _stockBoxesCtrl.dispose();
    _minStockBoxesCtrl.dispose();
    _batchCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _costPricePerPcCtrl.dispose();
    _powerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final admin = widget.admin;
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ??
          DateTime.now().add(Duration(days: admin.expiryDelayMonths * 30)),
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
      setState(() => _expiryDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      final l10n = context.read<LanguageProvider>().strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectExpiryDateError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    int spb = int.tryParse(_stripsPerBoxCtrl.text) ?? 1;
    int pps = int.tryParse(_pcsPerStripCtrl.text) ?? 10;
    if (spb <= 0) spb = 1;
    if (pps <= 0) pps = 10;

    final boxes = int.tryParse(_stockBoxesCtrl.text) ?? 0;
    final totalPcs = boxes * spb * pps;
    final stockStrips = totalPcs ~/ pps;
    final stockPcs = totalPcs % pps;

    final priceBox = double.tryParse(_priceBoxCtrl.text) ?? 0;
    final priceStrip = spb > 0 ? priceBox / spb : 0.0;
    final pricePc = pps > 0 ? priceStrip / pps : 0.0;

    final minStockBoxes =
        int.tryParse(_minStockBoxesCtrl.text) ?? widget.admin.lowStockThreshold;
    final minStockLevel = minStockBoxes * spb;

    final costPrice = double.tryParse(_costPricePerPcCtrl.text) ?? 0.0;

    final updatedProduct = Product(
      id: widget.record.product.id,
      name: _nameCtrl.text.trim(),
      generic: _genericCtrl.text.trim(),
      companyName: _companyNameCtrl.text.trim().isEmpty
          ? null
          : _companyNameCtrl.text.trim(),
      priceStrip: priceStrip,
      pricePc: pricePc,
      priceBox: priceBox,
      pcsPerStrip: pps,
      stripsPerBox: spb,
      stockStrips: stockStrips,
      stockPcs: stockPcs,
      expiryDate: _expiryDate,
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      minStockLevel: minStockLevel,
      supplierName: _supplierNameCtrl.text.trim().isEmpty
          ? null
          : _supplierNameCtrl.text.trim(),
      supplierPhone: _supplierPhoneCtrl.text.trim().isEmpty
          ? null
          : _supplierPhoneCtrl.text.trim(),
      medType: _selectedMedType,
      power: _powerCtrl.text.trim().isEmpty ? null : _powerCtrl.text.trim(),
      costPricePerPc: costPrice,
    );

    final updatedRecord = BulkImportRecord(
      product: updatedProduct,
      batchNumber: _batchCtrl.text.trim().isEmpty
          ? null
          : _batchCtrl.text.trim(),
      expiryDate: _expiryDate!,
      costPricePerPc: costPrice,
    );

    Navigator.of(context).pop<BulkImportRecord>(updatedRecord);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.admin;
    final l10n = context.watch<LanguageProvider>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.editImportedProduct,
          style: const TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // General
              _buildSection(
                title: l10n.generalInfo,
                icon: LucideIcons.info,
                child: Column(
                  children: [
                    _buildField(
                      controller: _nameCtrl,
                      label: l10n.productNameLabel,
                      icon: LucideIcons.pill,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredLabel : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _genericCtrl,
                      label: l10n.genericDescription,
                      icon: LucideIcons.fileText,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredLabel : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _companyNameCtrl,
                      label: l10n.companyNameOptional,
                      icon: LucideIcons.factory,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _barcodeCtrl,
                      label: l10n.barcodeLabelOptional,
                      icon: LucideIcons.scanLine,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildMedTypeDropdown(),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _powerCtrl,
                      label: '${l10n.powerLabel} (${l10n.powerHint})',
                      icon: LucideIcons.flaskConical,
                    ),
                  ],
                ),
              ),
              // Pricing & Packaging
              _buildSection(
                title: l10n.pricingPackaging,
                icon: LucideIcons.circleDollarSign,
                child: Column(
                  children: [
                    _buildField(
                      controller: _stripsPerBoxCtrl,
                      label: l10n.stripsPerBoxLabel,
                      icon: LucideIcons.package,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return l10n.mustBeGreaterThanZero;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _pcsPerStripCtrl,
                      label: l10n.pcsPerStripLabel,
                      icon: LucideIcons.boxes,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return l10n.mustBeGreaterThanZero;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _priceBoxCtrl,
                      label: l10n.pricePerBoxLabel,
                      icon: LucideIcons.shoppingCart,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return l10n.mustBeGreaterThanZero;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _costPricePerPcCtrl,
                      label: l10n.buyingPricePerPc,
                      icon: LucideIcons.coins,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
              // Inventory
              _buildSection(
                title: l10n.inventoryTracking,
                icon: LucideIcons.clipboardList,
                child: Column(
                  children: [
                    _buildField(
                      controller: _stockBoxesCtrl,
                      label: l10n.stockInBoxesLabel,
                      icon: LucideIcons.box,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _minStockBoxesCtrl,
                      label: l10n.minStockWarningBox,
                      icon: LucideIcons.alertTriangle,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _batchCtrl,
                            label: l10n.batchNoOptional,
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
                                          : '${l10n.selectExpiry}*',
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
              if (admin.showSupplierInfo)
                _buildSection(
                  title: l10n.supplierInfo,
                  icon: LucideIcons.truck,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _supplierNameCtrl,
                        label: l10n.supplierNameLabel,
                        icon: LucideIcons.user,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _supplierPhoneCtrl,
                        label: l10n.supplierPhoneLabel,
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(LucideIcons.check, color: AppColors.white),
                  label: Text(
                    l10n.saveChangesLabel,
                    style: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedTypeDropdown() {
    final l10n = context.watch<LanguageProvider>().strings;
    final medTypes = widget.admin.medicineTypes;
    return DropdownButtonFormField<String>(
      initialValue: _selectedMedType,
      decoration: InputDecoration(
        labelText: l10n.medTypeLabel,
        labelStyle: const TextStyle(
          color: AppColors.secondaryAccent,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          LucideIcons.pill,
          color: AppColors.secondaryAccent,
          size: 20,
        ),
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
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 2,
          ),
        ),
      ),
      items: medTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(
            type,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedMedType = val);
        }
      },
    );
  }

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
}

