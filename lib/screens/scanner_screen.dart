import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/colors.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

// Added SingleTickerProviderStateMixin to handle the 60fps animation sync
class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _cameraController;
  late AnimationController _animationController;
  late Animation<Alignment> _animation;

  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();

    // Initialize Scanner
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Initialize Animation (2 seconds to go down, reverses automatically)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Smooth easing curve for the bounce effect
    _animation =
        AlignmentTween(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutSine,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make the width responsive to the phone screen (85% of screen width)
    final double scanWindowWidth = MediaQuery.of(context).size.width * 0.85;
    // Hardcode a short height specifically optimized for 1D barcodes
    final double scanWindowHeight = 120.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              if (_isProcessingScan) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                setState(() => _isProcessingScan = true);
                // Stop animation once a barcode is found to show it processed
                _animationController.stop();

                final String code = barcodes.first.rawValue!;

                // Return the scanned barcode code back to the caller
                Navigator.pop(context, code);
              }
            },
          ),

          // Scanning overlay
          SafeArea(
            child: Center(
              child: Container(
                width: scanWindowWidth,
                height: scanWindowHeight,
                // Ensure the line doesn't paint outside the rounded borders
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.highlightActive,
                    width: 3, // Slightly thicker border for better visibility
                  ),
                  borderRadius: BorderRadius.circular(12),
                  // Optional: Add a slight dark tint inside the box to increase contrast
                  color: Colors.black.withValues(alpha: 0.1),
                ),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Align(alignment: _animation.value, child: child);
                  },
                  child: Container(
                    height: 3, // Thicker line looks better in motion
                    width: scanWindowWidth * 0.85,
                    decoration: BoxDecoration(
                      color: AppColors.highlightActive,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.highlightActive.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isProcessingScan)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.highlightActive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
