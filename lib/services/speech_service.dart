// Added speech to text functionality for voice-enabled product search
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lightweight wrapper around `speech_to_text` to keep
/// platform details and lifecycle management in one place.
///
/// Designed so it can be reused from multiple screens
/// (Manual Add, Home, etc.) without duplicating logic.
class SpeechService {
  SpeechService._internal()
      : _speech = SpeechToText();

  static final SpeechService _instance = SpeechService._internal();

  static SpeechService get instance => _instance;

  final SpeechToText _speech;

  bool _initialized = false;
  bool _hasPermission = false;
  bool _isListening = false;
  String _lastText = '';

  bool get isInitialized => _initialized;
  bool get hasPermission => _hasPermission;
  bool get isListening => _isListening;
  String get lastRecognizedText => _lastText;

  /// Request microphone permission and initialize the speech engine.
  ///
  /// Safe to call at app startup (silently, no error handler needed).
  /// Returns true if permission is granted.
  Future<bool> requestPermission() => initialize();

  /// Initialize the underlying speech engine and request permissions if needed.
  ///
  /// Skips re-initialization only when permission is already confirmed.
  /// Retries the OS permission dialog if previously denied.
  Future<bool> initialize({
    void Function(String error)? onError,
  }) async {
    // Already good — skip.
    if (_initialized && _hasPermission) return true;

    // Reset so the plugin can re-prompt if the user previously denied.
    _initialized = false;

    try {
      _hasPermission = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) {
            debugPrint('Speech status: $status');
          }
        },
        onError: (error) {
          onError?.call(error.errorMsg);
          if (kDebugMode) {
            debugPrint('Speech error: ${error.errorMsg}');
          }
        },
      );

      _initialized = _hasPermission;
    } catch (e) {
      onError?.call(e.toString());
      if (kDebugMode) {
        debugPrint('Speech init exception: $e');
      }
      _initialized = false;
      _hasPermission = false;
    }

    return _hasPermission;
  }

  /// Start listening for speech.
  ///
  /// [preferredLocaleId] can be set to e.g. `bn_BD` or `en_US`.
  /// If the locale is not available, the plugin falls back internally.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
    String? preferredLocaleId,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    final ok = await initialize(onError: onError);
    if (!ok) {
      onError?.call('Microphone permission not granted or speech not available.');
      return;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _lastText = '';
      _isListening = true;

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastText = result.recognizedWords;
          onResult(_lastText, result.finalResult);
        },
        listenFor: listenFor,
        localeId: preferredLocaleId,
        partialResults: true,
        listenOptions: SpeechListenOptions(cancelOnError: true),
      );
    } catch (e) {
      _isListening = false;
      onError?.call(e.toString());
      if (kDebugMode) {
        debugPrint('Speech listen exception: $e');
      }
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {
      // ignore
    } finally {
      _isListening = false;
    }
  }

  Future<void> cancel() async {
    if (!_isListening) return;
    try {
      await _speech.cancel();
    } catch (_) {
      // ignore
    } finally {
      _isListening = false;
      _lastText = '';
    }
  }
}

