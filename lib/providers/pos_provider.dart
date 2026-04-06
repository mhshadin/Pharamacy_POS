import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/sale_record.dart';
import 'admin_provider.dart';
import '../services/database_helper.dart';
import '../utils/product_matcher.dart';
import 'package:vibration/vibration.dart';

class POSProvider extends ChangeNotifier {
  POSProvider(this._admin);

  final AdminProvider _admin;
  final DatabaseHelper _db = DatabaseHelper();

  List<Product> _products = [];
  final List<CartItem> _cart = [];
  String _searchQuery = '';

  List<Product> get products => _products;
  List<CartItem> get cart => _cart;
  String get searchQuery => _searchQuery;
  String? _selectedMedType;
  String? get selectedMedType => _selectedMedType;

  /// Load all products from the database. Call once at startup and after mutations.
  Future<void> loadProducts() async {
    _products = await _db.getAllProducts();
    ProductMatcher.precomputeHashes(_products);
    notifyListeners();
  }
  /// Groups filtered products by name, returning only one representative per name.
  List<Product> get groupedFilteredProducts {
    final list = filteredProducts;
    final Map<String, Product> unique = {};
    for (var p in list) {
      final key = p.name.toLowerCase();
      if (!unique.containsKey(key)) {
        unique[key] = p;
      }
    }
    return unique.values.toList();
  }

  List<Product> get filteredProducts {
    var list = _products;
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      list = list
          .where(
            (product) =>
                product.name.toLowerCase().contains(lowerQuery) ||
                product.generic.toLowerCase().contains(lowerQuery),
          )
          .toList();
    }
    if (_selectedMedType != null) {
      list = list.where((p) => (p.medType ?? 'Tablet') == _selectedMedType).toList();
    }
    return list;
  }

  List<CartItem> get filteredCart {
    if (_searchQuery.isEmpty) return _cart;
    final lowerQuery = _searchQuery.toLowerCase();
    return _cart
        .where(
          (item) =>
              item.product.name.toLowerCase().contains(lowerQuery) ||
              item.product.generic.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  /// Get all available medicine types for a given product name.
  List<String> getAvailableTypes(String productName) {
    return _products
        .where((p) => p.name.toLowerCase() == productName.toLowerCase())
        .map((p) => p.medType ?? 'Tablet')
        .toSet()
        .toList();
  }

  String _normalizePower(String? value) => value?.trim().toLowerCase() ?? '';

  String getVariantLabel(Product product) {
    final type = product.medType ?? 'Tablet';
    final power = product.power?.trim();
    if (power == null || power.isEmpty) return type;
    return '$type • $power';
  }

  /// Returns available variants for a product name.
  List<Product> getAvailableVariants(String productName) {
    return _products
        .where((p) => p.name.toLowerCase() == productName.toLowerCase())
        .toList();
  }

  double get calculateTotal {
    return _cart.fold(0, (total, item) => total + item.total);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedMedType(String? type) {
    _selectedMedType = type;
    notifyListeners();
  }

  Future<bool> handleBarcodeScan(String barcode) async {
    // 1. Find product by barcode
    final productToAdd = await _db.getProductByBarcode(barcode);

    // 2. If not found, return false so UI can show error
    if (productToAdd == null) {
      return false;
    }

    // 3. Play success haptics & audio
    await _playBeep();
    await _vibrate();

    // 4. Add to cart
    final existingIndex = _cart.indexWhere(
      (p) => p.product.id == productToAdd.id,
    );

    if (existingIndex >= 0) {
      _cart[existingIndex].stripQuantity += 1;
    } else {
      _cart.add(
        CartItem(
          product: productToAdd,
          stripQuantity: 1,
          pcQuantity: 0,
          medType: productToAdd.medType,
        ),
      );
    }

    notifyListeners();
    return true; // Success
  }

  void updateStripQuantity(Product product, int delta) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final newQ = _cart[index].stripQuantity + delta;
      if (newQ >= 0) {
        _cart[index].stripQuantity = newQ;
        notifyListeners();
      }
    } else if (delta > 0) {
      _cart.add(
        CartItem(
          product: product,
          stripQuantity: delta,
          pcQuantity: 0,
          medType: product.medType,
        ),
      );
      notifyListeners();
    }
  }

  void updatePcQuantity(Product product, int delta) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final newQ = _cart[index].pcQuantity + delta;
      if (newQ >= 0) {
        _cart[index].pcQuantity = newQ;
        notifyListeners();
      }
    } else if (delta > 0) {
      _cart.add(
        CartItem(product: product, stripQuantity: 0, pcQuantity: delta),
      );
      notifyListeners();
    }
  }

  void setQuantities(Product product, int strips, int pcs) {
    final index = _cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _cart[index].stripQuantity = strips;
      _cart[index].pcQuantity = pcs;
    } else {
      _cart.add(
        CartItem(
          product: product,
          stripQuantity: strips,
          pcQuantity: pcs,
          medType: product.medType,
        ),
      );
    }
    notifyListeners();
  }

  void updateCartItemMedType(CartItem item, String newType) {
    // Backward-compatible switch by type only.
    updateCartItemVariant(item, newType, null);
  }

  void updateCartItemVariant(CartItem item, String newType, String? newPower) {
    // Find the product variant corresponding to this name + newType + newPower
    final variant = _products.firstWhere(
      (p) =>
          p.name.toLowerCase() == item.product.name.toLowerCase() &&
          (p.medType ?? 'Tablet') == newType &&
          _normalizePower(p.power) == _normalizePower(newPower),
      orElse: () => item.product,
    );

    item.product = variant;
    item.medType = newType;
    notifyListeners();
  }

  void removeItem(String id) {
    _cart.removeWhere((item) => item.product.id == id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Complete a sale: persist sale records, deduct stock, then clear the cart.
  Future<String> completeSale() async {
    // Generate a single invoice number for this entire transaction
    final invoiceNumber = await _db.getNextInvoiceNumber();

    for (final item in _cart) {
      int totalPiecesToDeduct =
          (item.stripQuantity * item.product.pcsPerStrip) + item.pcQuantity;

      if (totalPiecesToDeduct <= 0) continue;

      // Total amount for this line item to distribute across possibly multiple batches
      double totalItemAmount = item.total;
      int originalTotalPieces = totalPiecesToDeduct;

      final batches = await _db.getBatchesForProduct(item.product.id);

      for (final batch in batches) {
        if (totalPiecesToDeduct <= 0) break;

        final deductAmount = batch.remainingPieces < totalPiecesToDeduct
            ? batch.remainingPieces
            : totalPiecesToDeduct;

        if (deductAmount <= 0) continue;

        // Pro-rate the amount for this partial batch sale
        final double batchAmount =
            (deductAmount / originalTotalPieces) * totalItemAmount;

        // 1. Record the sale for this batch specifically, capturing cost at time of sale
        final sale = SaleRecord(
          id: 'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-${batch.id}',
          productName: item.product.name,
          quantity:
              deductAmount, // In pieces for the record, or we should clarify it's pieces.
          amount: batchAmount,
          date: DateTime.now(),
          invoiceNumber: invoiceNumber,
          batchNumber: batch.batchNumber,
          medType: item.product.medType,
          power: item.product.power,
          costPricePerPc: batch.costPricePerPc,
        );
        await _db.insertSale(sale);

        // 2. Update the batch in DB
        await _db.updateBatchRemainingPieces(
          batch.id,
          batch.remainingPieces - deductAmount,
        );

        totalPiecesToDeduct -= deductAmount;
      }

      // Note: If totalPiecesToDeduct > 0 here, it means we oversold beyond tracked batches.
      if (totalPiecesToDeduct > 0) {
        final double batchAmount =
            (totalPiecesToDeduct / originalTotalPieces) * totalItemAmount;
        final sale = SaleRecord(
          id: 'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-OVERSOLD',
          productName: item.product.name,
          quantity: totalPiecesToDeduct,
          amount: batchAmount,
          date: DateTime.now(),
          invoiceNumber: invoiceNumber,
          batchNumber: 'OVERSOLD',
          medType: item.product.medType,
          power: item.product.power,
          costPricePerPc: 0.0,
        );
        await _db.insertSale(sale);
      }
    }

    _cart.clear();
    // Reload products to reflect updated stock
    await loadProducts();
    
    // Trigger Google Drive Backup (same AdminProvider as the app so fileId + debounce are shared)
    _admin.scheduleSync();

    return invoiceNumber; // Return it so UI can display it
  }

  // --- HAPTICS & SOUND ---
  Future<void> _playBeep() async {
    try {
      // In a full implementation, you'd add a beep.mp3 to assets.
      // await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint("Audio Error: \$e");
    }
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      debugPrint("Vibration Error: \$e");
    }
  }
}
