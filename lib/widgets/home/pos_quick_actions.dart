import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';

class PosQuickActions extends StatelessWidget {
  final bool isScannerExpanded;
  final VoidCallback onToggleScanner;
  final VoidCallback onManualAdd;
  final VoidCallback onOcrScan;
  final VoidCallback onVoiceSearch;
  final bool isVoiceActive;

  const PosQuickActions({
    super.key,
    required this.isScannerExpanded,
    required this.onToggleScanner,
    required this.onManualAdd,
    required this.onOcrScan,
    required this.onVoiceSearch,
    this.isVoiceActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _QuickActionButton(
            label: isScannerExpanded ? 'Hide' : 'Scan',
            icon: isScannerExpanded ? LucideIcons.chevronUp : LucideIcons.scan,
            isActive: isScannerExpanded,
            onPressed: onToggleScanner,
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            label: 'Manual',
            icon: LucideIcons.plusSquare,
            onPressed: onManualAdd,
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            label: 'OCR',
            icon: LucideIcons.scanLine,
            onPressed: onOcrScan,
          ),
          const SizedBox(width: 8),
          _QuickActionButton(
            label: isVoiceActive ? 'Stop' : 'Voice',
            icon: isVoiceActive ? LucideIcons.micOff : LucideIcons.mic,
            isActive: isVoiceActive,
            activeColor: AppColors.highlightActive,
            onPressed: onVoiceSearch,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isActive
        ? (activeColor ?? AppColors.primaryDark)
        : AppColors.posButtonIdle;
    final fgColor = isActive ? AppColors.white : AppColors.primaryDark;

    return Expanded(
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: fgColor,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
