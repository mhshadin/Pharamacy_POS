import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../utils/colors.dart';

/// Slides in a full-height panel from the right (same pattern as product list).
void showRightFilterPanel(
  BuildContext context,
  Widget Function(BuildContext dialogContext) body,
) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final size = MediaQuery.sizeOf(dialogContext);
      final panelWidth = min(size.width * 0.88, 420.0);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.background,
          elevation: 12,
          shadowColor: AppColors.primaryDark.withValues(alpha: 0.15),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: panelWidth,
            height: size.height,
            child: SafeArea(
              left: false,
              child: body(dialogContext),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: child,
      );
    },
  );
}

/// Home quick-action tile styled icon button with optional badge.
Widget adminActionTileButton({
  required IconData icon,
  required String label,
  required String tooltip,
  required int activeCount,
  required VoidCallback onPressed,
  bool expand = false,
  double minWidth = 72,
}) {
  final tile = Tooltip(
    message: tooltip,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 44,
          width: expand ? double.infinity : minWidth,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? AppColors.primaryDark.withValues(alpha: 0.08)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: activeCount > 0
                      ? AppColors.primaryDark.withValues(alpha: 0.35)
                      : AppColors.divider,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: activeCount > 0
                        ? AppColors.primaryDark
                        : AppColors.primaryDark,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeCount > 0
                          ? AppColors.primaryDark
                          : AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (activeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              child: Text(
                activeCount > 99 ? '99+' : '$activeCount',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  if (expand) return Expanded(child: tile);
  return tile;
}
