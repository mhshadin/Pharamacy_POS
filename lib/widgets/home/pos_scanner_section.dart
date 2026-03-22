import 'dart:io';
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
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final isNarrow = screenWidth < 380;
    final cameraHeight = isTablet ? 320.0 : (isNarrow ? 180.0 : 220.0);
    final btnSpacing = isTablet ? 12.0 : (isNarrow ? 6.0 : 8.0);

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
                  height: cameraHeight,
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
                        if (!Platform.isWindows)
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
                                  children: [
                                    Icon(
                                      LucideIcons.cameraOff,
                                      color: Colors.white54,
                                      size: isNarrow ? 32.0 : 40.0,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
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
                                top: scanAnimation.value * cameraHeight,
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
              SizedBox(width: isNarrow ? 10.0 : 16.0),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScannerButton(
                      onPressed: onToggleCamera,
                      icon: isCameraActive ? LucideIcons.camera : LucideIcons.cameraOff,
                      label: 'Camera',
                      isActive: isCameraActive,
                      activeColor: AppColors.highlightActive,
                    ),
                    SizedBox(height: btnSpacing),
                    _ScannerButton(
                      onPressed: onManualAdd,
                      icon: LucideIcons.plusSquare,
                      label: 'Manual',
                      isActive: true,
                      activeColor: AppColors.secondaryAccent,
                    ),
                    SizedBox(height: btnSpacing),
                    _ScannerButton(
                      onPressed: onOcrScan,
                      icon: LucideIcons.scanLine,
                      label: 'OCR',
                      isActive: true,
                      activeColor: AppColors.secondaryAccent,
                    ),
                    SizedBox(height: btnSpacing),
                    _ScannerButton(
                      onPressed: onVoiceSearch,
                      icon: isVoiceActive ? LucideIcons.micOff : LucideIcons.mic,
                      label: 'Voice',
                      isActive: isVoiceActive,
                      activeColor: AppColors.highlightActive,
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

class _ScannerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;

  const _ScannerButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54, // Consistent touch target
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? activeColor : AppColors.primaryDark.withValues(alpha: 0.5),
          foregroundColor: isActive ? AppColors.primaryDark : AppColors.white.withValues(alpha: 0.7),
          elevation: isActive ? 2 : 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive ? activeColor : AppColors.secondaryAccent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.primaryDark : AppColors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
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

