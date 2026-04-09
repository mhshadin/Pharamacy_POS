import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../utils/colors.dart';
import '../utils/api_error_mapper.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../services/device_info_service.dart';
import '../services/google_drive_auth.dart';
import '../services/google_oauth_desktop.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'subscription_screen.dart';
import '../providers/admin_provider.dart';
import '../providers/language_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _regFullNameController = TextEditingController();
  final _regBusinessNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _authService = const AuthService();
  final _authStorage = const AuthStorage();

  bool _isLoading = false;
  bool _isRegistering = false;
  bool _isGoogleLoading = false;
  bool _regObscurePassword = true;

  // Use the shared instance so interactive login and background Drive sync
  // share the same GoogleSignIn session (required for signInSilently to work).
  final _googleSignIn = googleSignInClient;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regFullNameController.dispose();
    _regBusinessNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final hardwareUid = await _authStorage.getOrCreateHardwareUid();
      final dev = await DeviceInfoService.getDescriptor();
      final result = await _authService.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        hardwareUid: hardwareUid,
        deviceModel: dev.model,
        deviceDisplayName: dev.displayName,
      );

      await _authStorage.saveAuth(result);
      await context.read<AdminProvider>().reloadAuthSession();

      if (mounted) {
        await _showRestoreSourcePrompt();
      }

      if (!mounted) return;

      Widget nextScreen;
      if (result.subscriptionStatus == 'active') {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = SubscriptionScreen(
          pharmacyId: result.pharmacyId,
          isDismissible: false,
        );
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
    } on AuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forLogin(e));
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final l10n = context.read<LanguageProvider>().strings;
    setState(() {
      _isRegistering = true;
    });

    try {
      final hardwareUid = await _authStorage.getOrCreateHardwareUid();
      final dev = await DeviceInfoService.getDescriptor();
      final result = await _authService.registerLocal(
        email: _regEmailController.text,
        password: _regPasswordController.text,
        fullName: _regFullNameController.text,
        businessName: _regBusinessNameController.text,
        hardwareUid: hardwareUid,
        deviceModel: dev.model,
        deviceDisplayName: dev.displayName,
      );

      await _authStorage.saveAuth(result);
      await context.read<AdminProvider>().reloadAuthSession();

      if (mounted) {
        await _showRestoreSourcePrompt();
      }

      if (!mounted) return;

      // After registration, always show subscription screen or trial info
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            pharmacyId: result.pharmacyId,
            isDismissible: false,
          ),
        ),
      );
    } on AuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forRegistration(e));
    } catch (e) {
      _showErrorSnackBar(l10n.registrationFailed);
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;

    final l10n = context.read<LanguageProvider>().strings;
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      String idToken;
      String? accessToken;

      if (Platform.isWindows) {
        final tokens = await signInWithGoogleDesktop();
        idToken = tokens.idToken;
        accessToken = tokens.accessToken;
      } else {
        final account = await _googleSignIn.signIn();
        if (account == null) {
          if (mounted) {
            setState(() {
              _isGoogleLoading = false;
            });
          }
          return;
        }

        final auth = await account.authentication;
        idToken = auth.idToken ?? '';
        accessToken = auth.accessToken;

        if (idToken.isEmpty) {
          _showErrorSnackBar(l10n.googleIdTokenError);
          return;
        }
      }

      final hardwareUid = await _authStorage.getOrCreateHardwareUid();
      final dev = await DeviceInfoService.getDescriptor();

      final result = await _authService.loginWithGoogle(
        idToken: idToken,
        hardwareUid: hardwareUid,
        deviceModel: dev.model,
        deviceDisplayName: dev.displayName,
      );

      await _authStorage.saveAuth(result, googleAccessToken: accessToken);
      await context.read<AdminProvider>().reloadAuthSession();

      if (mounted) {
        await _showRestoreSourcePrompt();
      }

      if (!mounted) return;

      Widget nextScreen;
      if (result.subscriptionStatus == 'active') {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = SubscriptionScreen(
          pharmacyId: result.pharmacyId,
          isDismissible: false,
        );
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
    } on GoogleDesktopAuthCancelled {
      // Ignored
    } on GoogleDesktopAuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forGoogleSignIn(e));
    } on AuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forGoogleSignIn(e));
    } catch (e) {
      if (e.toString().contains('sign_in_canceled')) {
        return;
      }
      _showErrorSnackBar(l10n.googleSignInFailed);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _showRestoreSourcePrompt() async {
    if (!mounted) return;
    final l10n = context.read<LanguageProvider>().strings;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text('Choose where to restore your database from.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('skip'),
              child: Text(l10n.cancelBtn),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('local'),
              child: const Text('Local File'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('drive'),
              child: const Text('Google Drive'),
            ),
          ],
        );
      },
    );

    if (!mounted || choice == null || choice == 'skip') return;
    if (choice == 'local') {
      await _restoreFromLocalFile();
      return;
    }
    await _restoreFromGoogleDriveWithAuth();
  }

  Future<void> _restoreFromLocalFile() async {
    if (!mounted) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    try {
      await context.read<AdminProvider>().importDatabaseLocally(
        result.files.single.path!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored from local backup.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Local restore failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _restoreFromGoogleDriveWithAuth() async {
    if (!mounted) return;
    final admin = context.read<AdminProvider>();
    await admin.reloadAuthSession();
    var session = admin.authSession;

    if (session?.googleAccessToken == null || session!.googleAccessToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in with Gmail to restore from Google Drive.'),
          backgroundColor: AppColors.error,
        ),
      );

      String? accessToken;
      if (Platform.isWindows) {
        try {
          final tokens = await signInWithGoogleDesktop();
          accessToken = tokens.accessToken;
        } on GoogleDesktopAuthCancelled {
          return;
        }
      } else {
        final account = await _googleSignIn.signIn();
        if (account == null) return;
        final auth = await account.authentication;
        accessToken = auth.accessToken;
      }

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google login did not return a Drive token.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await _authStorage.setGoogleAccessToken(accessToken);
      await admin.reloadAuthSession();
      session = admin.authSession;
    }

    final restored = await admin.checkAndRestoreFromDrive();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Database restored from Google Drive.'
              : 'No Google Drive backup file found.',
        ),
        backgroundColor: restored ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.primaryDark)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // App Icon & Name
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_pharmacy_rounded,
                        size: 64,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.appName,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.signInToStart,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.validationEnterEmail;
                        }
                        if (!value.contains('@')) {
                          return l10n.validationValidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.validationEnterPassword;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                l10n.signInBtn,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.orCreateAccount,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                      icon: Image.network(
                        'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                        height: 24,
                      ),
                      label: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryDark,
                                ),
                              ),
                            )
                          : Text(
                              l10n.continueWithGoogle,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isRegistering
                          ? null
                          : () {
                              _showRegisterDialog();
                            },
                      child: Text(
                        l10n.createPharmacyAccount,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    final l10n = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      barrierDismissible: !_isRegistering,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return SingleChildScrollView(
                child: Form(
                  key: _registerFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.createPharmacyAccount,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regFullNameController,
                        decoration: _inputDecoration(
                          label: l10n.fullNameLabel,
                          icon: Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationEnterName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regBusinessNameController,
                        decoration: _inputDecoration(
                          label: l10n.pharmacyNameLabel,
                          icon: Icons.storefront_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationEnterBusiness;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regEmailController,
                        decoration: _inputDecoration(
                          label: l10n.emailLabel,
                          icon: Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.validationEnterEmail;
                          }
                          if (!value.contains('@')) {
                            return l10n.validationValidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regPasswordController,
                        obscureText: _regObscurePassword,
                        decoration: _inputDecoration(
                          label: l10n.passwordMinChars,
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _regObscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.primaryDark,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                _regObscurePassword = !_regObscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.validationEnterPassword;
                          }
                          if (value.length < 8) {
                            return l10n.validationPasswordMin;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regConfirmPasswordController,
                        obscureText: _regObscurePassword,
                        decoration: _inputDecoration(
                          label: l10n.confirmPasswordLabel,
                          icon: Icons.lock_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.validationConfirmPassword;
                          }
                          if (value != _regPasswordController.text) {
                            return l10n.validationPasswordsNoMatch;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isRegistering
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isRegistering
                                  ? null
                                  : () async {
                                      await _handleRegister();
                                      if (dialogContext.mounted &&
                                          Navigator.of(
                                            dialogContext,
                                          ).canPop() &&
                                          !_isRegistering) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                              ),
                              child: _isRegistering
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      l10n.createAccount,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
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
            },
          ),
        );
      },
    );
  }
}
