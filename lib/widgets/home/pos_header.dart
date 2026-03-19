import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';

class PosHeader extends StatelessWidget {
  final ValueChanged<String> onMenuSelected;

  const PosHeader({
    super.key,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(
                  LucideIcons.moreVertical,
                  color: AppColors.white,
                ),
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 2,
                  ),
                ),
                onSelected: onMenuSelected,
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'product_list',
                    child: Row(
                      children: const [
                        Icon(
                          LucideIcons.package,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Product List',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'returns',
                    child: Row(
                      children: const [
                        Icon(
                          LucideIcons.rotateCcw,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Returns',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'admin',
                    child: Row(
                      children: const [
                        Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

