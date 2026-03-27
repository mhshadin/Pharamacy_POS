import '../services/auth_service.dart';
import '../services/google_oauth_desktop.dart';

/// Maps raw API exceptions and backend error codes to safe, user-friendly
/// display messages grouped by the flow in which they occur.
///
/// Rules:
/// - Never expose raw JSON, HTTP status text, exception class names, or
///   provider response bodies to the user.
/// - Some backend messages are already user-friendly and are passed through.
/// - Unknown / unexpected errors fall back to a contextual generic hint.
class ApiErrorMapper {
  const ApiErrorMapper._();

  // ---------------------------------------------------------------------------
  // Public flow-specific entry points
  // ---------------------------------------------------------------------------

  static String forLogin(Object error) {
    if (error is AuthException) {
      return _mapKnownMessage(error.message) ??
          _mapByStatusCode(error.statusCode, context: 'Login failed') ??
          'Login failed. Please check your credentials and try again.';
    }
    return 'Login failed. Please try again.';
  }

  static String forRegistration(Object error) {
    if (error is AuthException) {
      return _mapKnownMessage(error.message) ??
          _mapByStatusCode(error.statusCode, context: 'Registration failed') ??
          'Registration failed. Please check your details and try again.';
    }
    return 'Registration failed. Please try again.';
  }

  static String forGoogleSignIn(Object error) {
    if (error is GoogleDesktopAuthException) {
      return _mapGoogleDesktopMessage(error.message) ??
          'Google sign-in failed. Please try again.';
    }
    if (error is AuthException) {
      return _mapKnownMessage(error.message) ??
          'Google sign-in failed. Please try again.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  static String forProfileNameUpdate(Object error) {
    if (error is AuthException) {
      if (_isSessionExpired(error)) {
        return 'Your session has expired. Please log in again to update your name.';
      }
    }
    return 'Unable to update your name. Please try again.';
  }

  static String forPasswordUpdate(Object error) {
    if (error is AuthException) {
      if (_isSessionExpired(error)) {
        return 'Your session has expired. Please log in again to set a password.';
      }
      if (error.message.toLowerCase().contains('at least 8')) {
        return 'Password must be at least 8 characters long.';
      }
    }
    return 'Unable to set password. Please try again.';
  }

  static String forPlanLoad() {
    return 'Unable to load subscription plans. Please check your connection and try again.';
  }

  static String forPaymentInit() {
    return 'Payment could not be started. Please try again or contact support.';
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Maps known backend error messages / codes that need special handling.
  /// Returns null if the message is either already user-friendly and can be
  /// shown as-is, or unknown (caller should use a context-specific fallback).
  static String? _mapKnownMessage(String message) {
    final m = message.trim();

    switch (m) {
      // --- Device / account conflicts ---
      case 'DEVICE_ALREADY_REGISTERED':
        return 'This device is already registered to another pharmacy account. Please contact support.';

      // --- Already user-friendly messages from the backend (pass through) ---
      case 'Invalid email or password.':
      case 'An account with this email already exists.':
      case 'Account disabled.':
      case 'Invalid email format.':
      case 'Password must be at least 8 characters long.':
        return m;

      // --- Google-specific backend errors ---
      case 'Invalid Google Token.':
      case 'Invalid token.':
        return 'Unable to verify your Google account. Please try signing in again.';

      // --- Server-side generic codes ---
      case 'Server error.':
      case 'Server error while creating the account.':
      case 'Server error while updating password.':
        return 'A server error occurred. Please try again later.';

      // --- Internal/technical: do NOT show as-is ---
      case 'Missing license token in response.':
        return 'Authentication failed. Please try again.';
    }

    // Pass through the long, helpful Google-path hint that the backend sends.
    if (m.contains("signed up with Google") && m.contains("set a password")) {
      return m;
    }

    // Unauthorized / session messages from backend (technical phrasing)
    if (m.contains('Unauthorized') || m.contains('forged token')) {
      return null; // let caller use session-expired copy or status-based fallback
    }

    // Fallback: if message looks like a status-code artefact, suppress it.
    if (m.startsWith('Authentication failed with status')) {
      return null;
    }

    // For any other readable backend message, pass it through.
    return m.isNotEmpty ? m : null;
  }

  static String? _mapByStatusCode(int? code, {required String context}) {
    if (code == null) return null;
    if (code == 401 || code == 403) {
      return '$context. Please check your credentials.';
    }
    if (code == 409) return 'This account already exists. Please sign in instead.';
    if (code >= 500) return 'A server error occurred. Please try again later.';
    return null;
  }

  static String? _mapGoogleDesktopMessage(String message) {
    final m = message.toLowerCase();
    if (m.contains('client_secret') || m.contains('configuration')) {
      return 'Google sign-in requires additional setup. Please contact support.';
    }
    if (m.contains('browser')) {
      return 'Could not open the browser for Google sign-in. Please try again.';
    }
    if (m.contains('port') || m.contains('server')) {
      return 'Google sign-in could not start. Please close other apps and try again.';
    }
    if (m.contains('state mismatch') || m.contains('csrf')) {
      return 'Google sign-in was interrupted. Please try again.';
    }
    if (m.contains('no authorization code') || m.contains('token exchange')) {
      return 'Google sign-in failed. Please try again.';
    }
    // Generic fallback for any other desktop OAuth error.
    return null;
  }

  static bool _isSessionExpired(AuthException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('unauthorized') ||
        msg.contains('expired') ||
        msg.contains('forged') ||
        e.statusCode == 401;
  }
}
