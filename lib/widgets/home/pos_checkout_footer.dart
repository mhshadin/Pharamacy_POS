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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.secondaryAccent,
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, -4),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ITEMS: ${cart.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryAccent,
                  letterSpacing: 1.1,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL PAYABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const TakaSymbol(
                        size: 28,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        total.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 30,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: cart.isEmpty ? null : onClear,
                  icon: const Icon(LucideIcons.trash2, size: 20),
                  label: const Text('CLEAR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    disabledForegroundColor: Colors.grey.shade400,
                    side: BorderSide(
                      color: cart.isEmpty
                          ? Colors.grey.shade300
                          : AppColors.error,
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 7,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

