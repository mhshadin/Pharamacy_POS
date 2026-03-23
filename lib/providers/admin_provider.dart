import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_batch.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/drive_service.dart';
import '../services/auth_storage.dart';
import '../services/google_drive_auth.dart';
import '../utils/inventory_alert_tiers.dart';
import 'dart:developer' as developer;

/// Any UI that mutates product or batch data (including returns)
/// should also trigger `POSProvider.loadProducts()` so the POS view
/// stays in sync with the latest stock and product information.
/// DTO for bulk import: product plus per-row batch number and expiry.
class BulkImportRecord {
  final Product product;
  final String? batchNumber;
  final DateTime expiryDate;

  BulkImportRecord({
    required this.product,
    this.batchNumber,
    required this.expiryDate,
  });
}

class AdminProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isAdminLoggedIn = false;
  String _currentPin = '12345'; // Default fallback

  List<Product> _products = [];
  List<SaleRecord> _sales = [];

  // Settings
  int _lowStockThreshold = 2; // Default to 2 boxes
  int _expiringSoonDays = 90;
  int _criticalExpiryDays = 30;
  int _moderateExpiryDays = 60;
  int _expiryDelayMonths = 6; // Default to 6 months
  bool _showSupplierInfo = false;
  int _defaultOrderBoxes = 100;
  List<String> _medicineTypes = [];
  static const List<String> defaultMedicineTypes = [
    'Tablet', 'Syrup', 'Injection', 'Capsule',
    'Cream', 'Ointment', 'Drops', 'Inhaler',
    'Gel', 'Spray', 'Powder', 'Suppository'
  ];

  // Google Drive Sync
  String? _googleDriveFileId;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _syncError;
  Timer? _debounceTimer;

  // Track notified products to avoid redundant alerts
  final Set<String> _notifiedLowStockIds = {};
  final Set<String> _notifiedExpiringIds = {};

  // Track products that the user has "seen" by opening the notification screen
  Set<String> _readLowStockIds = {};
  Set<String> _readExpiringIds = {};

  bool get isAdminLoggedIn => _isAdminLoggedIn;
  List<Product> get allProducts => _products;

  int get lowStockThreshold => _lowStockThreshold;
  int get expiringSoonDays => _expiringSoonDays;
  int get criticalExpiryDays => _criticalExpiryDays;
  int get moderateExpiryDays => _moderateExpiryDays;
  int get expiryDelayMonths => _expiryDelayMonths;
  bool get showSupplierInfo => _showSupplierInfo;
  int get defaultOrderBoxes => _defaultOrderBoxes;
  List<String> get medicineTypes => _medicineTypes;

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  bool login(String pin) {
    if (pin == _currentPin) {
      _isAdminLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _isAdminLoggedIn = false;
    notifyListeners();
  }

  /// Master load - Call only at startup.
  Future<void> loadData() async {
    try {
      await Future.wait([
        loadSettings(notify: false),
        loadProducts(notify: false),
        loadSales(notify: false),
      ]);
      notifyListeners();
      await checkForNotifications();
    } catch (e) {
      developer.log("Error loading initial data", error: e);
    }
  }

  /// Check for low stock and expiring products and show notifications.
  /// Only notifies once per threshold crossing.
  Future<void> checkForNotifications() async {
    final lowStock = lowStockProducts;
    final expiringSoon = expiringSoonProducts;

    final service = NotificationService();

    // 1. Handle Low Stock Alerts
    for (final p in lowStock) {
      // Only show OS notification if it hasn't been notified AND isn't already "read"
      if (!_notifiedLowStockIds.contains(p.id) && !_readLowStockIds.contains(p.id)) {
        await service.showLowStockAlert(p.name, p.stockStrips);
        _notifiedLowStockIds.add(p.id);
      }
    }
    // Clear tracking for products that are no longer low stock
    _notifiedLowStockIds.removeWhere((id) => !_products.any((p) => p.id == id && isProductLowStock(p)));
    _readLowStockIds.removeWhere((id) => !_products.any((p) => p.id == id && isProductLowStock(p)));

    // 2. Handle Expiry Alerts
    for (final p in expiringSoon) {
      // Only show OS notification if it hasn't been notified AND isn't already "read"
      if (!_notifiedExpiringIds.contains(p.id) && !_readExpiringIds.contains(p.id)) {
        final expiryStr = p.expiryDate?.toLocal().toString().split(' ')[0] ?? 'Unknown';
        await service.showExpiryAlert(p.name, expiryStr);
        _notifiedExpiringIds.add(p.id);
      }
    }
    // Clear tracking for products that are no longer expiring soon
    _notifiedExpiringIds.removeWhere((id) => !_products.any((p) => p.id == id && isProductExpiringSoon(p)));
    _readExpiringIds.removeWhere((id) => !_products.any((p) => p.id == id && isProductExpiringSoon(p)));
    
    // Persist cleaned up read IDs
    await _saveReadIds();
  }

  /// Mark all current alerts as read. They will no longer show in the badge
  /// or trigger new OS notifications until their status changes or new items appear.
  Future<void> markNotificationsAsRead() async {
    _readLowStockIds = lowStockProducts.map((p) => p.id).toSet();
    _readExpiringIds = expiringSoonProducts.map((p) => p.id).toSet();
    await _saveReadIds();
    notifyListeners();
  }

  Future<void> _saveReadIds() async {
    await _db.saveSetting('readLowStockIds', _readLowStockIds.join(','));
    await _db.saveSetting('readExpiringIds', _readExpiringIds.join(','));
  }

  int get unreadAlertCount {
    final unreadLowStock = lowStockProducts.where((p) => !_readLowStockIds.contains(p.id)).length;
    final unreadExpiring = expiringSoonProducts.where((p) => !_readExpiringIds.contains(p.id)).length;
    return unreadLowStock + unreadExpiring;
  }

  Future<void> loadSettings({bool notify = true}) async {
    final settings = await _db.getAllSettings();
    _lowStockThreshold = int.tryParse(settings['lowStockThreshold'] ?? '') ?? 2;
    _expiringSoonDays = int.tryParse(settings['expiringSoonDays'] ?? '') ?? 90;
    _criticalExpiryDays =
        int.tryParse(settings['criticalExpiryDays'] ?? '') ?? 30;
    _moderateExpiryDays =
        int.tryParse(settings['moderateExpiryDays'] ?? '') ?? 60;
    _expiryDelayMonths = int.tryParse(settings['expiryDelayMonths'] ?? '') ?? 6;
    _clampExpiryThresholds();
    _showSupplierInfo = settings['showSupplierInfo'] == 'true';
    _defaultOrderBoxes =
        int.tryParse(settings['defaultOrderBoxes'] ?? '') ?? 100;
    _currentPin = settings['adminPin'] ?? '12345';

    // Load read notification IDs
    final readLowStockStr = settings['readLowStockIds'] ?? '';
    _readLowStockIds = readLowStockStr.split(',').where((s) => s.isNotEmpty).toSet();
    
    final readExpiringStr = settings['readExpiringIds'] ?? '';
    _readExpiringIds = readExpiringStr.split(',').where((s) => s.isNotEmpty).toSet();

    final medTypesStr = settings['medicineTypes'] ?? '';
    if (medTypesStr.isEmpty) {
      _medicineTypes = List.from(defaultMedicineTypes);
    } else {
      _medicineTypes = medTypesStr.split(',').where((s) => s.isNotEmpty).toList();
    }

    _googleDriveFileId = settings['googleDriveFileId'];

    final lastSyncStr = settings['lastSyncTime'];
    if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }

    if (notify) notifyListeners();
  }

  void _clampExpiryThresholds() {
    if (_criticalExpiryDays < 0) _criticalExpiryDays = 0;
    if (_expiringSoonDays < _criticalExpiryDays) {
      _expiringSoonDays = _criticalExpiryDays;
    }
    if (_moderateExpiryDays < _criticalExpiryDays) {
      _moderateExpiryDays = _criticalExpiryDays;
    }
    if (_moderateExpiryDays > _expiringSoonDays) {
      _moderateExpiryDays = _expiringSoonDays;
    }
  }

  /// Schedules a backup to Google Drive.
  /// If [immediate] is true, it syncs right away.
  /// Otherwise, it debounces the request by 5 minutes, resetting the timer on subsequent calls.
  void scheduleSync({bool immediate = false}) {
    if (immediate) {
      _debounceTimer?.cancel();
      _performDriveSync();
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(minutes: 5), () {
        _performDriveSync();
      });
    }
  }

  Future<void> _performDriveSync() async {
    if (_isSyncing) return; // Prevent concurrent syncs

    // Refresh Drive file id (and related settings) from DB. Sync may run on a
    // fresh AdminProvider instance (e.g. POSProvider), which never called loadData().
    await loadSettings(notify: false);

    // Determine a valid Google access token, refreshing silently if possible.
    final authSession = await const AuthStorage().loadAuth();
    final storedToken = authSession?.googleAccessToken;

    // No stored token means user never signed in with Google — skip quietly.
    if (storedToken == null || storedToken.isEmpty) {
      developer.log("Skipping Drive sync: No Google access token found.");
      return;
    }

    // Attempt a silent token refresh. On failure fall back to the stored token
    // (may still be valid if it hasn't expired yet) rather than aborting.
    final refreshed = await refreshGoogleAccessToken();
    final googleToken = refreshed ?? storedToken;
    if (refreshed != null) {
      developer.log("Drive sync: access token refreshed successfully.");
    } else {
      developer.log("Drive sync: silent refresh failed, using stored token.");
    }

    final dbPath = await _db.getDatabasePath();
    if (dbPath == null) {
      developer.log("Skipping Drive sync: Could not determine DB path.");
      return;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final driveService = DriveService();
      final newFileId = await driveService.uploadDatabaseToDrive(
        accessToken: googleToken,
        dbFilePath: dbPath,
        fileId: _googleDriveFileId,
      );

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      
      // If the file ID changed (or it was the first upload), save it
      if (newFileId != _googleDriveFileId) {
        _googleDriveFileId = newFileId;
        await saveSetting('googleDriveFileId', newFileId);
      }
      
      await saveSetting('lastSyncTime', _lastSyncTime!.toIso8601String());
      
      notifyListeners();
      developer.log("Drive sync completed successfully. File ID: $newFileId");
    } catch (e) {
      developer.log("Drive sync failed", error: e);
      _isSyncing = false;
      final errorStr = e.toString();
      if (errorStr.contains('401') || errorStr.contains('invalid_grant') ||
          errorStr.contains('Invalid Credentials')) {
        _syncError =
            '401: Google session expired. Please sign out and sign back in with Google.';
      } else {
        _syncError = errorStr;
      }
      notifyListeners();

      // Retry after 5 minutes on failure
      developer.log("Scheduling retry sync in 5 minutes...");
      scheduleSync(immediate: false);
    }
  }

  Future<void> loadProducts({bool notify = true}) async {
    _products = await _db.getAllProducts();
    if (notify) notifyListeners();
  }

  Future<void> loadSales({bool notify = true}) async {
    _sales = await _db.getAllSales();
    if (notify) notifyListeners();
  }

  Future<void> saveSetting(String key, String value) async {
    try {
      await _db.saveSetting(key, value);
      await loadSettings();
    } catch (e) {
      developer.log("Failed to save setting", error: e);
      rethrow;
    }
  }

  Future<void> addMedicineType(String type) async {
    if (type.trim().isEmpty || _medicineTypes.contains(type.trim())) return;
    _medicineTypes.add(type.trim());
    await saveSetting('medicineTypes', _medicineTypes.join(','));
  }

  Future<void> removeMedicineType(String type) async {
    if (_medicineTypes.remove(type)) {
      await saveSetting('medicineTypes', _medicineTypes.join(','));
    }
  }

  // --- STOCK MANAGEMENT ---
  Future<List<StockBatch>> getBatchesForProduct(String productId) async {
    return await _db.getBatchesForProduct(productId);
  }

  Future<void> addBatch({
    required String productId,
    required String batchNumber,
    required DateTime expiryDate,
    required int strips,
    required int pcs,
    required int pcsPerStrip,
  }) async {
    final totalPcs = (strips * pcsPerStrip) + pcs;
    if (totalPcs <= 0) return;

    final batch = StockBatch(
      id: 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      batchNumber: batchNumber.isEmpty
          ? 'AUTO-${DateTime.now().millisecondsSinceEpoch}'
          : batchNumber,
      expiryDate: expiryDate,
      initialPieces: totalPcs,
      remainingPieces: totalPcs,
      dateAdded: DateTime.now(),
    );

    try {
      await _db.insertBatch(batch);
      await loadProducts(); // Only reload products, not sales/settings
      await checkForNotifications();
      scheduleSync(); // Trigger backup
    } catch (e) {
      developer.log("Failed to add batch", error: e);
      rethrow;
    }
  }

  Future<void> deleteBatch(String batchId) async {
    try {
      await _db.deleteBatch(batchId);
      await loadProducts();
      scheduleSync(); // Trigger backup
    } catch (e) {
      developer.log("Failed to delete batch", error: e);
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _db.updateProduct(product);
      await loadProducts();
      await checkForNotifications();
      scheduleSync();
    } catch (e) {
      developer.log("Failed to update product", error: e);
      rethrow;
    }
  }

  Future<void> addProduct(Product product, {String? initialBatchNumber}) async {
    try {
      await _db.insertProduct(product);

      final totalPcs = product.totalPieces;
      if (totalPcs > 0) {
        final now = DateTime.now();
        final batch = StockBatch(
          id: 'BATCH-${product.id}-1',
          productId: product.id,
          batchNumber:
              (initialBatchNumber != null && initialBatchNumber.isNotEmpty)
              ? initialBatchNumber
              : 'INIT-${now.millisecondsSinceEpoch}',
          expiryDate: product.expiryDate ?? now.add(const Duration(days: 365)),
          initialPieces: totalPcs,
          remainingPieces: totalPcs,
          dateAdded: now,
        );
        await _db.insertBatch(batch);
      }
      await loadProducts();
      await checkForNotifications();
      scheduleSync();
    } catch (e) {
      developer.log("Failed to add product", error: e);
      rethrow;
    }
  }

  Future<void> deleteProducts(List<String> productIds) async {
    try {
      await _db.deleteProducts(productIds);
      await loadProducts();
      scheduleSync();
    } catch (e) {
      developer.log("Failed to delete products", error: e);
      rethrow;
    }
  }

  Future<void> insertProductsBulk(List<BulkImportRecord> records) async {
    final List<Product> newProducts = [];
    final List<StockBatch> batches = [];
    final now = DateTime.now();

    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final imported = record.product;
      final totalPcs = imported.totalPieces;
      if (totalPcs <= 0) continue;

      // Try to find an existing product to merge stock into.
      Product? existing;

      // 1) Prefer matching by barcode if present.
      final barcode = imported.barcode;
      if (barcode != null && barcode.trim().isNotEmpty) {
        try {
          existing = await _db.getProductByBarcode(barcode.trim());
        } catch (_) {
          existing = null;
        }
      }

      // 2) Fallback: match by (name + generic) against already loaded products.
      if (existing == null) {
        for (final p in _products) {
          final sameName =
              p.name.trim().toLowerCase() == imported.name.trim().toLowerCase();
          final sameGeneric =
              p.generic.trim().toLowerCase() ==
                  imported.generic.trim().toLowerCase();
          final sameType = (p.medType ?? 'Tablet') == (imported.medType ?? 'Tablet');
          if (sameName && sameGeneric && sameType) {
            existing = p;
            break;
          }
        }
      }

      String targetProductId;

      if (existing != null) {
        targetProductId = existing.id;
      } else {
        targetProductId = imported.id;
        newProducts.add(imported);
      }

      final batchNumber = (record.batchNumber != null &&
              record.batchNumber!.trim().isNotEmpty)
          ? record.batchNumber!.trim()
          : 'INIT-BULK-${now.millisecondsSinceEpoch}-$i';

      batches.add(
        StockBatch(
          id: 'BATCH-$targetProductId-${now.millisecondsSinceEpoch}-$i',
          productId: targetProductId,
          batchNumber: batchNumber,
          expiryDate: record.expiryDate,
          initialPieces: totalPcs,
          remainingPieces: totalPcs,
          dateAdded: now,
        ),
      );
    }

    try {
      await _db.insertProductsBulk(newProducts, batches);
      await loadProducts();
      await checkForNotifications();
      scheduleSync();
    } catch (e) {
      developer.log("Failed to bulk insert products", error: e);
      rethrow;
    }
  }

  // --- QUERIES ---
  bool isProductLowStock(Product p) => p.stockStrips < p.minStockLevel;
  bool isProductExpiringSoon(Product p) =>
      p.daysUntilExpiry <= _expiringSoonDays;
  bool isProductExpiringCritical(Product p) =>
      p.daysUntilExpiry <= _criticalExpiryDays;

  InventoryAlertTier lowStockTierFor(Product p) => computeLowStockTier(p);

  InventoryAlertTier expiryTierFor(Product p) => computeExpiryTier(
        daysUntilExpiry: p.daysUntilExpiry,
        criticalExpiryDays: _criticalExpiryDays,
        moderateExpiryDays: _moderateExpiryDays,
        expiringSoonDays: _expiringSoonDays,
      );

  List<Product> get lowStockProducts {
    return _products.where((p) => isProductLowStock(p)).toList()
      ..sort((a, b) => a.stockStrips.compareTo(b.stockStrips));
  }

  List<Product> get expiringSoonProducts {
    return _products.where((p) => isProductExpiringSoon(p)).toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));
  }

  // --- SALES DATA ---
  List<SaleRecord> get allSales => _sales;

  List<SaleRecord> getSalesInRange(DateTime start, DateTime end) {
    return _sales
        .where(
          (s) =>
              s.date.isAfter(start) &&
              s.date.isBefore(end.add(const Duration(days: 1))),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get todaysSales {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _sales
        .where((s) => s.date.isAfter(todayStart))
        .fold(0.0, (sum, s) => sum + s.effectiveAmount);
  }

  int get todaysOrders {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _sales
        .where((s) => s.date.isAfter(todayStart) && s.effectiveQuantity > 0)
        .length;
  }

  double get weeklySales {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _sales
        .where((s) => s.date.isAfter(weekAgo))
        .fold(0.0, (sum, s) => sum + s.effectiveAmount);
  }

  /// Reload sales data (e.g., after a checkout on POS side).
  Future<void> refreshSales() async {
    await loadSales();
  }

  Future<bool> updatePin(String oldPin, String newPin) async {
    if (oldPin != _currentPin) return false;
    _currentPin = newPin;
    await saveSetting('adminPin', newPin);
    return true;
  }

  List<TopSellingProduct> getTopSellingProducts({
    required DateTime start,
    required DateTime end,
  }) {
    final Map<String, _TopSellingAcc> map = {};

    final filtered = _sales.where(
      (s) =>
          s.date.isAfter(start) &&
          s.date.isBefore(end.add(const Duration(days: 1))),
    );

    for (final s in filtered) {
      if (!map.containsKey(s.productName)) {
        map[s.productName] = _TopSellingAcc();
      }
      map[s.productName]!.quantity += s.effectiveQuantity;
      map[s.productName]!.revenue += s.effectiveAmount;
    }

    // Optimization: Create a hash map for O(1) product lookups instead of O(N) linear searches
    final Map<String, Product> productLookup = {
      for (var p in _products) p.name: p,
    };

    return map.entries
        .map((e) {
          final productName = e.key;
          final product = productLookup[productName]; // O(1) lookup

          return TopSellingProduct(
            name: productName,
            quantity: e.value.quantity,
            revenue: e.value.revenue,
            pcsPerStrip: product?.pcsPerStrip ?? 10,
            stripsPerBox: product?.stripsPerBox ?? 1,
          );
        })
        .where((p) => p.quantity > 0)
        .toList()
      ..sort((a, b) => b.boxesSold.compareTo(a.boxesSold));
  }
}

class _TopSellingAcc {
  int quantity = 0;
  double revenue = 0.0;
}

class TopSellingProduct {
  final String name;
  final int quantity;
  final double revenue;
  final int pcsPerStrip;
  final int stripsPerBox;

  TopSellingProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.pcsPerStrip,
    required this.stripsPerBox,
  });

  double get boxesSold {
    final pcsPerBox = pcsPerStrip * stripsPerBox;
    if (pcsPerBox <= 0) return 0.0;
    return quantity / pcsPerBox;
  }
}
