import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_service.dart';
import 'device_info_service.dart';

class AuthSession {
  AuthSession({
    required this.licenseToken,
    required this.pharmacyId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.subscriptionStatus,
    required this.subscriptionValidUntil,
    required this.planName,
    this.subscriptionTotalPlanDays,
    required this.userEmail,
    required this.refreshToken,
    this.googleAccessToken,
    this.userAvatarUrl,
    this.localProfileImagePath,
    this.phoneNumber,
    required this.isActive,
    this.isActiveSeller = true,
  });

  final String licenseToken;
  final String refreshToken;
  final String pharmacyId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String subscriptionStatus;
  final String subscriptionValidUntil;
  final String planName;
  final int? subscriptionTotalPlanDays;
  final String? googleAccessToken;
  final String? userAvatarUrl;
  final String? localProfileImagePath;
  final String? phoneNumber;
  final bool isActive;
  final bool isActiveSeller;

  bool get hasValidToken => licenseToken.isNotEmpty;
}

class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyPharmacyId = 'auth_pharmacy_id';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserRole = 'auth_user_role';
  static const _keySubStatus = 'auth_sub_status';
  static const _keySubValidUntil = 'auth_sub_valid_until';
  static const _keyPlanName = 'auth_plan_name';
  static const _keySubTotalPlanDays = 'auth_sub_total_plan_days';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyHardwareUid = 'hardware_uid';
  static const _keyGoogleAccessToken = 'auth_google_access_token';
  static const _keyUserAvatarUrl = 'auth_user_avatar_url';
  static const _keyLocalProfileImagePath = 'auth_local_profile_image_path';
  static const _keyPhoneNumber = 'auth_phone_number';
  static const _keyUserIsActive = 'auth_user_is_active';
  static const _keyIsActiveSeller = 'auth_is_active_seller';
  static const _keyLegacyLocalAdminPin = 'local_admin_pin';
  static const _securePinPrefix = 'local_admin_pin_v1';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  const AuthStorage();

  String _buildPinKey({required String userId, required String userEmail}) {
    final safeUserId = userId.trim().toLowerCase();
    final safeEmail = userEmail.trim().toLowerCase();
    return '$_securePinPrefix:$safeUserId:$safeEmail';
  }

  Future<void> saveAuth(AuthResult result, {String? googleAccessToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, result.licenseToken);
    await prefs.setString(_keyUserId, result.userId);
    await prefs.setString(_keyPharmacyId, result.pharmacyId);
    await prefs.setString(_keyRefreshToken, result.refreshToken);
    await prefs.setString(_keyUserName, result.userName);
    await prefs.setString(_keyUserEmail, result.userEmail);
    await prefs.setString(_keyUserRole, result.userRole);
    await prefs.setString(_keySubStatus, result.subscriptionStatus);
    await prefs.setString(_keySubValidUntil, result.subscriptionValidUntil);
    await prefs.setString(_keyPlanName, result.planName);
    final totalPlanDays = result.subscriptionTotalPlanDays;
    if (totalPlanDays != null) {
      await prefs.setInt(_keySubTotalPlanDays, totalPlanDays);
    } else {
      await prefs.remove(_keySubTotalPlanDays);
    }
    if (googleAccessToken != null && googleAccessToken.isNotEmpty) {
      await prefs.setString(_keyGoogleAccessToken, googleAccessToken);
    } else {
      // Avoid carrying a stale Drive token across non-Google logins/accounts.
      await prefs.remove(_keyGoogleAccessToken);
    }
    if (result.userAvatarUrl != null) {
      await prefs.setString(_keyUserAvatarUrl, result.userAvatarUrl!);
    }
    if (result.userPhoneNumber != null) {
      await prefs.setString(_keyPhoneNumber, result.userPhoneNumber!);
    } else {
      await prefs.remove(_keyPhoneNumber);
    }
    await prefs.setBool(_keyUserIsActive, result.isActive);
    await prefs.setBool(_keyIsActiveSeller, result.isActiveSeller);
  }

  Future<AuthSession?> loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken) ?? '';
    if (token.isEmpty) return null;

    return AuthSession(
      licenseToken: token,
      pharmacyId: prefs.getString(_keyPharmacyId) ?? '',
      userId: prefs.getString(_keyUserId) ?? '',
      refreshToken: prefs.getString(_keyRefreshToken) ?? '',
      userName: prefs.getString(_keyUserName) ?? '',
      userEmail: prefs.getString(_keyUserEmail) ?? '',
      userRole: prefs.getString(_keyUserRole) ?? '',
      subscriptionStatus: prefs.getString(_keySubStatus) ?? '',
      subscriptionValidUntil: prefs.getString(_keySubValidUntil) ?? '',
      planName: prefs.getString(_keyPlanName) ?? 'N/A',
      subscriptionTotalPlanDays: prefs.getInt(_keySubTotalPlanDays),
      googleAccessToken: prefs.getString(_keyGoogleAccessToken),
      userAvatarUrl: prefs.getString(_keyUserAvatarUrl),
      localProfileImagePath: prefs.getString(_keyLocalProfileImagePath),
      phoneNumber: prefs.getString(_keyPhoneNumber),
      isActive: prefs.getBool(_keyUserIsActive) ?? true,
      isActiveSeller: prefs.getBool(_keyIsActiveSeller) ?? true,
    );
  }

  /// Updates only the stored Google access token without touching other fields.
  Future<void> setGoogleAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleAccessToken, token);
  }

  Future<void> setActiveSeller(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsActiveSeller, value);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyPharmacyId);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keySubStatus);
    await prefs.remove(_keySubValidUntil);
    await prefs.remove(_keyPlanName);
    await prefs.remove(_keySubTotalPlanDays);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyGoogleAccessToken);
    await prefs.remove(_keyUserAvatarUrl);
    await prefs.remove(_keyLocalProfileImagePath);
    await prefs.remove(_keyPhoneNumber);
    await prefs.remove(_keyUserIsActive);
    await prefs.remove(_keyIsActiveSeller);
    // Keep device-local admin PIN intentionally. It is scoped per account key.
  }

  /// Persists only updated profile basics without touching other session fields.
  Future<void> updateNameAndAvatar(
    String name, {
    String? avatarUrl,
    String? phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    if (avatarUrl != null) {
      await prefs.setString(_keyUserAvatarUrl, avatarUrl);
    } else {
      await prefs.remove(_keyUserAvatarUrl);
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      await prefs.setString(_keyPhoneNumber, phoneNumber);
    } else {
      await prefs.remove(_keyPhoneNumber);
    }
  }

  Future<void> setLocalProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalProfileImagePath, path);
  }

  Future<void> clearLocalProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocalProfileImagePath);
  }

  Future<String> getOrCreateHardwareUid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyHardwareUid);
    if (existing != null && existing.isNotEmpty && !existing.startsWith('device_')) {
      return existing;
    }

    // One-time migration: legacy timestamp IDs ("device_*") -> OS-stable ID.
    final stableUid = await DeviceInfoService.resolveStableHardwareUid();
    await prefs.setString(_keyHardwareUid, stableUid);
    return stableUid;
  }

  Future<void> setLocalAdminPin({
    required String userId,
    required String userEmail,
    required String pin,
  }) async {
    final key = _buildPinKey(userId: userId, userEmail: userEmail);
    await _secureStorage.write(key: key, value: pin);
  }

  Future<String?> getLocalAdminPin({
    required String userId,
    required String userEmail,
  }) async {
    final key = _buildPinKey(userId: userId, userEmail: userEmail);
    return _secureStorage.read(key: key);
  }

  Future<void> clearLocalAdminPin({
    required String userId,
    required String userEmail,
  }) async {
    final key = _buildPinKey(userId: userId, userEmail: userEmail);
    await _secureStorage.delete(key: key);
  }

  Future<void> migrateLegacyAdminPinIfNeeded({
    required String userId,
    required String userEmail,
    required String? legacyPin,
  }) async {
    if (legacyPin == null || legacyPin.isEmpty) return;
    final key = _buildPinKey(userId: userId, userEmail: userEmail);
    final existing = await _secureStorage.read(key: key);
    if (existing == null || existing.isEmpty) {
      await _secureStorage.write(key: key, value: legacyPin);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLegacyLocalAdminPin);
  }
}

