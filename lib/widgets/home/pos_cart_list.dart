import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';
import '../../models/cart_item.dart';
import '../../providers/pos_provider.dart';
import 'pos_cart_item_card.dart';

class PosCartList extends StatelessWidget {
  final List<CartItem> cart;
  final List<CartItem> filteredCart;
  final POSProvider provider;

  const PosCartList({
    super.key,
    required this.cart,
    required this.filteredCart,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: AppColors.background,
        child: cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.package,
                      size: 64,
                      color: AppColors.secondaryAccent.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cart is empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                    const Text(
                      'Scan an item to begin',
                      style: TextStyle(
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                  ],
                ),
              )
            : filteredCart.isEmpty
                ? const Center(
                    child: Text(
                      'No items match search.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredCart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final item = filteredCart[idx];
                      return PosCartItemCard(
                        item: item,
                        provider: provider,
                      );
                    },
                  ),
      ),
    );
  }
}

