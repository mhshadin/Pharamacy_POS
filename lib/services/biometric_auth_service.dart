import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] for admin unlock and settings toggles.
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  final LocalAuthentication _local = LocalAuthentication();

  /// Device supports biometrics and the user has at least one enrolled.
  Future<bool> isReadyForUse() async {
    if (!await _local.isDeviceSupported()) return false;
    if (!await _local.canCheckBiometrics) return false;
    final types = await _local.getAvailableBiometrics();
    return types.isNotEmpty;
  }

  Future<List<BiometricType>> getEnrolledTypes() =>
      _local.getAvailableBiometrics();

  /// Strong biometric only (no device PIN/pattern fallback).
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _local.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
