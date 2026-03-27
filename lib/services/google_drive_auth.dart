import 'package:google_sign_in/google_sign_in.dart';
import 'auth_storage.dart';
import 'dart:developer' as developer;

/// Shared Google Sign-In configuration for the whole app.
///
/// Both interactive login (LoginScreen) and background Drive sync
/// (AdminProvider) must use the SAME instance so silent restore works.
final googleSignInClient = GoogleSignIn(
  serverClientId:
      '1044506320101-d2u82o19cks959l14qv082j1jss1cuoh.apps.googleusercontent.com',
  scopes: ['email', 'https://www.googleapis.com/auth/drive.file'],
);

/// Silently restores the Google session and returns a **fresh** access token.
///
/// Returns `null` when:
/// - No prior Google session exists on the device (email-only users).
/// - The user revoked app access.
/// - Google Sign-In cannot produce a token (network unavailable, etc.).
///
/// On success the new token is persisted to [AuthStorage] so the next
/// [_performDriveSync] can use it from SharedPreferences even if this
/// helper is not called again first.
Future<String?> refreshGoogleAccessToken() async {
  try {
    final account =
        googleSignInClient.currentUser ??
        await googleSignInClient.signInSilently();
    if (account == null) {
      return null;
    }

    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    await const AuthStorage().setGoogleAccessToken(token);
    return token;
  } catch (e, stack) {
    developer.log("refreshGoogleAccessToken failed", error: e, stackTrace: stack);
    return null;
  }
}
