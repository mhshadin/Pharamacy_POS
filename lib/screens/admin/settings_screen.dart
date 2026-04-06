import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';
import '../../providers/admin_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/alarm_slot.dart';
import '../../services/biometric_auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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

    final l10n = context.read<LanguageProvider>().strings;
    if (expiryCrit > expiryMod || expiryMod > expiryWarn) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text(
            l10n.expiryOrderError,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.settingsSaved,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;

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
                    title: l10n.inventoryAlerts,
                    icon: LucideIcons.bell,
                    children: [
                      _buildTextField(
                        controller: _lowStockCtrl,
                        label: l10n.lowStockThreshold,
                        helperText: l10n.lowStockThresholdHelper,
                        icon: LucideIcons.packageMinus,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _defaultOrderBoxesCtrl,
                        label: l10n.defaultBoxesToOrder,
                        helperText: l10n.defaultBoxesHelper,
                        icon: LucideIcons.packagePlus,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _expiryWarningCtrl,
                        label: l10n.expiringSoonWindow,
                        helperText: l10n.expiringSoonWindowHelper,
                        icon: LucideIcons.clock,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _expiryModerateCtrl,
                        label: l10n.moderateExpiry,
                        helperText: l10n.moderateExpiryHelper,
                        icon: LucideIcons.alertTriangle,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _expiryCriticalCtrl,
                        label: l10n.criticalExpiry,
                        helperText: l10n.criticalExpiryHelper,
                        icon: LucideIcons.alertOctagon,
                      ),
                      const Divider(height: 32, color: AppColors.divider),
                      _buildTextField(
                        controller: _expiryDelayCtrl,
                        label: l10n.defaultExpiryDelay,
                        helperText: l10n.defaultExpiryDelayHelper,
                        icon: LucideIcons.calendarDays,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          l10n.showSupplierInfo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          l10n.showSupplierInfoHelper,
                          style: const TextStyle(
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
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          l10n.expandOptionalFields,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          l10n.expandOptionalFieldsHelper,
                          style: const TextStyle(
                            color: AppColors.secondaryAccent,
                            fontSize: 12,
                          ),
                        ),
                        value: context.watch<AdminProvider>().expandOptionalFields,
                        onChanged: (val) {
                          context.read<AdminProvider>().saveSetting(
                            'expandOptionalFields',
                            val.toString(),
                          );
                        },
                        activeThumbColor: AppColors.primaryDark,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSecuritySection(context),
                  const SizedBox(height: 24),
                  _buildStockReminderSection(context),
                  const SizedBox(height: 24),
                  _buildMedicineTypesSection(context),
                  const SizedBox(height: 24),
                  _buildLanguageSection(context),
                  const SizedBox(height: 24),
                  _buildDriveSection(context),
                  const SizedBox(height: 24),
                  _buildLocalBackupSection(context),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(
                        LucideIcons.save,
                        color: AppColors.white,
                      ),
                      label: Text(
                        l10n.saveSettings,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
    final l10n = context.watch<LanguageProvider>().strings;

    String statusText = l10n.notSyncedYet;
    if (isSyncing) {
      statusText = l10n.syncingNow;
    } else if (syncError != null) {
      statusText = l10n.syncFailed;
    } else if (lastSync != null) {
      statusText = '${l10n.lastSync}: ${DateFormat('MMM dd, yyyy - HH:mm').format(lastSync)}';
    }

    return _buildSectionCard(
      title: l10n.databaseBackup,
      icon: LucideIcons.uploadCloud,
      children: [
        Text(
          l10n.googleDriveIntegration,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.googleDriveDesc,
          style: const TextStyle(
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
              color: syncError != null ? Colors.red.shade200 : AppColors.secondaryAccent.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSyncing 
                    ? LucideIcons.loader 
                    : (syncError != null ? LucideIcons.alertCircle : LucideIcons.checkCircle2),
                color: isSyncing 
                    ? AppColors.primaryDark.withValues(alpha: 0.7)
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
                          ? l10n.missingDriveScope
                          : l10n.ensureSignedIn,
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
                  label: Text(l10n.syncNow),
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

  Widget _buildStockReminderSection(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, admin, child) {
        final isEnabled = admin.stockReminderMasterEnabled;
        final isSupported = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

        return _buildSectionCard(
          title: 'Persistent Stock Reminders',
          icon: LucideIcons.alarmClock,
          children: [
            if (!isSupported)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(LucideIcons.alertCircle, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This feature is only supported on Android, iOS, and macOS. It is not available on Windows.',
                        style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
        SwitchListTile(
          title: const Text(
            'Enable Alarm Reminders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              fontSize: 14,
            ),
          ),
          subtitle: const Text(
            'Alarms will ring like a normal alarm clock even if the app is closed. Use this to ensure you check low stock and expiring items.',
            style: TextStyle(
              color: AppColors.secondaryAccent,
              fontSize: 12,
            ),
          ),
          value: isEnabled,
          onChanged: isSupported 
            ? (val) => admin.toggleStockReminderMaster(val)
            : null,
          activeThumbColor: AppColors.primaryDark,
          contentPadding: EdgeInsets.zero,
        ),
        if (isEnabled) ...[
          const Divider(height: 32, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scheduled Alarms',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontSize: 14,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddAlarmDialog(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Alarm'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (admin.alarmSlots.isEmpty)
            const Text(
              'No alarms set. Add one above.',
              style: TextStyle(color: AppColors.secondaryAccent, fontSize: 13),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: admin.alarmSlots.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final slot = admin.alarmSlots[index];
                return _buildAlarmSlotCard(context, slot);
              },
            ),
          const Divider(height: 32, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alarm Ringtone',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      admin.customRingtonePath != null
                          ? p.basename(admin.customRingtonePath!)
                          : 'Default Device Alarm Sound',
                      style: const TextStyle(
                        color: AppColors.secondaryAccent,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.audio,
                  );
                  if (result != null && result.files.single.path != null) {
                    admin.setCustomRingtone(result.files.single.path);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
        ],
      ],
    );
    });
  }

  Widget _buildAlarmSlotCard(BuildContext context, AlarmSlot slot) {
    // Format time
    final timeStr = '${slot.time.hour.toString().padLeft(2, '0')}:${slot.time.minute.toString().padLeft(2, '0')}';
    final daysStr = slot.days.map((d) {
      switch (d) {
        case 1: return 'Mon';
        case 2: return 'Tue';
        case 3: return 'Wed';
        case 4: return 'Thu';
        case 5: return 'Fri';
        case 6: return 'Sat';
        case 7: return 'Sun';
        default: return '';
      }
    }).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: slot.isEnabled ? AppColors.primaryDark.withValues(alpha: 0.5) : AppColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          timeStr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: slot.isEnabled ? AppColors.primaryDark : AppColors.secondaryAccent,
          ),
        ),
        subtitle: Text(
          daysStr,
          style: TextStyle(
            color: slot.isEnabled ? AppColors.primaryDark : AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: slot.isEnabled,
              onChanged: (val) {
                final upd = slot.copyWith(isEnabled: val);
                context.read<AdminProvider>().saveAlarmSlot(upd);
              },
              activeThumbColor: AppColors.primaryDark,
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
              onPressed: () {
                context.read<AdminProvider>().deleteAlarmSlot(slot.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAlarmDialog(BuildContext context) async {
    TimeOfDay selectedTime = TimeOfDay.now();
    Set<int> selectedDays = {1, 2, 3, 4, 5, 6, 7}; // Default all days

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Alarm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(LucideIcons.x, color: AppColors.secondaryAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      title: const Text('Time'),
                      trailing: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      onTap: () async {
                        final res = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (res != null) {
                          setModalState(() => selectedTime = res);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Repeat Days',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                        final isSel = selectedDays.contains(day);
                        String label = '';
                        switch (day) {
                          case 1: label = 'Mon'; break;
                          case 2: label = 'Tue'; break;
                          case 3: label = 'Wed'; break;
                          case 4: label = 'Thu'; break;
                          case 5: label = 'Fri'; break;
                          case 6: label = 'Sat'; break;
                          case 7: label = 'Sun'; break;
                        }
                        return FilterChip(
                          label: Text(label),
                          selected: isSel,
                          selectedColor: AppColors.primaryDark.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primaryDark,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: selectedDays.isEmpty
                          ? null
                          : () {
                              final slot = AlarmSlot(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                time: selectedTime,
                                days: selectedDays,
                              );
                              context.read<AdminProvider>().saveAlarmSlot(slot);
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Alarm',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocalBackupSection(BuildContext context) {
    final admin = context.read<AdminProvider>();
    final l10n = context.watch<LanguageProvider>().strings;

    return _buildSectionCard(
      title: l10n.phoneStorageBackup,
      icon: LucideIcons.smartphone,
      children: [
        Text(
          l10n.offlineBackupImport,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.offlineBackupDesc,
          style: const TextStyle(
            color: AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await admin.scheduleSync(immediate: true);
                  if (!context.mounted) return;
                  setState(() => _isLoading = false);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.exportedSuccess),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.download),
                label: Text(l10n.exportNow),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showImportConfirm(context),
                icon: const Icon(LucideIcons.fileInput, color: AppColors.white),
                label: Text(l10n.importDb, style: const TextStyle(color: AppColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showImportConfirm(BuildContext context) {
    final l10n = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.importDatabase,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.importDatabaseWarning,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.secondaryAccent,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.cancelBtn,
                        style: const TextStyle(color: AppColors.secondaryAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                        );

                        if (result != null && result.files.single.path != null) {
                          setState(() => _isLoading = true);
                          try {
                            if (!context.mounted) return;
                            await context.read<AdminProvider>().importDatabaseLocally(result.files.single.path!);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.importSuccess), backgroundColor: AppColors.success),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${l10n.importFailed}: $e'), backgroundColor: AppColors.error),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.importReplace, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineTypesSection(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final l10n = context.watch<LanguageProvider>().strings;
    final types = admin.medicineTypes;
    final addCtrl = TextEditingController();

    return _buildSectionCard(
      title: l10n.medicineCategories,
      icon: LucideIcons.layers,
      children: [
        Text(
          l10n.medicineCategoriesDesc,
          style: const TextStyle(
            color: AppColors.secondaryAccent,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showDeleteConfirm(context, type),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.x, size: 12, color: AppColors.white),
                    ),
                  ),
                ],
              ),
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
                  hintText: l10n.addNewType,
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryAccent),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primaryDark, width: 2),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, String type) {
    final l10n = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.trash2, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.removeCategory,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.removeCategoryConfirm} "$type"? ${l10n.removeCategoryWarning}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.secondaryAccent,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        l10n.cancelBtn,
                        style: const TextStyle(color: AppColors.secondaryAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<AdminProvider>().removeMedicineType(type);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.removeBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final l10n = langProvider.strings;

    return _buildSectionCard(
      title: l10n.languageSetting,
      icon: LucideIcons.languages,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLanguageOption(
                context,
                title: 'English',
                isSelected: !langProvider.isBangla,
                onTap: () => langProvider.setLanguage('en'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLanguageOption(
                context,
                title: 'বাংলা',
                isSelected: langProvider.isBangla,
                onTap: () => langProvider.setLanguage('bn'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.divider,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.white : AppColors.primaryDark,
            ),
          ),
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
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
            helperText: helperText,
            helperMaxLines: 3,
            helperStyle: const TextStyle(
              color: AppColors.secondaryAccent,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    return _buildSectionCard(
      title: l10n.adminAccessSecurity,
      icon: LucideIcons.fingerprint,
      children: const [
        _BiometricAdminSwitch(),
      ],
    );
  }
}

class _BiometricAdminSwitch extends StatefulWidget {
  const _BiometricAdminSwitch();

  @override
  State<_BiometricAdminSwitch> createState() => _BiometricAdminSwitchState();
}

class _BiometricAdminSwitchState extends State<_BiometricAdminSwitch> {
  bool? _hardwareReady;

  @override
  void initState() {
    super.initState();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    final ok = await BiometricAuthService.instance.isReadyForUse();
    if (mounted) setState(() => _hardwareReady = ok);
  }

  Future<void> _onToggle(bool wantEnabled) async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    await _checkHardware();

    if (_hardwareReady != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.biometricSetupRequired,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final prompt = wantEnabled
        ? l10n.biometricPromptEnable
        : l10n.biometricPromptDisable;
    final result = await BiometricAuthService.instance.authenticate(
      localizedReason: prompt,
    );
    if (!mounted) return;
    if (!result.success) {
      final reason = result.reason ?? BiometricAuthFailureReason.unknown;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _messageForFailure(reason),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await admin.saveSetting('adminBiometricEnabled', wantEnabled.toString());
  }

  String _messageForFailure(BiometricAuthFailureReason reason) {
    final l10n = context.read<LanguageProvider>().strings;
    switch (reason) {
      case BiometricAuthFailureReason.notEnrolled:
        return l10n.biometricSetupRequired;
      case BiometricAuthFailureReason.notAvailable:
        return l10n.biometricNotAvailable;
      case BiometricAuthFailureReason.lockedOut:
        return l10n.biometricLockedOut;
      case BiometricAuthFailureReason.temporaryLockout:
        return l10n.biometricTryAgainLater;
      case BiometricAuthFailureReason.canceled:
        return l10n.biometricCanceled;
      case BiometricAuthFailureReason.unknown:
        return l10n.biometricAuthFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final admin = context.watch<AdminProvider>();
    final ready = _hardwareReady == true;
    final checking = _hardwareReady == null;

    return SwitchListTile(
      title: Text(
        l10n.biometricUnlockAdmin,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        checking
            ? '…'
            : (ready
                ? l10n.biometricUnlockAdminHelper
                : l10n.biometricSetupRequired),
        style: const TextStyle(
          color: AppColors.secondaryAccent,
          fontSize: 12,
        ),
      ),
      value: admin.adminBiometricEnabled,
      onChanged: checking || !ready
          ? null
          : (v) => _onToggle(v),
      activeThumbColor: AppColors.primaryDark,
      contentPadding: EdgeInsets.zero,
    );
  }
}
