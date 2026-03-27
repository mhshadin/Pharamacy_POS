import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _kClientId =
    '1044506320101-uqu1sqihoq9sk5281q709fekvhtpjibt.apps.googleusercontent.com';
const _kRedirectPort = 43823;
const _kRedirectPath = '/oauth2redirect';
const _kRedirectUri = 'http://127.0.0.1:$_kRedirectPort$_kRedirectPath';
const _kOAuthCallbackTimeout = Duration(seconds: 45);
const _kDesktopClientSecretKey = 'google_desktop_client_secret';
const _kDesktopClientSecretFallback = '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';
const _secureStorage = FlutterSecureStorage();

class GoogleDesktopTokens {
  const GoogleDesktopTokens({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;
}

/// Launches a browser for Google OAuth (PKCE) and waits for the redirect on
/// a localhost HTTP server.  Returns id_token + access_token on success.
///
/// Throws a [GoogleDesktopAuthException] when the user cancels or an error
/// occurs.
Future<GoogleDesktopTokens> signInWithGoogleDesktop() async {
  final codeVerifier = _generateCodeVerifier();
  final codeChallenge = _generateCodeChallenge(codeVerifier);
  final state = _randomString(16);

  final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': _kClientId,
    'redirect_uri': _kRedirectUri,
    'response_type': 'code',
    'scope':
        'openid email profile https://www.googleapis.com/auth/drive.file',
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
    'access_type': 'online',
    'state': state,
    'prompt': 'select_account',
  });

  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _kRedirectPort);
  } on SocketException catch (_) {
    throw GoogleDesktopAuthException(
        'Could not start Google sign-in. Port $_kRedirectPort may be in use. Please close other apps and try again.');
  }

  final completer = Completer<Map<String, String>>();

  server.listen((HttpRequest request) async {
    if (request.uri.path != _kRedirectPath) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final params = request.uri.queryParameters;

    // Always respond to the browser first.
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_htmlCallback(error: params['error']))
      ..close();

    if (!completer.isCompleted) {
      completer.complete(Map<String, String>.from(params));
    }
  });

  if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
    await server.close(force: true);
    throw GoogleDesktopAuthException('Failed to open browser for Google sign-in.');
  }

  late Map<String, String> params;
  try {
    params = await completer.future.timeout(_kOAuthCallbackTimeout);
  } on TimeoutException {
    await server.close(force: true);
    throw GoogleDesktopAuthCancelled();
  } finally {
    await server.close(force: true);
  }

  if (params['error'] != null) {
    if (params['error'] == 'access_denied') {
      throw GoogleDesktopAuthCancelled();
    }
    throw GoogleDesktopAuthException(
        'Google sign-in failed. Please try again.');
  }

  final returnedState = params['state'];
  if (returnedState != state) {
    throw GoogleDesktopAuthException(
        'OAuth state mismatch – possible CSRF attempt.');
  }

  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw GoogleDesktopAuthException('No authorization code received from Google.');
  }

  return _exchangeCodeForTokens(code: code, codeVerifier: codeVerifier);
}

Future<GoogleDesktopTokens> _exchangeCodeForTokens({
  required String code,
  required String codeVerifier,
}) async {
  final clientSecret = await _readDesktopClientSecret();
  final includeClientSecret = clientSecret.isNotEmpty;
  final tokenBody = <String, String>{
    'client_id': _kClientId,
    'redirect_uri': _kRedirectUri,
    'code': code,
    'code_verifier': codeVerifier,
    'grant_type': 'authorization_code',
    if (includeClientSecret) 'client_secret': clientSecret,
  };
  final response = await http.post(
    Uri.https('oauth2.googleapis.com', '/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: tokenBody,
  );

  if (response.statusCode != 200) {
    throw GoogleDesktopAuthException(
      _buildTokenExchangeErrorMessage(response.statusCode, response.body),
    );
  }

  final Map<String, dynamic> data = jsonDecode(response.body);

  final idToken = data['id_token'] as String?;
  final accessToken = data['access_token'] as String?;

  if (idToken == null || idToken.isEmpty) {
    throw GoogleDesktopAuthException('Token exchange did not return an id_token.');
  }
  if (accessToken == null || accessToken.isEmpty) {
    throw GoogleDesktopAuthException('Token exchange did not return an access_token.');
  }

  return GoogleDesktopTokens(idToken: idToken, accessToken: accessToken);
}

Future<void> saveGoogleDesktopClientSecret(String secret) async {
  await _secureStorage.write(
    key: _kDesktopClientSecretKey,
    value: secret.trim(),
  );
}

Future<void> clearGoogleDesktopClientSecret() async {
  await _secureStorage.delete(key: _kDesktopClientSecretKey);
}

Future<String> _readDesktopClientSecret() async {
  final secret = await _secureStorage.read(key: _kDesktopClientSecretKey);
  if (secret != null && secret.trim().isNotEmpty) {
    return secret.trim();
  }
  return _kDesktopClientSecretFallback;
}

String _buildTokenExchangeErrorMessage(int statusCode, String responseBody) {
  try {
    final Map<String, dynamic> payload = jsonDecode(responseBody);
    final error = payload['error'] as String?;
    final description = payload['error_description'] as String?;

    if (error == 'invalid_request' &&
        (description ?? '').toLowerCase().contains('client_secret')) {
      // Configuration issue — show developer-actionable message, not raw body.
      return 'Google authentication requires additional configuration (client_secret). Please contact support.';
    }

    if (error == 'invalid_grant') {
      return 'Google sign-in session expired. Please try signing in again.';
    }

    if (error == 'access_denied') {
      return 'Google sign-in was denied. Please try again and grant the required permissions.';
    }
  } catch (_) {
    // Body is not JSON; use generic message below.
  }

  // Never surface raw response body or HTTP status codes to the user.
  return 'Google authentication failed. Please try signing in again.';
}

// ---------------------------------------------------------------------------
// PKCE helpers
// ---------------------------------------------------------------------------

String _generateCodeVerifier() => _randomString(64);

String _generateCodeChallenge(String verifier) {
  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return base64Url
      .encode(digest.bytes)
      .replaceAll('=', '');
}

String _randomString(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final rng = Random.secure();
  return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ---------------------------------------------------------------------------
// Callback HTML page shown to the user in the browser
// ---------------------------------------------------------------------------

String _htmlCallback({String? error}) {
  if (error != null) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Sign-in cancelled</title></head>
<body style="font-family:sans-serif;text-align:center;padding:40px">
  <h2>Sign-in was cancelled or failed.</h2>
  <p>You can close this tab and return to Pharmacy POS.</p>
</body>
</html>''';
  }
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Signed in!</title>
</head>
<body style="font-family:sans-serif;text-align:center;padding:40px">
  <h2>You have signed in successfully!</h2>
  <p>You can close this tab and return to Pharmacy POS.</p>
</body>
</html>''';
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class GoogleDesktopAuthException implements Exception {
  GoogleDesktopAuthException(this.message);
  final String message;

  @override
  String toString() => 'GoogleDesktopAuthException: $message';
}

class GoogleDesktopAuthCancelled extends GoogleDesktopAuthException {
  GoogleDesktopAuthCancelled() : super('User cancelled Google sign-in.');
}
