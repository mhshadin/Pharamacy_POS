import 'product.dart';

enum ItemType { strip, pc }

class CartItem {
  final Product product;
  int stripQuantity;
  int pcQuantity;

  CartItem({
    required this.product,
    this.stripQuantity = 1,
    this.pcQuantity = 0,
  });

  double get total =>
      (product.priceStrip * stripQuantity) + (product.pricePc * pcQuantity);

  int get totalPieces => (stripQuantity * product.pcsPerStrip) + pcQuantity;
}
