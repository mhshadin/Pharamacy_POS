import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';
import '../../widgets/taka_symbol.dart';
import '../../models/cart_item.dart';

class PosCheckoutFooter extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  final VoidCallback? onClear;
  final VoidCallback? onCheckout;

  const PosCheckoutFooter({
    super.key,
    required this.cart,
    required this.total,
    this.onClear,
    this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final totalFontSize = isNarrow ? 24.0 : 30.0;
    final takaSize = isNarrow ? 22.0 : 28.0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, isNarrow ? 10 : 12, 16, isNarrow ? 12 : 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top handle
          Container(
            width: 36,
            height: 3,
            margin: EdgeInsets.only(bottom: isNarrow ? 8 : 10),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Items chip
              _ItemsChip(count: cart.length),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL PAYABLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TakaSymbol(
                        size: takaSize,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        total.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: totalFontSize,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isNarrow ? 10 : 12),
          Row(
            children: [
              // Icon-only clear button
              SizedBox(
                height: 52,
                width: 52,
                child: OutlinedButton(
                  onPressed: cart.isEmpty ? null : onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    disabledForegroundColor: Colors.grey.shade400,
                    side: BorderSide(
                      color: cart.isEmpty
                          ? Colors.grey.shade300
                          : AppColors.error,
                      width: 1.5,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(LucideIcons.trash2, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Gradient checkout CTA
              Expanded(
                child: _GradientCheckoutButton(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  isNarrow: isNarrow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsChip extends StatelessWidget {
  final int count;
  const _ItemsChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondaryAccent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.shoppingCart,
            size: 14,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            '$count ${count == 1 ? 'item' : 'items'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientCheckoutButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isNarrow;

  const _GradientCheckoutButton({
    required this.onPressed,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDisabled
              ? null
              : const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.success],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: isDisabled ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(LucideIcons.shoppingBag, size: 18),
          label: Text(
            'Checkout',
            style: TextStyle(
              fontSize: isNarrow ? 14.0 : 16.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: AppColors.white,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
