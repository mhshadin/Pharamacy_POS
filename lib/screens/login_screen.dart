import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';
import '../utils/api_error_mapper.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../services/google_drive_auth.dart';
import '../services/google_oauth_desktop.dart';
import 'home_screen.dart';
import 'subscription_screen.dart';
import '../providers/admin_provider.dart';
import 'package:provider/provider.dart';

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
  bool _obscurePassword = true;
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
      final result = await _authService.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        hardwareUid: hardwareUid,
      );

      await _authStorage.saveAuth(result);

      if (!mounted) return;

      Widget nextScreen;
      if (result.subscriptionStatus == 'active') {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = SubscriptionScreen(
          pharmacyId: result.userId,
          isDismissible: true,
        );
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
    } on AuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forLogin(e));
    } catch (e) {
      _showErrorSnackBar('Login failed. Please try again.');
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

    setState(() {
      _isRegistering = true;
    });

    try {
      final hardwareUid = await _authStorage.getOrCreateHardwareUid();
      final result = await _authService.registerLocal(
        email: _regEmailController.text,
        password: _regPasswordController.text,
        fullName: _regFullNameController.text,
        businessName: _regBusinessNameController.text,
        hardwareUid: hardwareUid,
      );

      await _authStorage.saveAuth(result);

      if (!mounted) return;

      // After registration, always show subscription screen or trial info
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            pharmacyId: result.userId,
            isDismissible: true,
          ),
        ),
      );
    } on AuthException catch (e) {
      _showErrorSnackBar(ApiErrorMapper.forRegistration(e));
    } catch (e) {
      _showErrorSnackBar('Registration failed. Please try again.');
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

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      print("DEBUG: Google Login starting...");
      String idToken;
      String? accessToken;

      if (Platform.isWindows) {
        print("DEBUG: Using Windows PKCE Flow...");
        final tokens = await signInWithGoogleDesktop();
        idToken = tokens.idToken;
        accessToken = tokens.accessToken;
      } else {
        print("DEBUG: Triggering native Google Sign-In...");
        final account = await _googleSignIn.signIn();
        if (account == null) {
          print("DEBUG: Google Sign-In interaction CANCELED by user.");
          if (mounted) {
            setState(() {
              _isGoogleLoading = false;
            });
          }
          return;
        }

        print("DEBUG: User selected account: ${account.email}");
        final auth = await account.authentication;
        idToken = auth.idToken ?? '';
        accessToken = auth.accessToken;

        print(
          "DEBUG: Retrieved idToken (len: ${idToken.length}), accessToken (len: ${accessToken?.length ?? 0})",
        );

        if (idToken.isEmpty) {
          print("DEBUG ERROR: Google ID token is EMPTY.");
          _showErrorSnackBar('Unable to get Google ID token.');
          return;
        }
      }

      final hardwareUid = await _authStorage.getOrCreateHardwareUid();
      print("DEBUG: Hardware UID: $hardwareUid");

      print("DEBUG: Sending tokens to backend...");
      final result = await _authService.loginWithGoogle(
        idToken: idToken,
        hardwareUid: hardwareUid,
      );

      print("DEBUG: Backend Login successful for user: ${result.userName}");
      await _authStorage.saveAuth(result, googleAccessToken: accessToken);

      if (mounted) {
        print("DEBUG: Triggering database restore from Drive...");
        await context.read<AdminProvider>().checkAndRestoreFromDrive();
      }

      if (!mounted) return;

      Widget nextScreen;
      if (result.subscriptionStatus == 'active') {
        nextScreen = const HomeScreen();
      } else {
        nextScreen = SubscriptionScreen(
          pharmacyId: result.userId,
          isDismissible: true,
        );
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
    } on GoogleDesktopAuthCancelled {
      print("DEBUG: Google Desktop Auth Cancelled.");
    } on GoogleDesktopAuthException catch (e) {
      print("DEBUG ERROR: Google Desktop Auth Exception: ${e.message}");
      _showErrorSnackBar(ApiErrorMapper.forGoogleSignIn(e));
    } on AuthException catch (e) {
      print("DEBUG ERROR: Backend Auth Exception: $e");
      _showErrorSnackBar(ApiErrorMapper.forGoogleSignIn(e));
    } catch (e, stack) {
      print("DEBUG ERROR: Generic Google sign-in failure: $e");
      print(stack);
      if (e.toString().contains('sign_in_canceled')) {
        return;
      }
      _showErrorSnackBar('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
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
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.interTextTheme(theme.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pharmacy POS',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to start selling',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.primaryDark,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryDark,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Sign in',
                                          style: TextStyle(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isGoogleLoading
                                      ? null
                                      : _handleGoogleLogin,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.cardBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    foregroundColor: AppColors.primaryDark,
                                  ),
                                  icon: const Icon(
                                    Icons.g_mobiledata,
                                    size: 28,
                                  ),
                                  label: _isGoogleLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.primaryDark,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.cardBorder,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Or create an account',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.cardBorder,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isRegistering
                              ? null
                              : () {
                                  _showRegisterDialog();
                                },
                          child: const Text(
                            'Create a new pharmacy account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
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
                        'Create Pharmacy Account',
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
                          label: 'Your full name',
                          icon: Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regBusinessNameController,
                        decoration: _inputDecoration(
                          label: 'Pharmacy / business name',
                          icon: Icons.storefront_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your business name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regEmailController,
                        decoration: _inputDecoration(
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regPasswordController,
                        obscureText: _regObscurePassword,
                        decoration: _inputDecoration(
                          label: 'Password (min 8 characters)',
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
                            return 'Please enter a password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regConfirmPasswordController,
                        obscureText: _regObscurePassword,
                        decoration: _inputDecoration(
                          label: 'Confirm password',
                          icon: Icons.lock_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _regPasswordController.text) {
                            return 'Passwords do not match';
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
                              child: const Text('Cancel'),
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
                                  : const Text(
                                      'Create account',
                                      style: TextStyle(
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
