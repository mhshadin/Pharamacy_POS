import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lowStockCtrl = TextEditingController();
  final _expiryWarningCtrl = TextEditingController();
  final _expiryCriticalCtrl = TextEditingController();
  final _expiryDelayCtrl = TextEditingController();
  final _defaultOrderBoxesCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final admin = context.read<AdminProvider>();
    _lowStockCtrl.text = admin.lowStockThreshold.toString();
    _expiryWarningCtrl.text = admin.expiringSoonDays.toString();
    _expiryCriticalCtrl.text = admin.criticalExpiryDays.toString();
    _expiryDelayCtrl.text = admin.expiryDelayMonths.toString();
    _defaultOrderBoxesCtrl.text = admin.defaultOrderBoxes.toString();
  }

  @override
  void dispose() {
    _lowStockCtrl.dispose();
    _expiryWarningCtrl.dispose();
    _expiryCriticalCtrl.dispose();
    _expiryDelayCtrl.dispose();
    _defaultOrderBoxesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final admin = context.read<AdminProvider>();

    int lowStock = int.tryParse(_lowStockCtrl.text) ?? 20;
    int expiryWarn = int.tryParse(_expiryWarningCtrl.text) ?? 90;
    int expiryCrit = int.tryParse(_expiryCriticalCtrl.text) ?? 30;
    int expiryDelay = int.tryParse(_expiryDelayCtrl.text) ?? 6;
    int defaultOrderBoxes = int.tryParse(_defaultOrderBoxesCtrl.text) ?? 100;
    if (defaultOrderBoxes <= 0) defaultOrderBoxes = 100;

    await admin.saveSetting('lowStockThreshold', lowStock.toString());
    await admin.saveSetting('expiringSoonDays', expiryWarn.toString());
    await admin.saveSetting('criticalExpiryDays', expiryCrit.toString());
    await admin.saveSetting('expiryDelayMonths', expiryDelay.toString());
    await admin.saveSetting(
      'defaultOrderBoxes',
      defaultOrderBoxes.toString(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

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
              'Settings saved successfully',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    title: 'Inventory Alerts',
                    icon: LucideIcons.bell,
                    children: [
                      _buildTextField(
                        controller: _lowStockCtrl,
                        label: 'Low Stock Threshold (Boxes)',
                        helperText:
                            'Default warning level in boxes. Individual products can override this.',
                        icon: LucideIcons.packageMinus,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _defaultOrderBoxesCtrl,
                        label: 'Default Boxes to Order',
                        helperText:
                            'This is pre-filled when exporting an order list from Low Stock / Expiring Soon.',
                        icon: LucideIcons.packagePlus,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _expiryWarningCtrl,
                        label: 'Expiring Soon Warning (Days)',
                        helperText:
                            'Products expiring in this many days or fewer will show up in Expiring Soon list.',
                        icon: LucideIcons.clock,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _expiryCriticalCtrl,
                        label: 'Critical Expiry Warning (Days)',
                        helperText:
                            'Products expiring in this many days or fewer will be highlighted in critical red.',
                        icon: LucideIcons.alertOctagon,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _expiryDelayCtrl,
                        label: 'Default Expiry Delay (Months)',
                        helperText:
                            'The initial date in the Stock In date picker will be set to this many months from today.',
                        icon: LucideIcons.calendarDays,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text(
                          'Show Supplier Info in Stock In',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Enable this to enter and track supplier name and phone number during stock in.',
                          style: TextStyle(
                            color: AppColors.secondaryAccent,
                            fontSize: 12,
                          ),
                        ),
                        value: context.watch<AdminProvider>().showSupplierInfo,
                        onChanged: (val) {
                          context.read<AdminProvider>().saveSetting(
                            'showSupplierInfo',
                            val.toString(),
                          );
                        },
                        activeThumbColor: AppColors.primaryDark,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(
                        LucideIcons.save,
                        color: AppColors.white,
                      ),
                      label: const Text(
                        'Save Settings',
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
          decoration: InputDecoration(
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
        ),
        const SizedBox(height: 8),
        Text(
          helperText,
          style: const TextStyle(
            color: AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
