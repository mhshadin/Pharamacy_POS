import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../utils/colors.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/time_service.dart';
import '../services/database_helper.dart';
import '../providers/admin_provider.dart';
import '../providers/pos_provider.dart';
import 'db_location_gate_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'subscription_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authStorage = const AuthStorage();
  final _authApi = const AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await DatabaseHelper().ensureDatabaseReady();
      if (!mounted) return;
      final admin = context.read<AdminProvider>();
      final pos = context.read<POSProvider>();
      await admin.loadData();
      await pos.loadProducts();
    } catch (e, st) {
      debugPrint('SplashScreen: database init failed: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const DbLocationGateScreen(),
        ),
      );
      return;
    }

    // Small delay so the splash is visible and storage can initialize.
    await Future.delayed(const Duration(milliseconds: 600));

    // Try to sync time at startup if online
    await TimeService().fetchServerTime();

    final session = await _authStorage.loadAuth();

    if (!mounted) return;

    if (session != null && session.hasValidToken) {
      final canContinue = await _validateSessionAtStartup(session);
      if (!mounted) return;

      if (!canContinue) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // Reload session so subscription check uses the freshly refreshed values.
      final freshSession = await _authStorage.loadAuth() ?? session;

      if (await _shouldBlockForExpiredSubscription(freshSession)) {
        _showSubscriptionBlockedDialog(freshSession.pharmacyId);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<bool> _validateSessionAtStartup(AuthSession session) async {
    if (session.refreshToken.isEmpty) {
      await _authStorage.clearAuth();
      return false;
    }

    try {
      final refreshed = await _authApi.refreshJwtToken(session.refreshToken);
      await _authStorage.saveAuth(
        refreshed,
        googleAccessToken: session.googleAccessToken,
      );
      return true;
    } on AuthException catch (e) {
      // Server explicitly rejected the token (invalid or revoked) — force re-login.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authStorage.clearAuth();
        return false;
      }
      // Server error (5xx) — treat same as offline, proceed with cached session.
      return true;
    } catch (_) {
      // Network failure, timeout, socket error — proceed with cached session.
      return true;
    }
  }

  Future<bool> _shouldBlockForExpiredSubscription(AuthSession session) async {
    final raw = session.subscriptionValidUntil.trim();
    if (raw.isEmpty) return false;
    final expiresAt = DateTime.tryParse(raw);
    if (expiresAt == null) return false;

    final reliableNow = await TimeService().getReliableNow();
    final dateExpired = expiresAt.isBefore(reliableNow);
    if (!dateExpired) return false;

    // Block if SharedPreferences says inactive OR if JWT claim says expired.
    // The JWT check catches tampering on rooted devices where SharedPreferences
    // values have been edited directly.
    final jwtExpired = _authStorage.isJwtSubscriptionExpired(
      session.licenseToken,
      reliableNow,
    );
    return !session.isActive || jwtExpired;
  }

  void _showSubscriptionBlockedDialog(String pharmacyId) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Subscription expired'),
            content: const Text(
              'Your subscription has expired. Renew now to continue using the app.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: const Text('Exit'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(
                        pharmacyId: pharmacyId,
                        isDismissible: false,
                      ),
                    ),
                  );
                },
                child: const Text('Renew'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Pharmacy POS',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.secondaryAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

