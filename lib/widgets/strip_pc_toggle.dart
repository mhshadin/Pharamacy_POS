import 'package:flutter/material.dart';
import '../utils/colors.dart';

class StripPcToggle extends StatelessWidget {
  final String currentSelection;
  final Function(String) onChanged;

  const StripPcToggle({
    super.key,
    required this.currentSelection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStrip = currentSelection.toLowerCase() == 'strip';

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondaryAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('Strip'),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isStrip ? AppColors.secondaryAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isStrip
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'STRIP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isStrip ? AppColors.white : AppColors.primaryDark.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged('Pc'),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: !isStrip ? AppColors.secondaryAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: !isStrip
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'PC',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: !isStrip ? AppColors.white : AppColors.primaryDark.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
