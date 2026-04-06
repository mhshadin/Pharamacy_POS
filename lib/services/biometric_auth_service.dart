import 'package:local_auth/local_auth.dart';

enum BiometricAuthFailureReason {
  notEnrolled,
  notAvailable,
  lockedOut,
  temporaryLockout,
  canceled,
  unknown,
}

class BiometricAuthResult {
  const BiometricAuthResult._({
    required this.success,
    this.reason,
  });

  const BiometricAuthResult.success() : this._(success: true);

  const BiometricAuthResult.failure(BiometricAuthFailureReason reason)
      : this._(success: false, reason: reason);

  final bool success;
  final BiometricAuthFailureReason? reason;
}

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
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
  }) async {
    try {
      final ok = await _local.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      return ok
          ? const BiometricAuthResult.success()
          : const BiometricAuthResult.failure(
              BiometricAuthFailureReason.canceled,
            );
    } on LocalAuthException catch (e) {
      return BiometricAuthResult.failure(_mapExceptionToReason(e.code));
    }
  }

  BiometricAuthFailureReason _mapExceptionToReason(
    LocalAuthExceptionCode code,
  ) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return BiometricAuthFailureReason.notEnrolled;
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
        return BiometricAuthFailureReason.notAvailable;
      case LocalAuthExceptionCode.biometricLockout:
        return BiometricAuthFailureReason.lockedOut;
      case LocalAuthExceptionCode.temporaryLockout:
        return BiometricAuthFailureReason.temporaryLockout;
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.userRequestedFallback:
      case LocalAuthExceptionCode.authInProgress:
        return BiometricAuthFailureReason.canceled;
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return BiometricAuthFailureReason.unknown;
    }
  }
}
