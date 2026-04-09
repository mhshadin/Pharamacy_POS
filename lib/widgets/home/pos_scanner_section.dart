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

  // ── Expanded: fills parent height via LayoutBuilder ─────────────────────

  Widget _buildExpandedCard(BuildContext context, AppStrings l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Status bar is 26px; camera fills everything else
        const double statusBarH = 26;
        final double cameraHeight =
            (constraints.maxHeight - statusBarH).clamp(60.0, 400.0);
        final bool isNarrow = constraints.maxWidth < 200;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Camera view ────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    if (!Platform.isWindows)
                      Positioned.fill(
                        child: MobileScanner(
                          controller: cameraController,
                          onDetect: (capture) {
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty &&
                                barcodes.first.rawValue != null) {
                              onBarcodeScanned(barcodes.first.rawValue!);
                            }
                          },
                        ),
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
                                  size: isNarrow ? 20.0 : 26.0,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.cameraPaused,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
                                    blurRadius: 8,
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
                        top: 6, left: 6,
                        child: _CornerBracket(bT: true, bL: true)),
                    const Positioned(
                        top: 6, right: 6,
                        child: _CornerBracket(bT: true, bR: true)),
                    const Positioned(
                        bottom: 6, left: 6,
                        child: _CornerBracket(bB: true, bL: true)),
                    const Positioned(
                        bottom: 6, right: 6,
                        child: _CornerBracket(bB: true, bR: true)),
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
              // ── Status bar ─────────────────────────────────────────────
              SizedBox(
                height: statusBarH,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        isCameraActive
                            ? LucideIcons.scan
                            : LucideIcons.cameraOff,
                        size: 11,
                        color:
                            isCameraActive ? Colors.white60 : Colors.white30,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isCameraActive
                              ? l10n.tapScannerToPauseResume
                              : l10n.scannerPausedTapToResume,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
