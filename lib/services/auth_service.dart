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
  });

  final String licenseToken;
  final String userId;
  final String userName;
  final String userRole;
  final String subscriptionStatus;
  final String subscriptionValidUntil;
}

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

class AuthService {
  const AuthService();

  Uri _buildUri(String endpoint) {
    return Uri.parse('$apiBaseUrl/$endpoint');
  }

  Map<String, String> _jsonHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
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
    print('[AuthService] POST $uri');
    print('[AuthService] Payload idToken length=${idToken.length}, hardwareUid=$hardwareUid');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'idToken': idToken,
        'hardware_uid': hardwareUid,
      }),
    );

    print('[AuthService] Response status=${response.statusCode} body=${response.body}');
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
      body: jsonEncode({
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw _buildException(response);
    }
  }

  AuthResult _handleAuthResponse(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('[AuthService] Non-success status=${response.statusCode} body=${response.body}');
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
      userRole: (user['role'] ?? '').toString(),
      subscriptionStatus: (subscription['status'] ?? '').toString(),
      subscriptionValidUntil: (subscription['valid_until'] ?? '').toString(),
    );
  }

  AuthException _buildException(http.Response response) {
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final message = (data['error'] ?? data['message'] ?? 'Authentication failed.')
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

