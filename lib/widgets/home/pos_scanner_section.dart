import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/colors.dart';

class PosScannerSection extends StatelessWidget {
  final MobileScannerController cameraController;
  final Animation<double> scanAnimation;
  final bool isTablet;
  final bool isCameraActive;
  final bool isProcessingScan;
  final void Function(String code) onBarcodeScanned;
  final VoidCallback onToggleCamera;
  final Future<void> Function() onManualAdd;
  final Future<void> Function() onOcrScan;
  final VoidCallback onVoiceSearch;
  final bool isVoiceActive;

  const PosScannerSection({
    super.key,
    required this.cameraController,
    required this.scanAnimation,
    required this.isTablet,
    required this.isCameraActive,
    required this.isProcessingScan,
    required this.onBarcodeScanned,
    required this.onToggleCamera,
    required this.onManualAdd,
    required this.onOcrScan,
    required this.onVoiceSearch,
    this.isVoiceActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(
          bottom: BorderSide(
            color: AppColors.secondaryAccent,
            width: 4,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 8,
                child: Container(
                  height: isTablet ? 140 : 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.secondaryAccent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: cameraController,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty &&
                                barcodes.first.rawValue != null) {
                              onBarcodeScanned(barcodes.first.rawValue!);
                            }
                          },
                        ),
                        if (!isCameraActive)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black87,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      LucideIcons.cameraOff,
                                      color: Colors.white54,
                                      size: 40,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Camera Paused',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isCameraActive)
                          AnimatedBuilder(
                            animation: scanAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: scanAnimation.value *
                                    (isTablet ? 240 : 200),
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.highlightActive,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.highlightActive
                                            .withValues(alpha: 0.8),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: _CornerBracket(bT: true, bL: true),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: _CornerBracket(bT: true, bR: true),
                        ),
                        const Positioned(
                          bottom: 8,
                          left: 8,
                          child: _CornerBracket(bB: true, bL: true),
                        ),
                        const Positioned(
                          bottom: 8,
                          right: 8,
                          child: _CornerBracket(bB: true, bR: true),
                        ),
                        if (isProcessingScan)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.highlightActive,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onToggleCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCameraActive
                            ? AppColors.background
                            : AppColors.error.withValues(alpha: 0.1),
                        foregroundColor: isCameraActive
                            ? AppColors.primaryDark
                            : AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isCameraActive
                                ? AppColors.secondaryAccent
                                : AppColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Icon(
                        isCameraActive
                            ? LucideIcons.camera
                            : LucideIcons.cameraOff,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onManualAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlightActive,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.plusSquare,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onOcrScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryAccent,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.scanLine,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onVoiceSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVoiceActive
                            ? AppColors.highlightActive
                            : AppColors.background,
                        foregroundColor: isVoiceActive
                            ? AppColors.primaryDark
                            : AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isVoiceActive
                                ? AppColors.highlightActive
                                : AppColors.secondaryAccent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Icon(
                        isVoiceActive ? LucideIcons.micOff : LucideIcons.mic,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool bT, bB, bL, bR;
  const _CornerBracket({
    this.bT = false,
    this.bB = false,
    this.bL = false,
    this.bR = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: bT
              ? const BorderSide(color: AppColors.highlightActive, width: 2)
              : BorderSide.none,
          bottom: bB
              ? const BorderSide(color: AppColors.highlightActive, width: 2)
              : BorderSide.none,
          left: bL
              ? const BorderSide(color: AppColors.highlightActive, width: 2)
              : BorderSide.none,
          right: bR
              ? const BorderSide(color: AppColors.highlightActive, width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }
}

