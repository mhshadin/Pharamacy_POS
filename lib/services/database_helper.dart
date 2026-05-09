import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'db_location_service.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_batch.dart';
import '../models/alarm_slot.dart';
import 'package:flutter/material.dart';

/// Thrown when the user has not chosen a database folder yet.
class DatabaseLocationNotConfigured implements Exception {
  @override
  String toString() => 'DatabaseLocationNotConfigured';
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const MethodChannel _dbStorageChannel = MethodChannel(
    'pharmacy_pos/db_storage',
  );
  String? _resolvedDbPath;
  final DbLocationService _dbLocation = DbLocationService();

  /// Opens SQLite after [DbLocationService] has a saved folder (or throws [DatabaseLocationNotConfigured]).
  Future<void> ensureDatabaseReady() async {
    await database;
  }

  /// Copies the runtime DB file back to the authoritative store (SAF tree or MediaStore).
  Future<void> syncRuntimeToAuthoritative() async {
    if (!Platform.isAndroid) return;
    try {
      final path = await _resolveCanonicalDatabasePath();
      if (!await File(path).exists()) return;
      final tree = await _dbLocation.getAndroidTreeUri();
      if (tree != null && tree.isNotEmpty) {
        await _dbStorageChannel.invokeMethod('syncRuntimeToTree', {
          'treeUri': tree,
          'runtimePath': path,
        });
      } else {
        await _dbStorageChannel.invokeMethod('syncRuntimeToPublicDb', {
          'runtimePath': path,
        });
      }
    } on PlatformException {
      // ignore
    } on DatabaseLocationNotConfigured {
      // ignore
    }
  }

  Future<bool> get usesAndroidCustomTree async {
    if (!Platform.isAndroid) return false;
    final t = await _dbLocation.getAndroidTreeUri();
    return t != null && t.isNotEmpty;
  }

  /// Android SAF folder picker; returns persisted tree `content://` URI or null if cancelled.
  Future<String?> pickAndroidDocumentTree() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _dbStorageChannel.invokeMethod<String>('pickDocumentTree');
    } on PlatformException {
      return null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> _mergeDuplicateProducts(Database db) async {
    final products = await db.query('products');

    // Group by lowercase name
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var p in products) {
      final name = (p['name'] as String).toLowerCase();
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(p);
    }

    final batch = db.batch();
    for (var entry in grouped.entries) {
      final group = entry.value;
      if (group.length > 1) {
        // Primary product is the first one
        final primaryId = group.first['id'] as String;

        // Transfer batches from duplicates to primary
        for (int i = 1; i < group.length; i++) {
          final duplicateId = group[i]['id'] as String;
          batch.update(
            'product_batches',
            {'productId': primaryId},
            where: 'productId = ?',
            whereArgs: [duplicateId],
          );

          // Delete the duplicate product
          batch.delete('products', where: 'id = ?', whereArgs: [duplicateId]);
        }
      }
    }
    await batch.commit(noResult: true);
  }

  Future<Database> _initDatabase() async {
    final path = await _resolveCanonicalDatabasePath();

    final db = await openDatabase(
      path,
      version: 17,
      onUpgrade: _onUpgrade,
      onCreate: _onCreate,
    );
    await syncRuntimeToAuthoritative();
    return db;
  }

  /// Gets the absolute path to the active database file.
  Future<String?> getDatabasePath() async {
    return _resolveCanonicalDatabasePath();
  }

  Future<String> _resolveCanonicalDatabasePath() async {
    if (_resolvedDbPath != null) return _resolvedDbPath!;

    final dir = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      final runtimePath = p.join(dir.path, 'pharmacy_runtime.db');
      final legacyPath = p.join(dir.path, 'pharmacy.db');
      final tree = await _dbLocation.getAndroidTreeUri();
      if (tree != null && tree.isNotEmpty) {
        try {
          await _dbStorageChannel.invokeMethod<Map<Object?, Object?>>(
            'prepareDbFromTree',
            {
              'treeUri': tree,
              'runtimePath': runtimePath,
              'legacyPath': legacyPath,
            },
          );
          _resolvedDbPath = runtimePath;
        } on PlatformException catch (e) {
          throw Exception('Failed to prepare custom database folder: ${e.message}');
        }
        return _resolvedDbPath!;
      }
      try {
        final result = await _dbStorageChannel.invokeMethod<Map<Object?, Object?>>(
          'prepareDatabasePath',
          {'runtimePath': runtimePath, 'legacyPath': legacyPath},
        );
        final resolved = result?['runtimePath'] as String?;
        _resolvedDbPath = (resolved != null && resolved.isNotEmpty)
            ? resolved
            : runtimePath;
      } on PlatformException catch (e) {
        throw Exception('Failed to prepare default database (Downloads): ${e.message}');
      }
      return _resolvedDbPath!;
    }

    final folder = await _dbLocation.getDesktopFolderPath();
    if (folder != null && folder.isNotEmpty) {
      _resolvedDbPath = p.join(folder, 'pharmacy.db');
    } else {
      _resolvedDbPath = p.join(dir.path, 'pharmacy.db');
    }
    return _resolvedDbPath!;
  }

  Future<Uint8List> readCanonicalDatabaseBytes() async {
    if (Platform.isAndroid) {
      final tree = await _dbLocation.getAndroidTreeUri();
      if (tree != null && tree.isNotEmpty) {
        try {
          final bytes = await _dbStorageChannel.invokeMethod<Uint8List>(
            'readTreeDbBytes',
            {'treeUri': tree},
          );
          if (bytes != null && bytes.isNotEmpty) {
            return bytes;
          }
        } on PlatformException {
          // Fall through to runtime file.
        }
      } else {
        try {
          final bytes = await _dbStorageChannel
              .invokeMethod<Uint8List>('readPublicDbBytes');
          if (bytes != null && bytes.isNotEmpty) {
            return bytes;
          }
        } on PlatformException {
          // Fall through to runtime file.
        }
      }
    }

    final path = await _resolveCanonicalDatabasePath();
    final file = File(path);
    if (!await file.exists()) {
      return Uint8List(0);
    }
    return file.readAsBytes();
  }

  Future<void> writeCanonicalDatabaseBytes(Uint8List bytes) async {
    final path = await _resolveCanonicalDatabasePath();
    final file = File(path);
    if (file.parent.existsSync() == false) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);

    if (Platform.isAndroid) {
      final tree = await _dbLocation.getAndroidTreeUri();
      if (tree != null && tree.isNotEmpty) {
        try {
          await _dbStorageChannel.invokeMethod('writeTreeDbBytes', {
            'treeUri': tree,
            'bytes': bytes,
          });
        } on PlatformException {
          // Runtime file is authoritative for this session.
        }
      } else {
        try {
          await _dbStorageChannel.invokeMethod('writePublicDbBytes', {
            'bytes': bytes,
          });
        } on PlatformException {
          // Runtime file updated.
        }
      }
    }
  }

  /// Closes the active DB handle and clears cached connection.
  /// Also deletes any WAL / SHM sidecar files so that a freshly written
  /// database file is never corrupted by stale journal data.
  Future<void> resetConnection() async {
    String? pathBeforeReset = _resolvedDbPath;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _resolvedDbPath = null;

    // Delete stale WAL/SHM files that belong to the just-closed database.
    // If left on disk they are replayed on the next openDatabase() call and
    // can silently overwrite a freshly imported file with old data.
    if (pathBeforeReset != null) {
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$pathBeforeReset$suffix');
        if (await sidecar.exists()) {
          try {
            await sidecar.delete();
          } catch (_) {
            // Best-effort: ignore if the OS refuses (e.g. another handle open).
          }
        }
      }
    }
  }

  /// Persists a new DB folder (or clears to default), writes [bytes] there, and resets the connection.
  Future<void> applyNewDatabaseLocation({
    required Uint8List bytes,
    String? androidTreeUri,
    String? desktopFolderPath,
  }) async {
    await resetConnection();
    if (Platform.isAndroid) {
      if (androidTreeUri != null && androidTreeUri.isNotEmpty) {
        await _dbLocation.setAndroidTreeUri(androidTreeUri);
      } else {
        await _dbLocation.clearAndroidTreeUri();
      }
    } else {
      if (desktopFolderPath != null && desktopFolderPath.isNotEmpty) {
        await _dbLocation.setDesktopFolderPath(desktopFolderPath);
      } else {
        await _dbLocation.clearDesktopFolderPath();
      }
    }
    await writeCanonicalDatabaseBytes(bytes);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // Add invoiceNumber to sales if it doesn't already exist
        await db.execute('ALTER TABLE sales ADD COLUMN invoiceNumber TEXT');
      } catch (e) {
        // Ignore duplicate column errors (in case of interrupted migrations/hot restarts)
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }

      try {
        // Create invoice counter table if it doesn't exist
        await db.execute('''
          CREATE TABLE IF NOT EXISTS invoice_counter (
            date TEXT PRIMARY KEY,
            counter INTEGER DEFAULT 0
          )
        ''');
      } catch (e) {
        // Ignore table exists errors
      }
    }

    if (oldVersion < 3) {
      // 1. Add pcsPerStrip to products
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN pcsPerStrip INTEGER DEFAULT 10',
        );
      } catch (_) {}

      // 2. Add batch tracking fields to sales
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN batchNumber TEXT');
        await db.execute(
          'ALTER TABLE sales ADD COLUMN isReturned INTEGER DEFAULT 0',
        );
      } catch (_) {}

      // 3. Create product_batches table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_batches (
          id TEXT PRIMARY KEY,
          productId TEXT NOT NULL,
          batchNumber TEXT NOT NULL,
          expiryDate TEXT NOT NULL,
          initialPieces INTEGER NOT NULL,
          remainingPieces INTEGER NOT NULL,
          dateAdded TEXT NOT NULL,
          FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');

      // 4. Migrate existing stock to a legacy batch
      final products = await db.query('products');
      final nowStr = DateTime.now().toIso8601String();
      final batch = db.batch();
      for (final p in products) {
        final stStrips = (p['stockStrips'] as int?) ?? 0;
        final stPcs = (p['stockPcs'] as int?) ?? 0;
        final pcsPerStrip = (p['pcsPerStrip'] as int?) ?? 10;
        final totalPcs = (stStrips * pcsPerStrip) + stPcs;
        if (totalPcs > 0) {
          final expDate =
              p['expiryDate'] as String? ??
              DateTime.now().add(const Duration(days: 365)).toIso8601String();
          batch.insert('product_batches', {
            'id': 'LEGACY-${p['id']}',
            'productId': p['id'],
            'batchNumber': 'LEGACY',
            'expiryDate': expDate,
            'initialPieces': totalPcs,
            'remainingPieces': totalPcs,
            'dateAdded': nowStr,
          });
        }
      }
      await batch.commit(noResult: true);
    }

    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN returnedQuantity INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN priceBox REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE products ADD COLUMN stripsPerBox INTEGER DEFAULT 1',
        );
      } catch (_) {}
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN supplierName TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN supplierPhone TEXT');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      await _mergeDuplicateProducts(db);
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN companyName TEXT');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN medType TEXT');
        await db.execute('ALTER TABLE sales ADD COLUMN medType TEXT');
      } catch (_) {}
    }



    if (oldVersion < 12) {
      // Add per-batch cost price tracking
      try {
        await db.execute(
          'ALTER TABLE product_batches ADD COLUMN costPricePerPc REAL DEFAULT 0',
        );
      } catch (_) {}
      // Store cost at time of sale for accurate historical profit reporting
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN costPricePerPc REAL DEFAULT 0',
        );
      } catch (_) {}
    }



    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alarm_slots (
          id TEXT PRIMARY KEY,
          hour INTEGER NOT NULL,
          minute INTEGER NOT NULL,
          days TEXT NOT NULL,
          isEnabled INTEGER DEFAULT 1
        )
      ''');
      // Ensure products table has costPricePerPc for existing users
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN costPricePerPc REAL DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN power TEXT');
      } catch (_) {}
    }

    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN power TEXT');
      } catch (_) {}
    }

    if (oldVersion < 17) {
      await _ensureProductOcrIndexes(db);
    }
  }

  /// Case-insensitive prefix seeks for OCR candidate funnel (LIKE 'pre%' COLLATE NOCASE).
  Future<void> _ensureProductOcrIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_generic ON products(generic COLLATE NOCASE)',
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        generic TEXT NOT NULL,
        priceStrip REAL NOT NULL,
        pricePc REAL NOT NULL,
        priceBox REAL DEFAULT 0,
        pcsPerStrip INTEGER DEFAULT 10,
        stripsPerBox INTEGER DEFAULT 1,
        stockStrips INTEGER DEFAULT 0,
        stockPcs INTEGER DEFAULT 0,
        expiryDate TEXT,
        barcode TEXT,
        minStockLevel INTEGER DEFAULT 20,
        companyName TEXT,
        supplierName TEXT,
        supplierPhone TEXT,
        medType TEXT,
        power TEXT,
        costPricePerPc REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE alarm_slots (
        id TEXT PRIMARY KEY,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        days TEXT NOT NULL,
        isEnabled INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE product_batches (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        batchNumber TEXT NOT NULL,
        expiryDate TEXT NOT NULL,
        initialPieces INTEGER NOT NULL,
        remainingPieces INTEGER NOT NULL,
        dateAdded TEXT NOT NULL,
        costPricePerPc REAL DEFAULT 0,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        invoiceNumber TEXT,
        batchNumber TEXT,
        isReturned INTEGER DEFAULT 0,
        returnedQuantity INTEGER DEFAULT 0,
        medType TEXT,
        power TEXT,
        costPricePerPc REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_counter (
        date TEXT PRIMARY KEY,
        counter INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed initial products on first launch
    await _seedProducts(db);
    await _ensureProductOcrIndexes(db);
  }

  Future<void> _seedProducts(Database db) async {
    final now = DateTime.now();
    final seeds = [
      {
        'id': '1',
        'name': 'Paracetamol',
        'generic': '500mg • Analgesic',
        'priceStrip': 2.50,
        'pricePc': 0.25,
        'pcsPerStrip': 10,
        'stockStrips': 12,
        'stockPcs': 120,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567890',
        'minStockLevel': 20,
      },
      {
        'id': '2',
        'name': 'Amoxicillin',
        'generic': '250mg • Antibiotic',
        'priceStrip': 5.00,
        'pricePc': 0.50,
        'stockStrips': 145,
        'stockPcs': 1450,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567891',
        'minStockLevel': 20,
      },
      {
        'id': '3',
        'name': 'Cetirizine',
        'generic': '10mg • Antihistamine',
        'priceStrip': 3.00,
        'pricePc': 0.30,
        'stockStrips': 89,
        'stockPcs': 890,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567892',
        'minStockLevel': 20,
      },
      {
        'id': '4',
        'name': 'Omeprazole',
        'generic': '20mg • Proton Pump Inhibitor',
        'priceStrip': 4.50,
        'pricePc': 0.45,
        'stockStrips': 8,
        'stockPcs': 80,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567893',
        'minStockLevel': 15,
      },
      {
        'id': '5',
        'name': 'Metformin',
        'generic': '500mg • Antidiabetic',
        'priceStrip': 3.50,
        'pricePc': 0.35,
        'stockStrips': 200,
        'stockPcs': 2000,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567894',
        'minStockLevel': 20,
      },
      {
        'id': '6',
        'name': 'Azithromycin',
        'generic': '500mg • Antibiotic',
        'priceStrip': 12.00,
        'pricePc': 2.00,
        'stockStrips': 5,
        'stockPcs': 30,
        'expiryDate': now.add(const Duration(days: 365 * 2)).toIso8601String(),
        'barcode': '8901234567895',
        'minStockLevel': 10,
      },
      {
        'id': '7',
        'name': 'Ibuprofen',
        'generic': '400mg • NSAID',
        'priceStrip': 2.00,
        'pricePc': 0.20,
        'stockStrips': 67,
        'stockPcs': 670,
        'expiryDate': now.add(const Duration(days: 180)).toIso8601String(),
        'barcode': '8901234567896',
        'minStockLevel': 20,
      },
      {
        'id': '8',
        'name': 'Ranitidine',
        'generic': '150mg • H2 Blocker',
        'priceStrip': 2.80,
        'pricePc': 0.28,
        'stockStrips': 3,
        'stockPcs': 30,
        'expiryDate': now.add(const Duration(days: 10)).toIso8601String(),
        'barcode': '8901234567897',
        'minStockLevel': 25,
      },
      {
        'id': '9',
        'name': 'Losartan',
        'generic': '50mg • ARB Antihypertensive',
        'priceStrip': 6.00,
        'pricePc': 0.60,
        'stockStrips': 110,
        'stockPcs': 1100,
        'expiryDate': now.add(const Duration(days: 300)).toIso8601String(),
        'barcode': '8901234567898',
        'minStockLevel': 20,
      },
      {
        'id': '10',
        'name': 'Salbutamol Inhaler',
        'generic': '100mcg • Bronchodilator',
        'priceStrip': 8.00,
        'pricePc': 8.00,
        'stockStrips': 18,
        'stockPcs': 18,
        'expiryDate': now.add(const Duration(days: 75)).toIso8601String(),
        'barcode': '8901234567899',
        'minStockLevel': 10,
      },
    ];

    final batch = db.batch();
    for (final seed in seeds) {
      batch.insert('products', seed);

      final stStrips = (seed['stockStrips'] as int?) ?? 0;
      final stPcs = (seed['stockPcs'] as int?) ?? 0;
      final pcsPerStrip = (seed['pcsPerStrip'] as int?) ?? 10;
      final totalPcs = (stStrips * pcsPerStrip) + stPcs;

      batch.insert('product_batches', {
        'id': 'BATCH-${seed['id']}-1',
        'productId': seed['id'],
        'batchNumber': 'SEED-BATCH-1',
        'expiryDate': seed['expiryDate'],
        'initialPieces': totalPcs,
        'remainingPieces': totalPcs,
        'dateAdded': now.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  // ───────── BATCH METHODS ─────────

  Future<void> insertBatch(StockBatch stockBatch) async {
    final db = await database;
    await db.insert(
      'product_batches',
      stockBatch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBatchCostPrice(String batchId, double costPrice) async {
    final db = await database;
    await db.update(
      'product_batches',
      {'costPricePerPc': costPrice},
      where: 'id = ?',
      whereArgs: [batchId],
    );
  }

  Future<List<StockBatch>> getBatchesForProduct(String productId) async {
    final db = await database;
    final maps = await db.query(
      'product_batches',
      where: 'productId = ? AND remainingPieces > 0',
      whereArgs: [productId],
      orderBy: 'expiryDate ASC',
    );
    return maps.map((m) => StockBatch.fromMap(m)).toList();
  }

  Future<void> updateBatchRemainingPieces(
    String batchId,
    int newRemaining,
  ) async {
    final db = await database;
    await db.update(
      'product_batches',
      {'remainingPieces': newRemaining},
      where: 'id = ?',
      whereArgs: [batchId],
    );
  }

  /// Active batches drive [Product.expiryDate] via [_populateProductStock]; keep them in sync when
  /// the user edits expiry on the product so the change survives reload.
  Future<void> updateActiveBatchesExpiryDate(
    String productId,
    DateTime expiry,
  ) async {
    final db = await database;
    await db.update(
      'product_batches',
      {'expiryDate': expiry.toIso8601String()},
      where: 'productId = ? AND remainingPieces > 0',
      whereArgs: [productId],
    );
  }

  Future<void> deleteBatch(String batchId) async {
    final db = await database;
    await db.delete('product_batches', where: 'id = ?', whereArgs: [batchId]);
  }

  // ───────── PRODUCT METHODS ─────────

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final products = maps.map((m) => Product.fromMap(m)).toList();
    for (var p in products) {
      await _populateProductStock(p, db);
    }
    return products;
  }

  Future<Product?> getProductById(String id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return await _populateProductStock(Product.fromMap(maps.first), db);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode IS NOT NULL AND LOWER(barcode) = LOWER(?)',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return await _populateProductStock(Product.fromMap(maps.first), db);
  }

  /// Lowercases, trims, and collapses whitespace for OCR funnel matching.
  static String normalizeOcrTextForCandidates(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Strips characters that break or widen LIKE patterns unintentionally.
  static String _sanitizeLikePrefix(String s) {
    return s.replaceAll(RegExp(r'[%_\\]'), '');
  }

  /// Prefix + optional token-contains fallback; deduped by product id, capped at [limit].
  /// Uses indexed `LIKE 'prefix%' COLLATE NOCASE` first; if too few hits, adds `%token%` OR rows (capped).
  Future<List<Product>> getCandidatesForOcr(String ocrText, {int limit = 40}) async {
    final norm = normalizeOcrTextForCandidates(ocrText);
    if (norm.isEmpty) return [];

    final parts = norm.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final firstWord = parts.isNotEmpty ? parts.first : norm;
    final sanitized = _sanitizeLikePrefix(firstWord);
    if (sanitized.isEmpty) return [];

    final prefixLen = sanitized.length >= 4 ? 4 : sanitized.length;
    final prefix = sanitized.substring(0, prefixLen);

    final db = await database;
    final orderedIds = <String>[];
    final byId = <String, Map<String, dynamic>>{};

    void ingestRows(List<Map<String, dynamic>> rows) {
      for (final m in rows) {
        final id = m['id'] as String;
        if (byId.containsKey(id)) continue;
        byId[id] = m;
        orderedIds.add(id);
      }
    }

    final prefixPattern = '$prefix%';
    final prefixRows = await db.rawQuery(
      '''
      SELECT * FROM products
      WHERE name LIKE ? COLLATE NOCASE OR generic LIKE ? COLLATE NOCASE
      LIMIT ?
      ''',
      [prefixPattern, prefixPattern, limit],
    );
    ingestRows(prefixRows);

    const minPrefixHits = 10;
    if (byId.length < minPrefixHits && byId.length < limit) {
      final tokens = norm
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 3)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      final useTokens = tokens.take(3).toList();
      if (useTokens.isNotEmpty) {
        final clauses = <String>[];
        final wideArgs = <Object>[];
        for (final tok in useTokens) {
          final t = _sanitizeLikePrefix(tok);
          if (t.isEmpty) continue;
          final pat = '%$t%';
          clauses.add(
            '(name LIKE ? COLLATE NOCASE OR generic LIKE ? COLLATE NOCASE)',
          );
          wideArgs.add(pat);
          wideArgs.add(pat);
        }
        if (clauses.isNotEmpty) {
          wideArgs.add(limit);
          final wideRows = await db.rawQuery(
            'SELECT * FROM products WHERE ${clauses.join(' OR ')} LIMIT ?',
            wideArgs,
          );
          ingestRows(wideRows);
        }
      }
    }

    final products = orderedIds.map((id) => Product.fromMap(byId[id]!)).toList();
    if (products.length > limit) {
      products.removeRange(limit, products.length);
    }
    await _populateProductsStockBatch(products, db);
    return products;
  }

  Future<void> _populateProductsStockBatch(List<Product> products, Database db) async {
    if (products.isEmpty) return;
    final ids = products.map((p) => p.id).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final allMaps = await db.query(
      'product_batches',
      where: 'productId IN ($placeholders)',
      whereArgs: ids,
    );
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in allMaps) {
      final pid = m['productId'] as String;
      grouped.putIfAbsent(pid, () => []).add(m);
    }
    for (final p in products) {
      _applyBatchesToProduct(p, grouped[p.id] ?? const []);
    }
  }

  void _applyBatchesToProduct(Product product, List<Map<String, dynamic>> batchMaps) {
    int totalPcs = 0;
    DateTime? nearestExpiry;

    for (final b in batchMaps) {
      final int remaining = (b['remainingPieces'] as int?) ?? 0;
      totalPcs += remaining;

      if (remaining > 0) {
        final String? expiryStr = b['expiryDate'] as String?;
        if (expiryStr != null) {
          final DateTime expiry = DateTime.parse(expiryStr);
          if (nearestExpiry == null || expiry.isBefore(nearestExpiry)) {
            nearestExpiry = expiry;
          }
        }
      }
    }

    product.stockStrips = totalPcs ~/ product.pcsPerStrip;
    product.stockPcs = totalPcs % product.pcsPerStrip;

    if (nearestExpiry != null) {
      product.expiryDate = nearestExpiry;
    }
  }

  Future<Product?> getProductByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return await _populateProductStock(Product.fromMap(maps.first), db);
  }

  Future<Product> _populateProductStock(Product product, Database db) async {
    final batchMaps = await db.query(
      'product_batches',
      where: 'productId = ?',
      whereArgs: [product.id],
    );
    _applyBatchesToProduct(product, batchMaps);
    return product;
  }

  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertProductsBulk(
    List<Product> products,
    List<StockBatch> batches,
  ) async {
    final db = await database;
    final dbBatch = db.batch();

    for (var product in products) {
      dbBatch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (var stockBatch in batches) {
      dbBatch.insert(
        'product_batches',
        stockBatch.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await dbBatch.commit(noResult: true);
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProducts(List<String> productIds) async {
    if (productIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(productIds.length, '?').join(',');
    await db.delete(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: productIds,
    );
  }

  // ───────── SALES METHODS ─────────

  Future<void> insertSale(SaleRecord sale) async {
    final db = await database;
    await db.insert(
      'sales',
      sale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Completes a new sale built from [cart] in one transaction:
  /// 1) Generates a single invoice number for this transaction
  /// 2) Deducts stock from available batches
  /// 3) Inserts sale records
  Future<String> completeSale(List<CartItem> cart) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    return await db.transaction((txn) async {
      // 1) Generate next invoice number inside transaction.
      final counterResult = await txn.query(
        'invoice_counter',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      var nextCount = 1;
      if (counterResult.isEmpty) {
        await txn.insert('invoice_counter', {'date': dateStr, 'counter': 1});
      } else {
        nextCount = ((counterResult.first['counter'] as int?) ?? 0) + 1;
        await txn.update(
          'invoice_counter',
          {'counter': nextCount},
          where: 'date = ?',
          whereArgs: [dateStr],
        );
      }
      final newInvoice = 'INV-$dateStr-${nextCount.toString().padLeft(3, '0')}';

      // 2) Insert sale rows and deduct stock
      for (final item in cart) {
        var totalPiecesToDeduct =
            (item.stripQuantity * item.product.pcsPerStrip) + item.pcQuantity;
        if (totalPiecesToDeduct <= 0) continue;

        final totalItemAmount = item.total;
        final originalTotalPieces = totalPiecesToDeduct;

        final batches = await txn.query(
          'product_batches',
          where: 'productId = ? AND remainingPieces > 0',
          whereArgs: [item.product.id],
          orderBy: 'expiryDate ASC',
        );

        for (final batch in batches) {
          if (totalPiecesToDeduct <= 0) break;
          final remaining = (batch['remainingPieces'] as int?) ?? 0;
          final deductAmount = remaining < totalPiecesToDeduct
              ? remaining
              : totalPiecesToDeduct;
          if (deductAmount <= 0) continue;

          final batchAmount = (deductAmount / originalTotalPieces) * totalItemAmount;
          await txn.insert(
            'sales',
            SaleRecord(
              id:
                  'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-${batch['id']}',
              productName: item.product.name,
              quantity: deductAmount,
              amount: batchAmount,
              date: DateTime.now(),
              invoiceNumber: newInvoice,
              batchNumber: batch['batchNumber'] as String?,
              medType: item.product.medType,
              power: item.product.power,
              costPricePerPc: (batch['costPricePerPc'] as num?)?.toDouble() ?? 0.0,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          await txn.update(
            'product_batches',
            {'remainingPieces': remaining - deductAmount},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );

          totalPiecesToDeduct -= deductAmount;
        }

        // Preserve old behavior for oversold remainder.
        if (totalPiecesToDeduct > 0) {
          final oversoldAmount =
              (totalPiecesToDeduct / originalTotalPieces) * totalItemAmount;
          await txn.insert(
            'sales',
            SaleRecord(
              id:
                  'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-OVERSOLD',
              productName: item.product.name,
              quantity: totalPiecesToDeduct,
              amount: oversoldAmount,
              date: DateTime.now(),
              invoiceNumber: newInvoice,
              batchNumber: 'OVERSOLD',
              medType: item.product.medType,
              power: item.product.power,
              costPricePerPc: 0.0,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      return newInvoice;
    });
  }
  /// Replaces an existing invoice with a new sale built from [cart] in one
  /// transaction:
  /// 1) restore stock for the old invoice's active (non-returned) quantities,
  /// 2) hard-delete old invoice rows,
  /// 3) create a fresh invoice and deduct stock for current cart items.
  Future<String> completeReplacementSale({
    required List<CartItem> cart,
    required String sourceInvoiceNumber,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    return await db.transaction((txn) async {
      // 1) Restore stock from old invoice active quantities.
      final oldMaps = await txn.query(
        'sales',
        where: 'LOWER(invoiceNumber) = LOWER(?)',
        whereArgs: [sourceInvoiceNumber],
      );
      for (final map in oldMaps) {
        final sale = SaleRecord.fromMap(map);
        final restoreQty = sale.effectiveQuantity;
        if (restoreQty <= 0) continue;
        if (sale.batchNumber == null ||
            sale.batchNumber!.isEmpty ||
            sale.batchNumber == 'OVERSOLD') {
          continue;
        }
        final batchMaps = await txn.query(
          'product_batches',
          where:
              'batchNumber IS NOT NULL AND LOWER(batchNumber) = LOWER(?)',
          whereArgs: [sale.batchNumber],
          limit: 1,
        );
        if (batchMaps.isEmpty) continue;
        final batch = batchMaps.first;
        final remaining = (batch['remainingPieces'] as int?) ?? 0;
        await txn.update(
          'product_batches',
          {'remainingPieces': remaining + restoreQty},
          where: 'id = ?',
          whereArgs: [batch['id']],
        );
      }

      // 2) Hard-delete all old invoice rows.
      await txn.delete(
        'sales',
        where: 'LOWER(invoiceNumber) = LOWER(?)',
        whereArgs: [sourceInvoiceNumber],
      );

      // 3) Generate next invoice number inside same transaction.
      final counterResult = await txn.query(
        'invoice_counter',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      var nextCount = 1;
      if (counterResult.isEmpty) {
        await txn.insert('invoice_counter', {'date': dateStr, 'counter': 1});
      } else {
        nextCount = ((counterResult.first['counter'] as int?) ?? 0) + 1;
        await txn.update(
          'invoice_counter',
          {'counter': nextCount},
          where: 'date = ?',
          whereArgs: [dateStr],
        );
      }
      final newInvoice = 'INV-$dateStr-${nextCount.toString().padLeft(3, '0')}';

      // 4) Insert replacement sale rows and deduct stock from available batches.
      for (final item in cart) {
        var totalPiecesToDeduct =
            (item.stripQuantity * item.product.pcsPerStrip) + item.pcQuantity;
        if (totalPiecesToDeduct <= 0) continue;

        final totalItemAmount = item.total;
        final originalTotalPieces = totalPiecesToDeduct;

        final batches = await txn.query(
          'product_batches',
          where: 'productId = ? AND remainingPieces > 0',
          whereArgs: [item.product.id],
          orderBy: 'expiryDate ASC',
        );

        for (final batch in batches) {
          if (totalPiecesToDeduct <= 0) break;
          final remaining = (batch['remainingPieces'] as int?) ?? 0;
          final deductAmount = remaining < totalPiecesToDeduct
              ? remaining
              : totalPiecesToDeduct;
          if (deductAmount <= 0) continue;

          final batchAmount = (deductAmount / originalTotalPieces) * totalItemAmount;
          await txn.insert(
            'sales',
            SaleRecord(
              id:
                  'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-${batch['id']}',
              productName: item.product.name,
              quantity: deductAmount,
              amount: batchAmount,
              date: DateTime.now(),
              invoiceNumber: newInvoice,
              batchNumber: batch['batchNumber'] as String?,
              medType: item.product.medType,
              power: item.product.power,
              costPricePerPc: (batch['costPricePerPc'] as num?)?.toDouble() ?? 0.0,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          await txn.update(
            'product_batches',
            {'remainingPieces': remaining - deductAmount},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );

          totalPiecesToDeduct -= deductAmount;
        }

        // Preserve old behavior for oversold remainder.
        if (totalPiecesToDeduct > 0) {
          final oversoldAmount =
              (totalPiecesToDeduct / originalTotalPieces) * totalItemAmount;
          await txn.insert(
            'sales',
            SaleRecord(
              id:
                  'ORD-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}-OVERSOLD',
              productName: item.product.name,
              quantity: totalPiecesToDeduct,
              amount: oversoldAmount,
              date: DateTime.now(),
              invoiceNumber: newInvoice,
              batchNumber: 'OVERSOLD',
              medType: item.product.medType,
              power: item.product.power,
              costPricePerPc: 0.0,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      return newInvoice;
    });
  }

  Future<List<SaleRecord>> getSalesByInvoice(String invoiceQuery) async {
    final db = await database;
    if (invoiceQuery.isEmpty) {
      final maps = await db.query('sales', orderBy: 'date DESC');
      return maps.map((m) => SaleRecord.fromMap(m)).toList();
    }
    // LIKE + COLLATE NOCASE: explicit case-insensitive match on invoice / line name
    final maps = await db.rawQuery(
      '''
      SELECT * FROM sales
      WHERE invoiceNumber LIKE ? COLLATE NOCASE OR productName LIKE ? COLLATE NOCASE
      ORDER BY date DESC
      ''',
      ['%$invoiceQuery%', '%$invoiceQuery%'],
    );
    return maps.map((m) => SaleRecord.fromMap(m)).toList();
  }

  Future<void> returnSale(SaleRecord sale, int returnQty) async {
    final db = await database;

    final newReturnedQty = sale.returnedQuantity + returnQty;
    final isFullyReturned = newReturnedQty >= sale.quantity;

    // Both the sale-flag update and the stock restore run inside one
    // transaction so the DB is never left in a half-returned state if
    // the app is killed between the two writes.
    await db.transaction((txn) async {
      // 1. Mark sale as returned.
      await txn.update(
        'sales',
        {
          'isReturned': isFullyReturned ? 1 : 0,
          'returnedQuantity': newReturnedQty,
        },
        where: 'id = ?',
        whereArgs: [sale.id],
      );

      // 2. Restore stock to the originating batch.
      if (sale.batchNumber != null &&
          sale.batchNumber!.isNotEmpty &&
          sale.batchNumber != 'OVERSOLD') {
        final batchMaps = await txn.query(
          'product_batches',
          where:
              'batchNumber IS NOT NULL AND LOWER(batchNumber) = LOWER(?)',
          whereArgs: [sale.batchNumber],
        );
        if (batchMaps.isNotEmpty) {
          final batch = batchMaps.first;
          final int remaining = batch['remainingPieces'] as int;
          await txn.update(
            'product_batches',
            {'remainingPieces': remaining + returnQty},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );
        }
      }
    });
  }

  /// Voids an entire invoice by fully returning every sale record in [sales].
  /// For each record, marks returnedQuantity = quantity (fully returned) and
  /// restores the stock to the original batch. Call this before loading an
  /// invoice into the cart for replacement, so the Sales Report is not inflated.
  Future<void> voidInvoice(List<SaleRecord> sales) async {
    final db = await database;
    for (final sale in sales) {
      final remainingQty = sale.quantity - sale.returnedQuantity;
      if (remainingQty <= 0) continue; // already fully returned

      // Mark fully returned
      await db.update(
        'sales',
        {'isReturned': 1, 'returnedQuantity': sale.quantity},
        where: 'id = ?',
        whereArgs: [sale.id],
      );

      // Restore stock to batch
      if (sale.batchNumber != null &&
          sale.batchNumber!.isNotEmpty &&
          sale.batchNumber != 'OVERSOLD') {
        final batchMaps = await db.query(
          'product_batches',
          where:
              'batchNumber IS NOT NULL AND LOWER(batchNumber) = LOWER(?)',
          whereArgs: [sale.batchNumber],
        );
        if (batchMaps.isNotEmpty) {
          final batch = batchMaps.first;
          final int remaining = batch['remainingPieces'] as int;
          await db.update(
            'product_batches',
            {'remainingPieces': remaining + remainingQty},
            where: 'id = ?',
            whereArgs: [batch['id']],
          );
        }
      }
    }
  }

  Future<List<SaleRecord>> getAllSales() async {
    final db = await database;
    final maps = await db.query('sales', orderBy: 'date DESC');
    return maps.map((m) => SaleRecord.fromMap(m)).toList();
  }

  Future<List<SaleRecord>> getSalesInRange(DateTime start, DateTime end) async {
    final db = await database;
    // Ensure 'end' captures the entire day without bleeding into the next 24 hours.
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final maps = await db.query(
      'sales',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        start.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return maps.map((m) => SaleRecord.fromMap(m)).toList();
  }

  Future<List<SaleRecord>> getSalesSince(DateTime since) async {
    final db = await database;
    final maps = await db.query(
      'sales',
      where: 'date >= ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((m) => SaleRecord.fromMap(m)).toList();
  }

  Future<String> getNextInvoiceNumber() async {
    final db = await database;
    final now = DateTime.now();
    // format YYYYMMDD
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    return await db.transaction((txn) async {
      // Get current counter for today
      final List<Map<String, dynamic>> result = await txn.query(
        'invoice_counter',
        where: 'date = ?',
        whereArgs: [dateStr],
      );

      int nextCount = 1;
      if (result.isEmpty) {
        // First invoice today
        await txn.insert('invoice_counter', {
          'date': dateStr,
          'counter': nextCount,
        });
      } else {
        // Increment counter
        nextCount = (result.first['counter'] as int) + 1;
        await txn.update(
          'invoice_counter',
          {'counter': nextCount},
          where: 'date = ?',
          whereArgs: [dateStr],
        );
      }

      // return formatted INV-YYYYMMDD-NNN
      return 'INV-$dateStr-${nextCount.toString().padLeft(3, '0')}';
    });
  }

  // ───────── SETTINGS METHODS ─────────

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  // ───────── PROFIT / COST HELPERS ─────────

  /// Returns the cost price per piece from the most recently added batch
  /// for a product. Returns 0.0 if no batches exist or none have a price set.
  /// Used to pre-fill the buying price field when restocking.
  Future<double> getLastBatchCostPrice(String productId) async {
    final db = await database;
    final maps = await db.query(
      'product_batches',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'dateAdded DESC',
      limit: 1,
    );
    if (maps.isEmpty) return 0.0;
    return (maps.first['costPricePerPc'] as num?)?.toDouble() ?? 0.0;
  }

  /// Updates the costPricePerPc for all batches of a product that still have stock.
  Future<void> updateActiveBatchesCostPrice(
    String productId,
    double newCostPricePerPc,
  ) async {
    final db = await database;
    await db.update(
      'product_batches',
      {'costPricePerPc': newCostPricePerPc},
      where: 'productId = ? AND remainingPieces > 0',
      whereArgs: [productId],
    );
  }

  // ───────── ALARM SLOTS ─────────

  Future<void> insertAlarmSlot(AlarmSlot slot) async {
    final db = await database;
    await db.insert(
      'alarm_slots',
      {
        'id': slot.id,
        'hour': slot.time.hour,
        'minute': slot.time.minute,
        'days': slot.days.join(','),
        'isEnabled': slot.isEnabled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAlarmSlot(String id) async {
    final db = await database;
    await db.delete('alarm_slots', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AlarmSlot>> getAllAlarmSlots() async {
    final db = await database;
    final maps = await db.query('alarm_slots');
    return maps.map((m) {
      final daysStr = m['days'] as String;
      return AlarmSlot(
        id: m['id'] as String,
        time: TimeOfDay(hour: m['hour'] as int, minute: m['minute'] as int),
        days: daysStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toSet(),
        isEnabled: (m['isEnabled'] as int) == 1,
      );
    }).toList();
  }
}

