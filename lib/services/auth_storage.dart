import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AuthSession {
  AuthSession({
    required this.licenseToken,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.subscriptionStatus,
    required this.subscriptionValidUntil,
  });

  final String licenseToken;
  final String userId;
  final String userName;
  final String userRole;
  final String subscriptionStatus;
  final String subscriptionValidUntil;

  bool get hasValidToken => licenseToken.isNotEmpty;
}

class AuthStorage {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'auth_user_id';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserRole = 'auth_user_role';
  static const _keySubStatus = 'auth_sub_status';
  static const _keySubValidUntil = 'auth_sub_valid_until';
  static const _keyHardwareUid = 'hardware_uid';

  const AuthStorage();

  Future<void> saveAuth(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, result.licenseToken);
    await prefs.setString(_keyUserId, result.userId);
    await prefs.setString(_keyUserName, result.userName);
    await prefs.setString(_keyUserRole, result.userRole);
    await prefs.setString(_keySubStatus, result.subscriptionStatus);
    await prefs.setString(_keySubValidUntil, result.subscriptionValidUntil);
  }

  Future<AuthSession?> loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken) ?? '';
    if (token.isEmpty) return null;

    return AuthSession(
      licenseToken: token,
      userId: prefs.getString(_keyUserId) ?? '',
      userName: prefs.getString(_keyUserName) ?? '',
      userRole: prefs.getString(_keyUserRole) ?? '',
      subscriptionStatus: prefs.getString(_keySubStatus) ?? '',
      subscriptionValidUntil: prefs.getString(_keySubValidUntil) ?? '',
    );
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keySubStatus);
    await prefs.remove(_keySubValidUntil);
  }

  Future<String> getOrCreateHardwareUid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyHardwareUid);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    // Simple random-like UID based on DateTime + random number.
    // You can replace this with a more robust device identifier if needed.
    final now = DateTime.now().microsecondsSinceEpoch;
    final generated = 'device_$now';
    await prefs.setString(_keyHardwareUid, generated);
    return generated;
  }
}

