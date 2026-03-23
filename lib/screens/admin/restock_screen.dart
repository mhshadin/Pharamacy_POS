import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/admin_provider.dart';
import '../../providers/pos_provider.dart';
import '../../utils/colors.dart';
import '../../utils/responsive_helper.dart';

/// Add stock for an existing product (new batch with expiry).
class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key, required this.product});

  final Product product;

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _stockBoxesCtrl = TextEditingController();
  final _stockStripsCtrl = TextEditingController();
  DateTime? _expiryDate;
  bool _submitting = false;

  Product get _p => widget.product;

  @override
  void initState() {
    super.initState();
    // Default until settings apply on first frame.
    _expiryDate = DateTime.now().add(const Duration(days: 180));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final admin = context.read<AdminProvider>();
      setState(() {
        _expiryDate =
            DateTime.now().add(Duration(days: admin.expiryDelayMonths * 30));
      });
    });
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _stockBoxesCtrl.dispose();
    _stockStripsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final admin = context.read<AdminProvider>();
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

  void _syncBoxesFromStrips(String val) {
    if (val.isEmpty) return;
    final strips = int.tryParse(val);
    final spb = _p.stripsPerBox > 0 ? _p.stripsPerBox : 1;
    if (strips != null) {
      _stockBoxesCtrl.text = (strips ~/ spb).toString();
    }
  }

  void _syncStripsFromBoxes(String val) {
    if (val.isEmpty) return;
    final boxes = int.tryParse(val);
    final spb = _p.stripsPerBox > 0 ? _p.stripsPerBox : 1;
    if (boxes != null) {
      _stockStripsCtrl.text = (boxes * spb).toString();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final spb = _p.stripsPerBox > 0 ? _p.stripsPerBox : 1;
    final pps = _p.pcsPerStrip > 0 ? _p.pcsPerStrip : 10;

    int stripsInput = int.tryParse(_stockStripsCtrl.text) ?? 0;
    int boxesInput = int.tryParse(_stockBoxesCtrl.text) ?? 0;

    int totalStrips;
    if (_stockStripsCtrl.text.isNotEmpty) {
      totalStrips = stripsInput;
    } else if (_stockBoxesCtrl.text.isNotEmpty) {
      totalStrips = boxesInput * spb;
    } else {
      totalStrips = 0;
    }

    if (totalStrips <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter boxes or strips to add.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<AdminProvider>().addBatch(
            productId: _p.id,
            batchNumber: _batchCtrl.text.trim(),
            expiryDate: _expiryDate!,
            strips: totalStrips,
            pcs: 0,
            pcsPerStrip: pps,
          );
      if (!mounted) return;
      await context.read<POSProvider>().loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(LucideIcons.checkCircle2, color: AppColors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Stock added successfully!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add stock. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
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
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exp = _p.expiryDate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Restock'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: ResponsiveHelper.screenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _p.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _p.companyName != null && _p.companyName!.isNotEmpty
                          ? '${_p.generic} • ${_p.companyName}'
                          : _p.generic,
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current stock: ${_p.stockBoxes} boxes • ${_p.remainingStrips} strips • ${_p.totalPieces} pcs',
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontSize: 12,
                      ),
                    ),
                    if (exp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current expiry (product): ${exp.day}/${exp.month}/${exp.year}',
                        style: const TextStyle(
                          color: AppColors.secondaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Packaging: ${_p.stripsPerBox} strips/box • ${_p.pcsPerStrip} pcs/strip',
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildSection(
                title: 'Batch & expiry',
                icon: LucideIcons.calendar,
                child: LayoutBuilder(
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
                                    ? 'New batch exp: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                                    : 'Select expiry for new batch*',
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
                    );
                    return ResponsiveHelper.responsiveRow(
                      constraints: constraints,
                      left: _buildField(
                        controller: _batchCtrl,
                        label: 'Batch No (optional)',
                        icon: LucideIcons.hash,
                        keyboardType: TextInputType.text,
                      ),
                      right: expiryWidget,
                    );
                  },
                ),
              ),
              _buildSection(
                title: 'Quantity to add',
                icon: LucideIcons.package,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ResponsiveHelper.responsiveRow(
                      constraints: constraints,
                      left: _buildField(
                        controller: _stockBoxesCtrl,
                        label: 'Boxes',
                        icon: LucideIcons.box,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _syncStripsFromBoxes,
                      ),
                      right: _buildField(
                        controller: _stockStripsCtrl,
                        label: 'Strips',
                        icon: LucideIcons.layers,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _syncBoxesFromStrips,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(LucideIcons.plus, color: AppColors.white),
                  label: Text(
                    _submitting ? 'Adding…' : 'Add stock',
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
