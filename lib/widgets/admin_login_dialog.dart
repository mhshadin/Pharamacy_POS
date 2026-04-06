import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../utils/colors.dart';
import '../providers/admin_provider.dart';
import '../providers/language_provider.dart';
import '../services/biometric_auth_service.dart';
import '../services/auth_service.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController = TextEditingController();
  String? _errorText;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmNewPin = true;
  bool _isSubmitting = false;
  bool _biometricReady = false;
  bool _biometricChecked = false;
  String _biometricButtonLabel = '';
  bool _resetMode = false;
  bool _otpSent = false;

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
    final result = await BiometricAuthService.instance.authenticate(
      localizedReason: l10n.biometricUnlockReason,
    );
    if (!mounted) return;
    if (result.success) {
      context.read<AdminProvider>().completeBiometricLogin();
      Navigator.pop(context, true);
    } else if (!auto) {
      final reason = result.reason ?? BiometricAuthFailureReason.unknown;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _messageForFailure(reason),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _otpController.dispose();
    _newPinController.dispose();
    _confirmNewPinController.dispose();
    super.dispose();
  }

  void _enterResetMode() {
    setState(() {
      _resetMode = true;
      _otpSent = false;
      _errorText = null;
      _pinController.clear();
      _confirmPinController.clear();
      _otpController.clear();
      _newPinController.clear();
      _confirmNewPinController.clear();
    });
  }

  void _exitResetMode() {
    setState(() {
      _resetMode = false;
      _otpSent = false;
      _errorText = null;
      _otpController.clear();
      _newPinController.clear();
      _confirmNewPinController.clear();
    });
  }

  Future<void> _sendOtp() async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    final email = admin.authSession?.userEmail ?? '';

    if (email.isEmpty) {
      setState(() => _errorText = l10n.validationEnterEmail);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await const AuthService().requestAdminPinResetOtp(email: email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your email.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitReset() async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    final email = admin.authSession?.userEmail ?? '';
    final otp = _otpController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmNewPin = _confirmNewPinController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorText = l10n.validationEnterEmail);
      return;
    }
    if (otp.isEmpty) {
      setState(() => _errorText = 'Please enter the OTP.');
      return;
    }
    if (newPin.isEmpty) {
      setState(() => _errorText = l10n.adminLoginPinEmpty);
      return;
    }
    if (newPin.length < 4) {
      setState(() => _errorText = l10n.minFourDigits);
      return;
    }
    if (confirmNewPin != newPin) {
      setState(() => _errorText = l10n.pinsDoNotMatch);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await const AuthService().resetAdminPinWithOtp(
        email: email,
        otp: otp,
        newPin: newPin,
      );

      // Refresh local pin cache + login
      await admin.fetchBackendAdminPin();
      if (!mounted) return;

      final ok = admin.login(newPin);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _errorText = l10n.adminLoginWrongPin);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPin() async {
    final l10n = context.read<LanguageProvider>().strings;
    final pin = _pinController.text.trim();
    final admin = context.read<AdminProvider>();
    final isPinSet = admin.isAdminPinSet;

    if (pin.isEmpty) {
      setState(() => _errorText = l10n.adminLoginPinEmpty);
      return;
    }

    if (isPinSet) {
      if (admin.login(pin)) {
        Navigator.pop(context, true);
      } else {
        setState(() => _errorText = l10n.adminLoginWrongPin);
        _pinController.clear();
      }
      return;
    }

    if (pin.length < 4) {
      setState(() => _errorText = l10n.minFourDigits);
      return;
    }

    final confirm = _confirmPinController.text.trim();
    if (confirm != pin) {
      setState(() => _errorText = l10n.pinsDoNotMatch);
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      await admin.setupAdminPin(pin);
      if (!mounted) return;
      admin.login(pin);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '${l10n.adminPinSetupFailed} ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;
    final admin = context.watch<AdminProvider>();
    final isPinSet = admin.isAdminPinSet;
    final email = admin.authSession?.userEmail ?? '';
    final showBiometric =
        isPinSet &&
        admin.adminBiometricEnabled &&
        _biometricChecked &&
        _biometricReady;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.secondaryAccent, width: 3),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
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
              _resetMode
                  ? 'Reset admin PIN'
                  : (isPinSet ? l10n.adminLoginTitle : l10n.adminPinSetupTitle),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _resetMode
                  ? (email.isEmpty
                      ? 'Enter the OTP sent to your email and set a new PIN.'
                      : 'Enter the OTP sent to $email and set a new PIN.')
                  : (isPinSet
                      ? l10n.adminLoginEnterPin
                      : l10n.adminPinSetupSubtitle),
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
            if (!_resetMode) ...[
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
                  hintText: isPinSet ? '• • • • •' : '• • • •',
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
              if (!isPinSet) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  obscureText: _obscureConfirm,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '• • • •',
                    hintStyle: TextStyle(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.5),
                      letterSpacing: 8,
                    ),
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
                        _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: AppColors.secondaryAccent,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  onSubmitted: (_) => _submitPin(),
                ),
              ],
              if (isPinSet) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _enterResetMode,
                    child: const Text('Forgot PIN?'),
                  ),
                ),
              ],
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  letterSpacing: 6,
                ),
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(
                    color: AppColors.secondaryAccent.withValues(alpha: 0.5),
                    letterSpacing: 6,
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
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _sendOtp,
                  child: Text(_otpSent ? 'Resend OTP' : 'Send OTP'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPinController,
                obscureText: _obscureNewPin,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'New PIN',
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
                      _obscureNewPin ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: AppColors.secondaryAccent,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewPin = !_obscureNewPin),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmNewPinController,
                obscureText: _obscureConfirmNewPin,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'Confirm PIN',
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
                      _obscureConfirmNewPin
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      color: AppColors.secondaryAccent,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmNewPin = !_obscureConfirmNewPin,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submitReset(),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetMode ? _exitResetMode : () => Navigator.pop(context, false),
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
                      _resetMode ? 'Back' : l10n.cancelBtn,
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
                    onPressed: _isSubmitting ? null : (_resetMode ? _submitReset : _submitPin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _resetMode
                          ? 'Reset PIN'
                          : (isPinSet ? l10n.adminLoginBtn : l10n.adminPinSetupBtn),
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
      ),
    );
  }
}
