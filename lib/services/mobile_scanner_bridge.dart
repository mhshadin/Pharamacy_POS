import 'package:flutter/foundation.dart';

/// Coordinates the Home POS barcode camera with overlay routes such as
/// [ScannerScreen], so only one [MobileScannerController] uses the device
/// camera at a time (avoids native "already running" errors).
class MobileScannerBridge {
  static Future<void> Function()? _pauseBackground;
  static VoidCallback? _resumeBackground;
  static int _overlayDepth = 0;

  static void register({
    required Future<void> Function() pauseBackgroundScanner,
    required VoidCallback resumeBackgroundScanner,
  }) {
    _pauseBackground = pauseBackgroundScanner;
    _resumeBackground = resumeBackgroundScanner;
  }

  static void unregister() {
    _pauseBackground = null;
    _resumeBackground = null;
    _overlayDepth = 0;
  }

  /// Call before [Navigator.push] to [ScannerScreen] while Home may be underneath.
  static Future<void> beforePushOverlayScanner() async {
    final pause = _pauseBackground;
    if (pause == null) return;
    _overlayDepth++;
    if (_overlayDepth > 1) return;
    await pause();
  }

  /// Call in `finally` after the overlay route pops.
  static void afterPopOverlayScanner() {
    final resume = _resumeBackground;
    if (resume == null) return;
    _overlayDepth--;
    if (_overlayDepth < 0) _overlayDepth = 0;
    if (_overlayDepth > 0) return;
    resume();
  }
}
