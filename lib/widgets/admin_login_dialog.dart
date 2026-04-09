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

enum _ResetMethod { otp, password }

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmNewPinController =
      TextEditingController();
  final TextEditingController _accountPasswordController =
      TextEditingController();
  String? _errorText;
  String? _otpErrorText;
  String? _passwordResetErrorText;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmNewPin = true;
  bool _obscureAccountPassword = true;
  bool _isSubmitting = false;
  bool _biometricReady = false;
  bool _biometricChecked = false;
  String _biometricButtonLabel = '';
  bool _resetMode = false;
  bool _otpSent = false;
  _ResetMethod _resetMethod = _ResetMethod.otp;

  String _normalizePin(String pin) {
    final buffer = StringBuffer();
    for (final codePoint in pin.runes) {
      if (codePoint >= 0x09E6 && codePoint <= 0x09EF) {
        buffer.writeCharCode(0x30 + (codePoint - 0x09E6));
        continue;
      }
      if (codePoint >= 0x0660 && codePoint <= 0x0669) {
        buffer.writeCharCode(0x30 + (codePoint - 0x0660));
        continue;
      }
      if (codePoint >= 0x06F0 && codePoint <= 0x06F9) {
        buffer.writeCharCode(0x30 + (codePoint - 0x06F0));
        continue;
      }
      buffer.writeCharCode(codePoint);
    }
    return buffer.toString().trim();
  }

  /// Shared look for secondary actions in this dialog (matches footer OutlinedButton).
  ButtonStyle _dialogOutlinedButtonStyle({required bool selected}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryDark,
      side: const BorderSide(color: AppColors.primaryDark, width: 2),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: selected
          ? AppColors.primaryDark.withValues(alpha: 0.08)
          : AppColors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
  }

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
    _accountPasswordController.dispose();
    super.dispose();
  }

  void _enterResetMode() {
    setState(() {
      _resetMode = true;
      _otpSent = false;
      _errorText = null;
      _otpErrorText = null;
      _passwordResetErrorText = null;
      _pinController.clear();
      _confirmPinController.clear();
      _otpController.clear();
      _newPinController.clear();
      _confirmNewPinController.clear();
      _accountPasswordController.clear();
      _resetMethod = _ResetMethod.otp;
    });
  }

  void _exitResetMode() {
    setState(() {
      _resetMode = false;
      _otpSent = false;
      _errorText = null;
      _otpErrorText = null;
      _passwordResetErrorText = null;
      _otpController.clear();
      _newPinController.clear();
      _confirmNewPinController.clear();
      _accountPasswordController.clear();
      _resetMethod = _ResetMethod.otp;
    });
  }

  void _selectResetMethod(_ResetMethod method) {
    setState(() {
      _resetMethod = method;
      _otpErrorText = null;
      _passwordResetErrorText = null;
    });
  }

  Future<void> _sendOtp() async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    final email = admin.authSession?.userEmail ?? '';

    if (email.isEmpty) {
      setState(() => _otpErrorText = l10n.validationEnterEmail);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _otpErrorText = null;
    });

    try {
      await const AuthService().requestAdminPinResetOtp(email: email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.otpSent),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _otpErrorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitReset() async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    final email = admin.authSession?.userEmail ?? '';
    final otp = _otpController.text.trim();
    final newPin = _normalizePin(_newPinController.text);
    final confirmNewPin = _normalizePin(_confirmNewPinController.text);

    if (email.isEmpty) {
      setState(() => _otpErrorText = l10n.validationEnterEmail);
      return;
    }
    if (otp.isEmpty) {
      setState(() => _otpErrorText = l10n.otpRequired);
      return;
    }
    if (newPin.isEmpty) {
      setState(() => _otpErrorText = l10n.adminLoginPinEmpty);
      return;
    }
    if (newPin.length < 4) {
      setState(() => _otpErrorText = l10n.minFourDigits);
      return;
    }
    if (confirmNewPin != newPin) {
      setState(() => _otpErrorText = l10n.pinsDoNotMatch);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _otpErrorText = null;
    });

    try {
      await const AuthService().verifyAdminPinOtp(email: email, otp: otp);
      await admin.setupAdminPin(newPin);
      if (!mounted) return;

      final ok = admin.login(newPin);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _otpErrorText = l10n.adminLoginWrongPin);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _otpErrorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPasswordReset() async {
    final l10n = context.read<LanguageProvider>().strings;
    final admin = context.read<AdminProvider>();
    final token = admin.authSession?.licenseToken ?? '';
    final password = _accountPasswordController.text;
    final newPin = _normalizePin(_newPinController.text);
    final confirmNewPin = _normalizePin(_confirmNewPinController.text);

    if (token.isEmpty) {
      setState(() => _passwordResetErrorText = l10n.adminPinSetupFailed);
      return;
    }
    if (password.trim().isEmpty) {
      setState(
        () => _passwordResetErrorText = l10n.passwordRequiredForPinReset,
      );
      return;
    }
    if (newPin.isEmpty) {
      setState(() => _passwordResetErrorText = l10n.adminLoginPinEmpty);
      return;
    }
    if (newPin.length < 4) {
      setState(() => _passwordResetErrorText = l10n.minFourDigits);
      return;
    }
    if (confirmNewPin != newPin) {
      setState(() => _passwordResetErrorText = l10n.pinsDoNotMatch);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _passwordResetErrorText = null;
    });

    try {
      await const AuthService().resetAdminPinWithPassword(
        token: token,
        password: password,
        newPin: newPin,
      );
      await admin.setupAdminPin(newPin);
      if (!mounted) return;

      final ok = admin.login(newPin);
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() => _passwordResetErrorText = l10n.adminLoginWrongPin);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _passwordResetErrorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPin() async {
    final l10n = context.read<LanguageProvider>().strings;
    final pin = _normalizePin(_pinController.text);
    final admin = context.read<AdminProvider>();
    final isPinSet = admin.isAdminPinSet;

    if (pin.isEmpty) {
      setState(() => _errorText = l10n.adminLoginPinEmpty);
      return;
    }

    if (isPinSet) {
      final success = admin.login(pin);
      if (success) {
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

    final confirm = _normalizePin(_confirmPinController.text);
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
      setState(
        () => _errorText = '${l10n.adminPinSetupFailed} ${e.toString()}',
      );
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
                    ? l10n.forgotPinTitle
                    : (isPinSet
                          ? l10n.adminLoginTitle
                          : l10n.adminPinSetupTitle),
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
                    ? (_resetMethod == _ResetMethod.otp
                          ? l10n.resetPinSubtitle(email)
                          : l10n.resetPinWithPasswordSubtitle)
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
                          _obscureConfirm
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
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
                      child: Text(l10n.forgotPin),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pinResetMethodTitle,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _selectResetMethod(_ResetMethod.otp),
                            style: _dialogOutlinedButtonStyle(
                              selected: _resetMethod == _ResetMethod.otp,
                            ),
                            child: Text(
                              l10n.resetWithOtp,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () =>
                                      _selectResetMethod(_ResetMethod.password),
                            style: _dialogOutlinedButtonStyle(
                              selected: _resetMethod == _ResetMethod.password,
                            ),
                            child: Text(
                              l10n.resetWithPassword,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_resetMethod == _ResetMethod.otp) ...[
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
                      errorText: _otpErrorText,
                      errorStyle: const TextStyle(fontWeight: FontWeight.bold),
                      labelText: l10n.enterOtpCode,
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
                      style: _dialogOutlinedButtonStyle(selected: false),
                      child: Text(_otpSent ? l10n.resendOtp : l10n.sendOtp),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _accountPasswordController,
                    obscureText: _obscureAccountPassword,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      errorText: _passwordResetErrorText,
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
                          _obscureAccountPassword
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          color: AppColors.secondaryAccent,
                        ),
                        onPressed: () => setState(
                          () => _obscureAccountPassword =
                              !_obscureAccountPassword,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    labelText: l10n.newPin,
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                    floatingLabelStyle: TextStyle(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    errorText: _resetMethod == _ResetMethod.password
                        ? _passwordResetErrorText
                        : null,
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
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    labelText: l10n.confirmPin,
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                    floatingLabelStyle: TextStyle(
                      color: AppColors.secondaryAccent.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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
                  onSubmitted: (_) => _resetMethod == _ResetMethod.otp
                      ? _submitReset()
                      : _submitPasswordReset(),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetMode
                          ? _exitResetMode
                          : () => Navigator.pop(context, false),
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
                        _resetMode ? l10n.wizardBack : l10n.cancelBtn,
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
                      onPressed: _isSubmitting
                          ? null
                          : (_resetMode
                                ? (_resetMethod == _ResetMethod.otp
                                      ? _submitReset
                                      : _submitPasswordReset)
                                : _submitPin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _resetMode
                            ? l10n.resetPin
                            : (isPinSet
                                  ? l10n.adminLoginBtn
                                  : l10n.adminPinSetupBtn),
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
