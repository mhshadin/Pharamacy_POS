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
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const PosScannerSection({
    super.key,
    required this.cameraController,
    required this.scanAnimation,
    required this.isTablet,
    required this.isCameraActive,
    required this.isProcessingScan,
    required this.onBarcodeScanned,
    required this.onToggleCamera,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _buildCollapsedCard();
    }
    return _buildExpandedCard(context);
  }

  // ── Collapsed: 48 px white card ──────────────────────────────────────────

  Widget _buildCollapsedCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: onToggleExpanded,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isCameraActive ? LucideIcons.scan : LucideIcons.cameraOff,
                color: isCameraActive
                    ? AppColors.primaryDark
                    : AppColors.secondaryAccent.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCameraActive
                      ? 'Scanner active — tap to expand'
                      : 'Scanner paused — tap to expand',
                  style: TextStyle(
                    color: isCameraActive
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronDown,
                color: AppColors.secondaryAccent,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expanded: white card with camera + bottom info row ───────────────────

  Widget _buildExpandedCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final cameraHeight =
        isTablet ? 280.0 : (screenWidth * 0.38).clamp(100.0, 160.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Camera view ──────────────────────────────────────────────
            Container(
              height: cameraHeight,
              width: double.infinity,
              color: const Color(0xFF111827),
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
                  // Paused overlay
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
                                size: isNarrow ? 26.0 : 32.0,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Camera Paused',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Tap to resume',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Scan line animation
                  if (isCameraActive)
                    AnimatedBuilder(
                      animation: scanAnimation,
                      builder: (context, _) {
                        return Positioned(
                          top: scanAnimation.value * cameraHeight,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.highlightActive,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.highlightActive
                                      .withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  // Corner brackets
                  const Positioned(
                    top: 8, left: 8,
                    child: _CornerBracket(bT: true, bL: true),
                  ),
                  const Positioned(
                    top: 8, right: 8,
                    child: _CornerBracket(bT: true, bR: true),
                  ),
                  const Positioned(
                    bottom: 8, left: 8,
                    child: _CornerBracket(bB: true, bL: true),
                  ),
                  const Positioned(
                    bottom: 8, right: 8,
                    child: _CornerBracket(bB: true, bR: true),
                  ),
                  // Tap-to-pause/resume
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isProcessingScan) return;
                        onToggleCamera();
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Processing overlay
                  if (isProcessingScan)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.highlightActive,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Bottom info row ──────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isCameraActive ? LucideIcons.scan : LucideIcons.cameraOff,
                    size: 14,
                    color: isCameraActive
                        ? AppColors.primaryDark
                        : AppColors.secondaryAccent.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCameraActive
                          ? 'Tap scanner to pause/resume'
                          : 'Scanner paused — tap to resume',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryAccent
                            .withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleExpanded,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Collapse',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          LucideIcons.chevronUp,
                          size: 14,
                          color: AppColors.secondaryAccent,
                        ),
                      ],
                    ),
                  ),
                ],
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
