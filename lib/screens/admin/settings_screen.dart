import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  final _expiryModerateCtrl = TextEditingController();
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
    _expiryModerateCtrl.text = admin.moderateExpiryDays.toString();
    _expiryDelayCtrl.text = admin.expiryDelayMonths.toString();
    _defaultOrderBoxesCtrl.text = admin.defaultOrderBoxes.toString();
  }

  @override
  void dispose() {
    _lowStockCtrl.dispose();
    _expiryWarningCtrl.dispose();
    _expiryCriticalCtrl.dispose();
    _expiryModerateCtrl.dispose();
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
    int expiryMod = int.tryParse(_expiryModerateCtrl.text) ?? 60;
    int expiryDelay = int.tryParse(_expiryDelayCtrl.text) ?? 6;
    int defaultOrderBoxes = int.tryParse(_defaultOrderBoxesCtrl.text) ?? 100;
    if (defaultOrderBoxes <= 0) defaultOrderBoxes = 100;

    if (expiryCrit > expiryMod || expiryMod > expiryWarn) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: const Text(
            'Expiry days must be ordered: Critical (red) ≤ Moderate (amber) ≤ Expiring Soon window.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    await admin.saveSetting('lowStockThreshold', lowStock.toString());
    await admin.saveSetting('expiringSoonDays', expiryWarn.toString());
    await admin.saveSetting('criticalExpiryDays', expiryCrit.toString());
    await admin.saveSetting('moderateExpiryDays', expiryMod.toString());
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
                        label: 'Expiring Soon Window (Days)',
                        helperText:
                            'Products expiring within this many days appear in Expiring Soon. Green tier uses the time range above Moderate (amber).',
                        icon: LucideIcons.clock,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _expiryModerateCtrl,
                        label: 'Moderate Expiry (Days, Amber)',
                        helperText:
                            'Amber highlight: expires within this many days but after the critical (red) range. Must be between Critical and the window above.',
                        icon: LucideIcons.alertTriangle,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _expiryCriticalCtrl,
                        label: 'Critical Expiry (Days, Red)',
                        helperText:
                            'Red highlight: expires within this many days (and expired stock). Use the lowest value of the three.',
                        icon: LucideIcons.alertOctagon,
                      ),
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
                  const SizedBox(height: 24),
                  _buildMedicineTypesSection(context),
                  const SizedBox(height: 24),
                  _buildDriveSection(context),
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

  Widget _buildDriveSection(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final isSyncing = admin.isSyncing;
    final lastSync = admin.lastSyncTime;
    final syncError = admin.syncError;
    
    String statusText = 'Not synced yet';
    if (isSyncing) {
      statusText = 'Syncing now...';
    } else if (syncError != null) {
      statusText = 'Sync failed';
    } else if (lastSync != null) {
      statusText = 'Last sync: ${DateFormat('MMM dd, yyyy - HH:mm').format(lastSync)}';
    }

    return _buildSectionCard(
      title: 'Database Backup',
      icon: LucideIcons.uploadCloud,
      children: [
        const Text(
          'Google Drive Integration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Securely backup your database to Google Drive. Backups happen automatically after data changes.',
          style: TextStyle(
            color: AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: syncError != null ? Colors.red.shade50 : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: syncError != null ? Colors.red.shade200 : AppColors.secondaryAccent.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSyncing 
                    ? LucideIcons.loader 
                    : (syncError != null ? LucideIcons.alertCircle : LucideIcons.checkCircle2),
                color: isSyncing 
                    ? AppColors.primaryDark.withOpacity(0.7)
                    : (syncError != null ? Colors.red : AppColors.success),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: syncError != null ? Colors.red.shade900 : AppColors.primaryDark,
                        fontSize: 14,
                      ),
                    ),
                    if (syncError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                         syncError.contains('403') 
                          ? 'Missing Drive scope. Please sign out and sign back in.'
                          : 'Ensure you are signed in and have internet.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isSyncing)
                TextButton.icon(
                  onPressed: () {
                    context.read<AdminProvider>().scheduleSync(immediate: true);
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Sync Now'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineTypesSection(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final types = admin.medicineTypes;
    final addCtrl = TextEditingController();

    return _buildSectionCard(
      title: 'Medicine Categories',
      icon: LucideIcons.layers,
      children: [
        const Text(
          'Manage types like Tablet, Syrup, etc. These appear in Stock In and POS filters.',
          style: TextStyle(
            color: AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            return Chip(
              label: Text(
                type,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              backgroundColor: AppColors.surfaceLight,
              side: const BorderSide(color: AppColors.divider),
              deleteIcon: const Icon(LucideIcons.x, size: 14, color: AppColors.error),
              onDeleted: () {
                _showDeleteConfirm(context, type);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: addCtrl,
                decoration: InputDecoration(
                  hintText: 'Add new type (e.g. Inhaler)',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryAccent),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    context.read<AdminProvider>().addMedicineType(val.trim());
                    addCtrl.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (addCtrl.text.trim().isNotEmpty) {
                  context.read<AdminProvider>().addMedicineType(addCtrl.text.trim());
                  addCtrl.clear();
                }
              },
              icon: const Icon(LucideIcons.plus, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Type?'),
        content: Text('Are you sure you want to remove "$type"? Existing products with this type will keep it until edited.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<AdminProvider>().removeMedicineType(type);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
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
