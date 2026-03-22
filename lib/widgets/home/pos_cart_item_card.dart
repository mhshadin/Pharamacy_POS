import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../utils/colors.dart';
import '../../models/cart_item.dart';
import '../../providers/pos_provider.dart';
import '../taka_symbol.dart';

class PosCartItemCard extends StatelessWidget {
  final CartItem item;
  final POSProvider provider;

  const PosCartItemCard({
    super.key,
    required this.item,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final nameFontSize = isNarrow ? 15.0 : 18.0;
    final stripPriceFontSize = isNarrow ? 15.0 : 18.0;
    final pcPriceFontSize = isNarrow ? 13.0 : 16.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.secondaryAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.highlightActive),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.package,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.product.generic,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TakaSymbol(
                        size: isNarrow ? 12.0 : 14.0,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item.product.priceStrip.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: stripPriceFontSize,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'STRIP PRICE',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.secondaryAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TakaSymbol(
                        size: isNarrow ? 10.0 : 12.0,
                        color: AppColors.secondaryAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item.product.pricePc.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: pcPriceFontSize,
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'PC PRICE',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.secondaryAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.background, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _QuantityBox(
                        label: 'STRIP',
                        quantity: item.stripQuantity,
                        onDecrement: () =>
                            provider.updateStripQuantity(item.product, -1),
                        onIncrement: () =>
                            provider.updateStripQuantity(item.product, 1),
                      ),
                      const SizedBox(width: 12),
                      _QuantityBox(
                        label: 'PC',
                        quantity: item.pcQuantity,
                        onDecrement: () =>
                            provider.updatePcQuantity(item.product, -1),
                        onIncrement: () =>
                            provider.updatePcQuantity(item.product, 1),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => provider.removeItem(item.product.id),
                        icon: const Icon(LucideIcons.trash2, size: 20),
                        color: AppColors.error,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityBox extends StatelessWidget {
  final String label;
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityBox({
    required this.label,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 380;
    final btnW = isNarrow ? 28.0 : 32.0;
    final numW = isNarrow ? 30.0 : 36.0;
    final boxH = isNarrow ? 32.0 : 36.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.secondaryAccent,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: boxH,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.secondaryAccent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onDecrement,
                child: Container(
                  width: btnW,
                  alignment: Alignment.center,
                  color: AppColors.background,
                  child: const Icon(
                    LucideIcons.minus,
                    size: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Container(
                width: numW,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: AppColors.secondaryAccent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: isNarrow ? 12.0 : 14.0,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              InkWell(
                onTap: onIncrement,
                child: Container(
                  width: btnW,
                  alignment: Alignment.center,
                  color: AppColors.background,
                  child: const Icon(
                    LucideIcons.plus,
                    size: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

