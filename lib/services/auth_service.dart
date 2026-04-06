import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthResult {
  AuthResult({
    required this.licenseToken,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.subscriptionStatus,
    required this.subscriptionValidUntil,
    required this.planName,
    required this.userEmail,
    required this.refreshToken,
    this.userAvatarUrl,
    this.userPhoneNumber,
  });

  final String licenseToken;
  final String refreshToken;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String subscriptionStatus;
  final String subscriptionValidUntil;
  final String planName;
  final String? userAvatarUrl;
  final String? userPhoneNumber;
}

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

class AdminPinStatus {
  const AdminPinStatus({required this.isPinSet, this.adminPin});

  final bool isPinSet;
  final String? adminPin;
}

class AuthService {
  const AuthService();

  Uri _buildUri(String endpoint) {
    return Uri.parse('$apiBaseUrl/$endpoint');
  }

  Map<String, String> _jsonHeaders({String? token}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
    required String hardwareUid,
  }) async {
    final uri = _buildUri('local_login.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'hardware_uid': hardwareUid,
      }),
    );

    return _handleAuthResponse(response);
  }

  Future<AuthResult> loginWithGoogle({
    required String idToken,
    required String hardwareUid,
  }) async {
    final uri = _buildUri('google_login.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({'idToken': idToken, 'hardware_uid': hardwareUid}),
    );

    return _handleAuthResponse(response);
  }

  /// Refreshes the JWT license token using a valid refresh token.
  Future<AuthResult> refreshJwtToken(String refreshToken) async {
    final uri = _buildUri('refresh_token.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return _handleAuthResponse(response);
  }

  Future<AuthResult> registerLocal({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String hardwareUid,
  }) async {
    final uri = _buildUri('local_register.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'business_name': businessName.trim(),
        'hardware_uid': hardwareUid,
      }),
    );

    return _handleAuthResponse(response);
  }

  Future<void> setPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = _buildUri('set_password.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'new_password': newPassword}),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }
  }

  Future<AdminPinStatus> getAdminPinStatus(String token) async {
    final uri = _buildUri('admin_pin.php');
    final response = await http.get(uri, headers: _jsonHeaders(token: token));

    if (response.statusCode != 200) {
      throw _buildException(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final isPinSet = data['is_pin_set'] == true;
    final adminPin = data['admin_pin']?.toString();
    return AdminPinStatus(isPinSet: isPinSet, adminPin: adminPin);
  }

  Future<void> updateAdminPin({
    required String token,
    required String newPin,
  }) async {
    final uri = _buildUri('admin_pin.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'new_pin': newPin}),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }
  }

  Future<void> requestAdminPinResetOtp({required String email}) async {
    final uri = _buildUri('request_admin_pin_reset.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email.trim()}),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }
  }

  Future<void> resetAdminPinWithOtp({
    required String email,
    required String otp,
    required String newPin,
  }) async {
    final uri = _buildUri('reset_admin_pin_with_otp.php');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email.trim(),
        'otp': otp.trim(),
        'new_pin': newPin.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }
  }

  /// Updates the user's display name (and optionally avatar URL) on the backend.
  /// Returns a map with updated `name`, `avatar`, and `phone_number` keys on success.
  Future<Map<String, String?>> updateProfile({
    required String token,
    String? fullName,
    String? avatarUrl,
    String? phoneNumber,
  }) async {
    final uri = _buildUri('update_profile.php');
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;

    if (body.isEmpty) {
      throw AuthException('At least one profile field is required for update.');
    }

    final response = await http.post(
      uri,
      headers: _jsonHeaders(token: token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = (data['user'] as Map?) ?? {};
    return {
      'name': (user['name'] ?? '').toString(),
      'avatar': user['avatar']?.toString(),
      'phone_number': user['phone_number']?.toString(),
    };
  }

  AuthResult _handleAuthResponse(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildException(response);
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final token = data['license_token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException(
        'Missing license token in response.',
        statusCode: response.statusCode,
      );
    }

    final subscription = (data['subscription'] as Map?) ?? {};
    final user = (data['user'] as Map?) ?? {};

    return AuthResult(
      licenseToken: token,
      userId: (user['id'] ?? '').toString(),
      userName: (user['name'] ?? '').toString(),
      userEmail: (user['email'] ?? '').toString(),
      userRole: (user['role'] ?? '').toString(),
      subscriptionStatus: (subscription['status'] ?? '').toString(),
      subscriptionValidUntil: (subscription['valid_until'] ?? '').toString(),
      planName: (subscription['plan_name'] ?? 'N/A').toString(),
      refreshToken: (data['refresh_token'] ?? '').toString(),
      userAvatarUrl: user['avatar']?.toString(),
      userPhoneNumber: user['phone_number']?.toString(),
    );
  }

  AuthException _buildException(http.Response response) {
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final message =
          (data['error'] ?? data['message'] ?? 'Authentication failed.')
              .toString();
      return AuthException(message, statusCode: response.statusCode);
    } catch (_) {
      return AuthException(
        'Authentication failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }
}
