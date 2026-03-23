import 'product.dart';

enum ItemType { strip, pc }

class CartItem {
  Product product;
  int stripQuantity;
  int pcQuantity;
  String? medType;

  CartItem({
    required this.product,
    this.stripQuantity = 1,
    this.pcQuantity = 0,
    this.medType,
  });

  double get total =>
      (product.priceStrip * stripQuantity) + (product.pricePc * pcQuantity);

  int get totalPieces => (stripQuantity * product.pcsPerStrip) + pcQuantity;
}
