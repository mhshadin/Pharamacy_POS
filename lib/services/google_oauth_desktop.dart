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
  _logOAuth(
    'Starting desktop OAuth. client_id=$_kClientId redirect_uri=$_kRedirectUri state=$state verifier_len=${codeVerifier.length}',
  );

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
  _logOAuth('Auth URL prepared: $authUrl');

  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _kRedirectPort);
    _logOAuth('Local callback server listening on 127.0.0.1:$_kRedirectPort');
  } on SocketException catch (e) {
    _logOAuth('Failed to start local callback server: $e');
    throw GoogleDesktopAuthException(
        'Could not start Google sign-in. Port $_kRedirectPort may be in use. Please close other apps and try again.');
  }

  final completer = Completer<Map<String, String>>();

  server.listen((HttpRequest request) async {
    _logOAuth(
      'Received callback request path=${request.uri.path} query=${request.uri.query}',
    );
    if (request.uri.path != _kRedirectPath) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      _logOAuth('Ignored callback on unexpected path: ${request.uri.path}');
      return;
    }

    final params = request.uri.queryParameters;
    _logOAuth(
      'Callback params keys=${params.keys.join(",")} has_code=${params.containsKey("code")} error=${params["error"]}',
    );

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
    _logOAuth('launchUrl failed for auth URL.');
    throw GoogleDesktopAuthException('Failed to open browser for Google sign-in.');
  }
  _logOAuth('Browser launched successfully.');

  late Map<String, String> params;
  try {
    params = await completer.future.timeout(_kOAuthCallbackTimeout);
  } on TimeoutException {
    await server.close(force: true);
    _logOAuth('OAuth flow timed out waiting for callback.');
    throw GoogleDesktopAuthCancelled();
  } finally {
    await server.close(force: true);
    _logOAuth('Local callback server closed.');
  }

  if (params['error'] != null) {
    if (params['error'] == 'access_denied') {
      throw GoogleDesktopAuthCancelled();
    }
    _logOAuth('Google OAuth callback error: ${params['error']}');
    throw GoogleDesktopAuthException(
        'Google sign-in failed. Please try again.');
  }

  final returnedState = params['state'];
  if (returnedState != state) {
    _logOAuth('State mismatch. expected=$state got=$returnedState');
    throw GoogleDesktopAuthException(
        'OAuth state mismatch – possible CSRF attempt.');
  }

  final code = params['code'];
  if (code == null || code.isEmpty) {
    _logOAuth('No authorization code found in callback.');
    throw GoogleDesktopAuthException('No authorization code received from Google.');
  }
  _logOAuth('Authorization code received. len=${code.length}');

  return _exchangeCodeForTokens(code: code, codeVerifier: codeVerifier);
}

Future<GoogleDesktopTokens> _exchangeCodeForTokens({
  required String code,
  required String codeVerifier,
}) async {
  final clientSecret = await _readDesktopClientSecret();
  _logOAuth(
    'Token exchange start. client_id=$_kClientId redirect_uri=$_kRedirectUri code_len=${code.length} verifier_len=${codeVerifier.length}',
  );
  final includeClientSecret = clientSecret.isNotEmpty;
  final tokenBody = <String, String>{
    'client_id': _kClientId,
    'redirect_uri': _kRedirectUri,
    'code': code,
    'code_verifier': codeVerifier,
    'grant_type': 'authorization_code',
    if (includeClientSecret) 'client_secret': clientSecret,
  };
  _logOAuth(
    'Token request payload prepared. includes_client_secret=$includeClientSecret keys=${tokenBody.keys.join(",")}',
  );
  final response = await http.post(
    Uri.https('oauth2.googleapis.com', '/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: tokenBody,
  );
  _logOAuth(
    'Token exchange response status=${response.statusCode} body=${response.body}',
  );

  if (response.statusCode != 200) {
    throw GoogleDesktopAuthException(
      _buildTokenExchangeErrorMessage(response.statusCode, response.body),
    );
  }

  final Map<String, dynamic> data = jsonDecode(response.body);

  final idToken = data['id_token'] as String?;
  final accessToken = data['access_token'] as String?;
  _logOAuth(
    'Token JSON parsed. keys=${data.keys.join(",")} id_token_len=${idToken?.length ?? 0} access_token_len=${accessToken?.length ?? 0}',
  );

  if (idToken == null || idToken.isEmpty) {
    throw GoogleDesktopAuthException('Token exchange did not return an id_token.');
  }
  if (accessToken == null || accessToken.isEmpty) {
    throw GoogleDesktopAuthException('Token exchange did not return an access_token.');
  }

  return GoogleDesktopTokens(idToken: idToken, accessToken: accessToken);
}

void _logOAuth(String message) {
  print('DEBUG OAUTH DESKTOP: $message');
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
  // Raw details are already logged by _logOAuth before this is called.
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
