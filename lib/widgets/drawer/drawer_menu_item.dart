import 'package:flutter/material.dart';
import '../../utils/colors.dart';

/// Styled drawer menu item with icon, label, and optional selected state.
class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const DrawerMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color:
                isSelected ? Colors.white.withAlpha(26) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    isSelected ? Colors.white : Colors.white.withAlpha(204),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withAlpha(230),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section divider with an optional uppercase title label.
class DrawerSectionLabel extends StatelessWidget {
  final String? title;

  const DrawerSectionLabel({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withAlpha(51), height: 1),
          if (title != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withAlpha(128),
                  letterSpacing: 0.8,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
