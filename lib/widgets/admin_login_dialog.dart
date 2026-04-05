import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../utils/colors.dart';
import '../providers/admin_provider.dart';
import '../providers/language_provider.dart';
import '../services/biometric_auth_service.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  bool _obscure = true;
  bool _biometricReady = false;
  bool _biometricChecked = false;
  String _biometricButtonLabel = '';

  @override
  void initState() {
    super.initState();
    _prepareBiometricUi();
  }

  Future<void> _prepareBiometricUi() async {
    final admin = context.read<AdminProvider>();
    if (!admin.adminBiometricEnabled) {
      if (mounted) {
        setState(() {
          _biometricChecked = true;
          _biometricReady = false;
        });
      }
      return;
    }

    final ready = await BiometricAuthService.instance.isReadyForUse();
    List<BiometricType> types = [];
    if (ready) {
      types = await BiometricAuthService.instance.getEnrolledTypes();
    }
    if (!mounted) return;
    final l10n = context.read<LanguageProvider>().strings;
    setState(() {
      _biometricChecked = true;
      _biometricReady = ready;
      _biometricButtonLabel = _labelForBiometricTypes(types, l10n);
    });

    if (ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryBiometricLogin(auto: true);
      });
    }
  }

  static String _labelForBiometricTypes(
    List<BiometricType> types,
    AppStrings l10n,
  ) {
    if (types.contains(BiometricType.face)) return l10n.biometricUseFace;
    if (types.contains(BiometricType.fingerprint)) {
      return l10n.biometricUseFingerprint;
    }
    if (types.contains(BiometricType.iris)) return l10n.biometricUseGeneric;
    return l10n.biometricUseGeneric;
  }

  Future<void> _tryBiometricLogin({bool auto = false}) async {
    final l10n = context.read<LanguageProvider>().strings;
    final ok = await BiometricAuthService.instance.authenticate(
      localizedReason: l10n.biometricUnlockReason,
    );
    if (!mounted) return;
    if (ok) {
      context.read<AdminProvider>().completeBiometricLogin();
      Navigator.pop(context, true);
    } else if (!auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.biometricAuthFailed,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submitPin() {
    final l10n = context.read<LanguageProvider>().strings;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = l10n.adminLoginPinEmpty);
      return;
    }
    final admin = context.read<AdminProvider>();
    if (admin.login(pin)) {
      Navigator.pop(context, true);
    } else {
      setState(() => _errorText = l10n.adminLoginWrongPin);
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final admin = context.watch<AdminProvider>();
    final showBiometric =
        admin.adminBiometricEnabled && _biometricChecked && _biometricReady;

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.secondaryAccent, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.lock,
                size: 40,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adminLoginTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminLoginEnterPin,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryAccent,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (showBiometric) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _tryBiometricLogin(auto: false),
                  icon: const Icon(LucideIcons.fingerprint, size: 20),
                  label: Text(
                    _biometricButtonLabel.isEmpty
                        ? l10n.biometricUseGeneric
                        : _biometricButtonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(
                      color: AppColors.primaryDark,
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: !showBiometric,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '• • • • •',
                hintStyle: TextStyle(
                  color: AppColors.secondaryAccent.withValues(alpha: 0.5),
                  letterSpacing: 8,
                ),
                errorText: _errorText,
                errorStyle: const TextStyle(fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryDark,
                    width: 3,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: AppColors.secondaryAccent,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submitPin(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primaryDark,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.cancelBtn,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.adminLoginBtn,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
