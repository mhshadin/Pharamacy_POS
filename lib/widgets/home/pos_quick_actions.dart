import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/language_provider.dart';

class PosQuickActions extends StatelessWidget {
  final bool isScannerExpanded;
  final VoidCallback onToggleScanner;
  final VoidCallback onManualAdd;
  final VoidCallback onOcrScan;
  final VoidCallback onVoiceTap;
  final bool isVoiceActive;
  final bool isPanelMode;

  const PosQuickActions({
    super.key,
    required this.isScannerExpanded,
    required this.onToggleScanner,
    required this.onManualAdd,
    required this.onOcrScan,
    required this.onVoiceTap,
    this.isVoiceActive = false,
    this.isPanelMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<LanguageProvider>().strings;

    final actions = [
      _ActionData(
        label: l10n.manual,
        icon: LucideIcons.plusSquare,
        onPressed: onManualAdd,
      ),
      _ActionData(
        label: l10n.ocr,
        icon: LucideIcons.scanLine,
        onPressed: onOcrScan,
      ),
      _ActionData(
        label: isVoiceActive ? l10n.cancelBtn : l10n.voice,
        icon: isVoiceActive ? LucideIcons.micOff : LucideIcons.mic,
        isActive: isVoiceActive,
        activeColor: AppColors.highlightActive,
        onPressed: onVoiceTap,
      ),
    ];

    if (isPanelMode) {
      // Expanded fills the parent SizedBox height — buttons share equally
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions.asMap().entries.map((e) {
          final isLast = e.key == actions.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 5),
              child: _VerticalActionButton(
                label: e.value.label,
                icon: e.value.icon,
                isActive: e.value.isActive,
                activeColor: e.value.activeColor,
                onPressed: e.value.onPressed,
              ),
            ),
          );
        }).toList(),
      );
    }

    // Horizontal row for legacy / non-panel usage
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: actions.asMap().entries.map((e) {
          final isLast = e.key == actions.length - 1;
          final a = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: a.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: a.isActive
                        ? (a.activeColor ?? AppColors.primaryDark)
                        : AppColors.posButtonIdle,
                    foregroundColor:
                        a.isActive ? AppColors.white : AppColors.primaryDark,
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
                      Icon(a.icon, size: 18),
                      const SizedBox(height: 2),
                      Text(
                        a.label,
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
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionData {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;

  const _ActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });
}

class _VerticalActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;

  const _VerticalActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? (activeColor ?? AppColors.primaryDark)
        : AppColors.posButtonIdle;
    final fg = isActive ? AppColors.white : AppColors.primaryDark;

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
