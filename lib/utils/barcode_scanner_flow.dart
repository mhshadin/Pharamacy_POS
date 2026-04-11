import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/scanner_screen.dart';
import '../services/mobile_scanner_bridge.dart';

/// Opens [ScannerScreen] and replaces [controller] text with the scanned value.
class BarcodeScannerFlow {
  BarcodeScannerFlow._();

  static Future<void> scanIntoController({
    required BuildContext context,
    required TextEditingController controller,
    required VoidCallback onApplied,
    String webUnavailableMessage = 'Barcode scanning is not supported on web.',
  }) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(webUnavailableMessage)),
        );
      }
      return;
    }

    await MobileScannerBridge.beforePushOverlayScanner();
    String? scannedCode;
    try {
      if (!context.mounted) return;
      scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );
    } finally {
      MobileScannerBridge.afterPopOverlayScanner();
    }
    if (!context.mounted) return;
    if (scannedCode != null && scannedCode.isNotEmpty) {
      controller.text = scannedCode;
      controller.selection =
          TextSelection.collapsed(offset: scannedCode.length);
      onApplied();
    }
  }
}
