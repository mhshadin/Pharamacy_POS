import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_batch.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/drive_service.dart';
import '../services/auth_storage.dart';
import '../services/auth_service.dart';
import '../services/google_drive_auth.dart';
import '../services/time_service.dart';
import '../utils/inventory_alert_tiers.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _adminBiometricEnabled = false;
  int _defaultOrderBoxes = 100;
  List<String> _medicineTypes = [];
  static const List<String> defaultMedicineTypes = [
    'Tablet',
    'Syrup',
    'Injection',
    'Capsule',
    'Cream',
    'Ointment',
    'Drops',
    'Inhaler',
    'Gel',
    'Spray',
    'Powder',
    'Suppository',
  ];

  // Extra Reminder Alarm
  bool _extraReminderEnabled = false;
  List<int> _reminderDays = []; // 1 (Mon) to 7 (Sun)
  TimeOfDay _reminderTime = const TimeOfDay(hour: 10, minute: 0);
  String? _reminderAudioPath;

  // Google Drive Sync
  String? _googleDriveFileId;
  String? _googleDriveFolderId;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _syncError;
  Timer? _syncDebounce;
  String _productSearchQuery = '';
  String _productSortBy = 'Name (A-Z)';
  final Set<String> _selectedCompanies = {};
  final Set<String> _selectedGenerics = {};
  final Set<String> _selectedTypes = {};

  // Track notified products to avoid redundant alerts
  final Set<String> _notifiedLowStockIds = {};
  final Set<String> _notifiedExpiringIds = {};

  // Track products that the user has "seen" by opening the notification screen
  Set<String> _readLowStockIds = {};
  Set<String> _readExpiringIds = {};

  AuthSession? _authSession;

  /// Reloads the authentication session from storage.
  /// Called after login or when tokens are rotated.
  Future<void> reloadAuthSession() async {
    developer.log("AdminProvider: Reloading auth session from storage...");
    _authSession = await const AuthStorage().loadAuth();
    notifyListeners();
    developer.log("AdminProvider: Session reloaded. RefreshToken present: ${_authSession?.refreshToken.isNotEmpty}");
  }

  bool get isAdminLoggedIn => _isAdminLoggedIn;
  AuthSession? get authSession => _authSession;
  List<Product> get allProducts => _products;

  int get lowStockThreshold => _lowStockThreshold;
  int get expiringSoonDays => _expiringSoonDays;
  int get criticalExpiryDays => _criticalExpiryDays;
  int get moderateExpiryDays => _moderateExpiryDays;
  int get expiryDelayMonths => _expiryDelayMonths;
  bool get showSupplierInfo => _showSupplierInfo;
  bool get adminBiometricEnabled => _adminBiometricEnabled;
  int get defaultOrderBoxes => _defaultOrderBoxes;
  List<String> get medicineTypes => _medicineTypes;

  String? get googleDriveFileId => _googleDriveFileId;
  String? get googleDriveFolderId => _googleDriveFolderId;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;

  bool get extraReminderEnabled => _extraReminderEnabled;
  List<int> get reminderDays => _reminderDays;
  TimeOfDay get reminderTime => _reminderTime;
  String? get reminderAudioPath => _reminderAudioPath;

  // Product Filtering & Sorting Getters
  String get searchQuery => _productSearchQuery;
  String get sortBy => _productSortBy;
  Set<String> get selectedCompanies => _selectedCompanies;
  Set<String> get selectedGenerics => _selectedGenerics;
  Set<String> get selectedTypes => _selectedTypes;

  bool get isFilterEmpty =>
      _productSearchQuery.isEmpty &&
      _selectedCompanies.isEmpty &&
      _selectedGenerics.isEmpty &&
      _selectedTypes.isEmpty;

  List<String> get allTypes =>
      _products.map((p) => p.medType ?? 'Tablet').toSet().toList()..sort();

  Product? getProductByName(String name, {String? medType}) {
    try {
      return _products.firstWhere((p) {
        final sameName =
            p.name.trim().toLowerCase() == name.trim().toLowerCase();
        if (medType != null) {
          return sameName && (p.medType ?? 'Tablet') == medType;
        }
        return sameName;
      });
    } catch (_) {
      return null;
    }
  }

  bool login(String pin) {
    if (pin == _currentPin) {
      _isAdminLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Call only after [BiometricAuthService.authenticate] succeeds.
  void completeBiometricLogin() {
    _isAdminLoggedIn = true;
    notifyListeners();
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
      await fetchBackendAdminPin();
      notifyListeners();
      await checkForNotifications();
      await checkSubscriptionStatus();
    } catch (e) {
      checkSubscriptionStatus();
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
      if (!_notifiedLowStockIds.contains(p.id) &&
          !_readLowStockIds.contains(p.id)) {
        await service.showLowStockAlert(p.name, p.stockStrips);
        _notifiedLowStockIds.add(p.id);
      }
    }
    // Clear tracking for products that are no longer low stock
    _notifiedLowStockIds.removeWhere(
      (id) => !_products.any((p) => p.id == id && isProductLowStock(p)),
    );
    _readLowStockIds.removeWhere(
      (id) => !_products.any((p) => p.id == id && isProductLowStock(p)),
    );

    // 2. Handle Expiry Alerts
    for (final p in expiringSoon) {
      // Only show OS notification if it hasn't been notified AND isn't already "read"
      if (!_notifiedExpiringIds.contains(p.id) &&
          !_readExpiringIds.contains(p.id)) {
        final expiryStr =
            p.expiryDate?.toLocal().toString().split(' ')[0] ?? 'Unknown';
        await service.showExpiryAlert(p.name, expiryStr);
        _notifiedExpiringIds.add(p.id);
      }
    }
    // Clear tracking for products that are no longer expiring soon
    _notifiedExpiringIds.removeWhere(
      (id) => !_products.any((p) => p.id == id && isProductExpiringSoon(p)),
    );
    _readExpiringIds.removeWhere(
      (id) => !_products.any((p) => p.id == id && isProductExpiringSoon(p)),
    );

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
    final unreadLowStock = lowStockProducts
        .where((p) => !_readLowStockIds.contains(p.id))
        .length;
    final unreadExpiring = expiringSoonProducts
        .where((p) => !_readExpiringIds.contains(p.id))
        .length;
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
    _adminBiometricEnabled = settings['adminBiometricEnabled'] == 'true';
    _defaultOrderBoxes =
        int.tryParse(settings['defaultOrderBoxes'] ?? '') ?? 100;

    // Load auth session for user info
    _authSession = await const AuthStorage().loadAuth();

    // Load local PIN
    _currentPin = settings['adminPin'] ?? '12345';

    // Load read notification IDs
    final readLowStockStr = settings['readLowStockIds'] ?? '';
    _readLowStockIds = readLowStockStr
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();

    final readExpiringStr = settings['readExpiringIds'] ?? '';
    _readExpiringIds = readExpiringStr
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();

    final medTypesStr = settings['medicineTypes'] ?? '';
    if (medTypesStr.isEmpty) {
      _medicineTypes = List.from(defaultMedicineTypes);
    } else {
      _medicineTypes = medTypesStr
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    _googleDriveFileId = await _db.getSetting('googleDriveFileId');
    _googleDriveFolderId = await _db.getSetting('googleDriveFolderId');
    final lastSyncStr = await _db.getSetting('googleDriveLastSync');
    if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }

    _extraReminderEnabled = (await _db.getSetting('extraReminderEnabled')) == 'true';
    final daysStr = await _db.getSetting('reminderDays') ?? '';
    _reminderDays = daysStr.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
    final timeStr = await _db.getSetting('reminderTime') ?? '10:00';
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _reminderAudioPath = await _db.getSetting('reminderAudioPath');

    if (notify) notifyListeners();
  }

  /// Secure Just-In-Time fetch of Admin PIN from backend
  Future<void> fetchBackendAdminPin() async {
    if (_authSession == null) return;
    
    bool needRetry = false;
    try {
      final backendPin = await const AuthService().getAdminPin(
        _authSession!.licenseToken,
      );
      if (backendPin != _currentPin) {
        _currentPin = backendPin;
        await _db.saveSetting('adminPin', backendPin);
      }
    } on AuthException catch (e) {
      if (e.statusCode == 401) {
        needRetry = true;
      } else {
        developer.log("Failed to fetch admin PIN from backend", error: e);
      }
    } catch (e) {
      developer.log("Failed to fetch admin PIN from backend", error: e);
    }

    if (needRetry) {
      try {
        // Attempt JWT Refresh
        developer.log("JWT expired, attempting auto-refresh...");
        final result = await const AuthService().refreshJwtToken(
          _authSession!.refreshToken,
        );
        
        // Update storage (this saves both the new license_token and the new rotated refresh_token)
        await const AuthStorage().saveAuth(result);
        
        // Reload in-memory auth session so UI uses the new tokens
        _authSession = await const AuthStorage().loadAuth();
        notifyListeners();

        // Retry the PIN fetch with the fresh token
        final backendPin = await const AuthService().getAdminPin(
          _authSession!.licenseToken,
        );
        if (backendPin != _currentPin) {
          _currentPin = backendPin;
          await _db.saveSetting('adminPin', backendPin);
        }
        developer.log("JWT auto-refresh and retry successful.");
      } catch (retryException) {
        developer.log("JWT retry failure on admin PIN", error: retryException);
      }
    }
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
  Future<void> scheduleSync({bool immediate = false}) async {
    if (immediate) {
      _syncDebounce?.cancel();
      await _performDriveSync();
    } else {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(minutes: 5), () {
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

    // Attempt a silent token refresh. On failure, we no longer fall back to the
    // stored token, as it is almost certainly expired (tokens last 1 hour).
    final googleToken = await refreshGoogleAccessToken();
    if (googleToken == null) {
      _syncError = "Google Drive session expired. Please reconnect in Settings.";
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final dbPath = await _db.getDatabasePath();
      if (dbPath == null) {
        _syncError = "Could not find database path";
        notifyListeners();
        return;
      }

      final driveService = DriveService();

      _googleDriveFolderId = await driveService.getOrCreateFolder(
        accessToken: googleToken,
        folderName: 'Pharmacy POS Backups',
      );
      await saveSetting('googleDriveFolderId', _googleDriveFolderId!);

      final newFileId = await driveService.uploadDatabaseToDrive(
        accessToken: googleToken,
        dbFilePath: dbPath,
        fileId: _googleDriveFileId,
        folderId: _googleDriveFolderId,
      );

      _googleDriveFileId = newFileId;
      await saveSetting('googleDriveFileId', newFileId);

      await _performLocalExport(dbPath);

      _lastSyncTime = DateTime.now();
      await saveSetting('lastSyncTime', _lastSyncTime!.toIso8601String());
    } catch (e, stack) {
      developer.log("Drive Sync Exception", error: e, stackTrace: stack);
      final errMsg = e.toString().toLowerCase();
      if (errMsg.contains('401') || errMsg.contains('unauthorized') || errMsg.contains('403')) {
        _syncError = "Google Drive session expired. Please sign in again.";
      } else {
        _syncError = e.toString();
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _performLocalExport(String dbPath) async {
    try {
      final File dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return;
      }

      final Uint8List bytes = await dbFile.readAsBytes();
      final String fileName = "pharmacy_backup";

      // Save using FileSaver to the public Downloads folder on Android
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'db',
        mimeType: MimeType.other,
      );

      // Saved to $savedPath
    } catch (e, stack) {
      developer.log("Local export failed", error: e, stackTrace: stack);
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
      rethrow;
    }
  }

  /// Manually imports a database file and replaces the current one.
  Future<void> importDatabaseLocally(String filePath) async {
    try {
      final currentDbPath = await _db.getDatabasePath();
      if (currentDbPath == null) {
        throw Exception("Could not find current DB path");
      }

      // Safety check - verify it's a valid sqlite file if possible or just proceed
      final importFile = File(filePath);
      if (!await importFile.exists()) throw Exception("Import file not found");

      await importFile.copy(currentDbPath);

      // Reload everything
      await loadData();
    } catch (e) {
      rethrow;
    }
  }

  /// Searches for and downloads a backup from Drive after login.
  Future<void> checkAndRestoreFromDrive() async {
    final googleToken = _authSession?.googleAccessToken;
    if (googleToken == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final driveService = DriveService();

      // 1. Find the folder
      final folderId = await driveService.getOrCreateFolder(
        accessToken: googleToken,
        folderName: 'Pharmacy POS Backups',
      );
      _googleDriveFolderId = folderId;
      await saveSetting('googleDriveFolderId', folderId);

      // 2. Find the file in that folder
      // We'll search for 'pharmacy.db' in that folder
      final searchUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q='
        '\'$folderId\' in parents and name = \'pharmacy.db\' and trashed = false'
        '&fields=files(id, name)',
      );

      final response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $googleToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List files = data['files'] ?? [];
        if (files.isNotEmpty) {
          final fileId = files.first['id'] as String;
          _googleDriveFileId = fileId;
          await saveSetting('googleDriveFileId', fileId);

          // 3. Download the file
          final dbPath = await _db.getDatabasePath();
          if (dbPath != null) {
            final downloadUri = Uri.parse(
              'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
            );
            final downloadResponse = await http.get(
              downloadUri,
              headers: {'Authorization': 'Bearer $googleToken'},
            );

            if (downloadResponse.statusCode == 200) {
              await File(dbPath).writeAsBytes(downloadResponse.bodyBytes);
              await loadData();
            } else {
              developer.log(
                "Download failed with status ${downloadResponse.statusCode}",
              );
            }
          }
        }
      }
    } catch (e, stack) {
      developer.log("Restore from Drive failed", error: e, stackTrace: stack);
    } finally {
      _isSyncing = false;
      notifyListeners();
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
          final sameType =
              (p.medType ?? 'Tablet') == (imported.medType ?? 'Tablet');
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

      final batchNumber =
          (record.batchNumber != null && record.batchNumber!.trim().isNotEmpty)
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

  // --- Product List State Management ---
  void setSearchQuery(String query) {
    _productSearchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _productSortBy = sort;
    notifyListeners();
  }

  void toggleCompanyFilter(String company) {
    if (_selectedCompanies.contains(company)) {
      _selectedCompanies.remove(company);
    } else {
      _selectedCompanies.add(company);
    }
    notifyListeners();
  }

  void toggleGenericFilter(String generic) {
    if (_selectedGenerics.contains(generic)) {
      _selectedGenerics.remove(generic);
    } else {
      _selectedGenerics.add(generic);
    }
    notifyListeners();
  }

  void toggleTypeFilter(String type) {
    if (_selectedTypes.contains(type)) {
      _selectedTypes.remove(type);
    } else {
      _selectedTypes.add(type);
    }
    notifyListeners();
  }

  void clearFilters() {
    _productSearchQuery = '';
    _selectedCompanies.clear();
    _selectedGenerics.clear();
    _selectedTypes.clear();
    notifyListeners();
  }

  Future<bool> updatePin(String oldPin, String newPin) async {
    if (oldPin != _currentPin) return false;

    // 1. Update backend if logged in
    if (_authSession != null) {
      try {
        await const AuthService().updateAdminPin(
          token: _authSession!.licenseToken,
          newPin: newPin,
        );
      } catch (e) {
        developer.log("Failed to sync admin PIN to backend", error: e);
        // We still proceed with local update for offline usability,
        // but user might want to know it didn't sync.
      }
    }

    // 2. Update local
    _currentPin = newPin;
    await saveSetting('adminPin', newPin);
    return true;
  }

  /// Updates the user's display name on the backend, then persists and
  /// refreshes the in-memory auth session so all UI rebuilds immediately.
  Future<void> updateProfileName(String newName) async {
    if (_authSession == null) throw Exception('Not authenticated.');

    final updated = await const AuthService().updateProfile(
      token: _authSession!.licenseToken,
      fullName: newName,
    );

    final resolvedName = updated['name'] ?? newName;
    final resolvedAvatar = updated['avatar'];

    await const AuthStorage().updateNameAndAvatar(
      resolvedName,
      avatarUrl: resolvedAvatar,
    );

    _authSession = await const AuthStorage().loadAuth();
    notifyListeners();
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

  // --- SUBSCRIPTION MONITORING ---

  Future<void> checkSubscriptionStatus() async {
    final session = _authSession;
    if (session == null || session.subscriptionValidUntil.isEmpty) return;

    try {
      final validUntil = DateTime.parse(session.subscriptionValidUntil);
      final now = DateTime.now();

      // Calculate remaining days
      final remainingDays = validUntil.difference(now).inDays;

      // 1. If expired, handle it
      if (remainingDays < 0) return;

      // 2. Check for warnings (7, 5, 1 days)
      final thresholds = [7, 5, 1];
      if (thresholds.contains(remainingDays)) {
        final lastWarning = await TimeService().getLastWarningDate();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        if (lastWarning != todayStr) {
          _pendingSubWarningDays = remainingDays;
          await TimeService().saveWarningDate(todayStr);
          notifyListeners();
        }
      }
    } catch (e) {
      // Removed print statement as per instruction
    }
  }

  int? _pendingSubWarningDays;
  int? get pendingSubWarningDays => _pendingSubWarningDays;

  void clearPendingWarning() {
    _pendingSubWarningDays = null;
    notifyListeners();
  }

  // --- EXTRA REMINDER ALARM LOGIC ---

  Future<void> toggleExtraReminder(bool enabled) async {
    _extraReminderEnabled = enabled;
    await saveSetting('extraReminderEnabled', enabled.toString());
    if (enabled) {
      await scheduleAllAlarms();
    } else {
      await cancelAllAlarms();
    }
    notifyListeners();
  }

  Future<void> updateReminderDays(List<int> days) async {
    _reminderDays = days;
    await saveSetting('reminderDays', days.join(','));
    if (_extraReminderEnabled) {
      await scheduleAllAlarms();
    }
    notifyListeners();
  }

  Future<void> updateReminderTime(TimeOfDay time) async {
    _reminderTime = time;
    await saveSetting('reminderTime', '${time.hour}:${time.minute}');
    if (_extraReminderEnabled) {
      await scheduleAllAlarms();
    }
    notifyListeners();
  }

  Future<void> updateReminderAudioPath(String? path) async {
    if (path == null) {
      _reminderAudioPath = null;
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.split(Platform.isWindows ? '\\' : '/').last;
        final newPath = '${appDir.path}/$fileName';
        final file = File(path);
        
        // Only copy if it's a new path and not already in app documents
        if (path != newPath) {
          await file.copy(newPath);
          _reminderAudioPath = newPath;
        } else {
          _reminderAudioPath = path;
        }
      } catch (e) {
        developer.log("Error copying audio file: $e");
        _reminderAudioPath = path; // Fallback to original path if copy fails
      }
    }
    await saveSetting('reminderAudioPath', _reminderAudioPath ?? '');
    if (_extraReminderEnabled) {
      await scheduleAllAlarms();
    }
    notifyListeners();
  }

  Future<void> scheduleAllAlarms() async {
    await cancelAllAlarms();
    if (!_extraReminderEnabled || _reminderDays.isEmpty) return;

    for (final day in _reminderDays) {
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        _reminderTime.hour,
        _reminderTime.minute,
      );

      // Find the next occurrence of this day
      // now.weekday is 1-7 (Mon-Sun)
      int daysUntil = day - now.weekday;
      if (daysUntil < 0 || (daysUntil == 0 && scheduledDate.isBefore(now))) {
        daysUntil += 7;
      }
      scheduledDate = scheduledDate.add(Duration(days: daysUntil));

      final alarmSettings = AlarmSettings(
        id: day, // Unique ID per weekday 1-7
        dateTime: scheduledDate,
        assetAudioPath: _reminderAudioPath ?? 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        notificationSettings: const NotificationSettings(
          title: 'Stock & Expiry Reminder',
          body: 'Check your inventory for low stock or expiring meds.',
          stopButton: 'Dismiss',
        ),
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 3),
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
      );

      await Alarm.set(alarmSettings: alarmSettings);
      developer.log("Scheduled alarm for day $day at $scheduledDate");
    }
  }

  Future<void> cancelAllAlarms() async {
    for (int i = 1; i <= 7; i++) {
      await Alarm.stop(i);
    }
  }

  /// Triggers an interactive Google Sign-In to refresh the session token.
  Future<void> reconnectGoogle() async {
    try {
      final account = await googleSignInClient.signIn();
      if (account == null) return; // User canceled

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) {
        await const AuthStorage().setGoogleAccessToken(token);
        _syncError = null;
        notifyListeners();
        // Immediately try a sync with the fresh token
        await scheduleSync(immediate: true);
      }
    } catch (e) {
      _syncError = "Failed to sign in to Google: $e";
      notifyListeners();
    }
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
