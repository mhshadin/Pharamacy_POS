import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/colors.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/time_service.dart';
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
    // Small delay so the splash is visible and storage can initialize.
    await Future.delayed(const Duration(milliseconds: 600));

    dev.log('[SplashAuth] Bootstrap started', name: 'SplashAuth');

    // Try to sync time at startup if online
    await TimeService().fetchServerTime();

    final session = await _authStorage.loadAuth();

    dev.log(
      '[SplashAuth] Session loaded: '
      'hasToken=${session?.hasValidToken}, '
      'userId=${session?.userId}, '
      'email=${session?.userEmail}, '
      'hasRefreshToken=${session?.refreshToken.isNotEmpty}, '
      'isActive=${session?.isActive}, '
      'validUntil=${session?.subscriptionValidUntil}',
      name: 'SplashAuth',
    );

    if (!mounted) return;

    if (session != null && session.hasValidToken) {
      final canContinue = await _validateSessionAtStartup(session);
      if (!mounted) return;

      dev.log('[SplashAuth] canContinue=$canContinue', name: 'SplashAuth');

      if (!canContinue) {
        dev.log('[SplashAuth] -> LoginScreen (token rejected)', name: 'SplashAuth');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // Reload session so subscription check uses the freshly refreshed values.
      final freshSession = await _authStorage.loadAuth() ?? session;
      dev.log(
        '[SplashAuth] Fresh session after refresh: '
        'isActive=${freshSession.isActive}, '
        'validUntil=${freshSession.subscriptionValidUntil}, '
        'email=${freshSession.userEmail}',
        name: 'SplashAuth',
      );

      if (await _shouldBlockForExpiredSubscription(freshSession)) {
        dev.log('[SplashAuth] -> Subscription blocked dialog', name: 'SplashAuth');
        _showSubscriptionBlockedDialog(freshSession.pharmacyId);
        return;
      }
      if (!mounted) return;
      dev.log('[SplashAuth] -> HomeScreen', name: 'SplashAuth');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      dev.log('[SplashAuth] -> LoginScreen (no session)', name: 'SplashAuth');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<bool> _validateSessionAtStartup(AuthSession session) async {
    if (session.refreshToken.isEmpty) {
      dev.log('[SplashAuth] No refresh token stored — clearing auth', name: 'SplashAuth');
      await _authStorage.clearAuth();
      return false;
    }

    dev.log('[SplashAuth] Attempting token refresh...', name: 'SplashAuth');

    try {
      final refreshed = await _authApi.refreshJwtToken(session.refreshToken);
      await _authStorage.saveAuth(
        refreshed,
        googleAccessToken: session.googleAccessToken,
      );
      dev.log(
        '[SplashAuth] Token refresh SUCCESS: '
        'userId=${refreshed.userId}, '
        'email=${refreshed.userEmail}, '
        'isActive=${refreshed.isActive}, '
        'validUntil=${refreshed.subscriptionValidUntil}, '
        'hasNewRefreshToken=${refreshed.refreshToken.isNotEmpty}',
        name: 'SplashAuth',
      );
      return true;
    } on AuthException catch (e) {
      dev.log(
        '[SplashAuth] Token refresh REJECTED by server: '
        'status=${e.statusCode}, message=${e.message}',
        name: 'SplashAuth',
      );
      // Server explicitly rejected the token (invalid or revoked) — force re-login.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _authStorage.clearAuth();
        return false;
      }
      // Server error (5xx) — treat same as offline, proceed with cached session.
      return true;
    } catch (e) {
      dev.log(
        '[SplashAuth] Token refresh FAILED (offline/timeout): $e',
        name: 'SplashAuth',
      );
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

