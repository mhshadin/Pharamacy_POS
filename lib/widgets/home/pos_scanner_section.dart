import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_strings.dart';
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
    final l10n = context.read<LanguageProvider>().strings;
    if (!isExpanded) {
      return _buildCollapsedCard(l10n);
    }
    return _buildExpandedCard(context, l10n);
  }

  // ── Collapsed: 48 px white card ──────────────────────────────────────────

  Widget _buildCollapsedCard(AppStrings l10n) {
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
                      ? l10n.scannerActiveExpand
                      : l10n.scannerPausedExpand,
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

  Widget _buildExpandedCard(BuildContext context, AppStrings l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    // Camera fills more height when in side-by-side layout
    final cameraHeight =
        isTablet ? 280.0 : (screenWidth * 0.52).clamp(130.0, 220.0);

    return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
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
                              Text(
                                l10n.cameraPaused,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l10n.tapToResume,
                                style: const TextStyle(
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

            // ── Compact status bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isCameraActive ? LucideIcons.scan : LucideIcons.cameraOff,
                    size: 13,
                    color: isCameraActive
                        ? Colors.white70
                        : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isCameraActive
                          ? l10n.tapScannerToPauseResume
                          : l10n.scannerPausedTapToResume,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
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
