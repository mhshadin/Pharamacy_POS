import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_batch.dart';
import '../models/alarm_slot.dart';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

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
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/pharmacy.db';

    return await openDatabase(
      path,
      version: 16,
      onUpgrade: _onUpgrade,
      onCreate: _onCreate,
    );
  }

  /// Gets the absolute path to the active database file.
  Future<String?> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/pharmacy.db';
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

    if (oldVersion < 11) {
      // Ensure columns exist just in case version 10 was skipped or failed
      try {
        await db.execute('ALTER TABLE products ADD COLUMN medType TEXT');
      } catch (_) {}
      try {
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

    if (oldVersion < 13) {
      // Robust check for missing cost tracking columns
      try {
        await db.execute(
          'ALTER TABLE product_batches ADD COLUMN costPricePerPc REAL DEFAULT 0',
        );
      } catch (_) {}
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
        'expiryDate': now.add(const Duration(days: 25)).toIso8601String(),
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
        'expiryDate': now.add(const Duration(days: 365)).toIso8601String(),
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
        'expiryDate': now.add(const Duration(days: 200)).toIso8601String(),
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
        'expiryDate': now.add(const Duration(days: 60)).toIso8601String(),
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
        'expiryDate': now.add(const Duration(days: 400)).toIso8601String(),
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
        'expiryDate': now.add(const Duration(days: 15)).toIso8601String(),
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
    final maps = await db.query('products', orderBy: 'name ASC');
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
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return await _populateProductStock(Product.fromMap(maps.first), db);
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

  Future<List<SaleRecord>> getSalesByInvoice(String invoiceQuery) async {
    final db = await database;
    if (invoiceQuery.isEmpty) {
      final maps = await db.query('sales', orderBy: 'date DESC', limit: 50);
      return maps.map((m) => SaleRecord.fromMap(m)).toList();
    }
    // Use LIKE for partial matching to be more forgiving with typos
    final maps = await db.query(
      'sales',
      where: 'invoiceNumber LIKE ? OR productName LIKE ?',
      whereArgs: ['%$invoiceQuery%', '%$invoiceQuery%'],
      orderBy: 'date DESC',
      limit: 50,
    );
    return maps.map((m) => SaleRecord.fromMap(m)).toList();
  }

  Future<void> returnSale(SaleRecord sale, int returnQty) async {
    final db = await database;

    final newReturnedQty = sale.returnedQuantity + returnQty;
    final isFullyReturned = newReturnedQty >= sale.quantity;

    // 1. Mark as returned
    await db.update(
      'sales',
      {
        'isReturned': isFullyReturned ? 1 : 0,
        'returnedQuantity': newReturnedQty,
      },
      where: 'id = ?',
      whereArgs: [sale.id],
    );

    // 2. Find batch and add stock back
    if (sale.batchNumber != null &&
        sale.batchNumber!.isNotEmpty &&
        sale.batchNumber != 'OVERSOLD') {
      final batchMaps = await db.query(
        'product_batches',
        where: 'batchNumber = ?',
        whereArgs: [sale.batchNumber],
      );
      if (batchMaps.isNotEmpty) {
        final batch = batchMaps.first;
        final int remaining = batch['remainingPieces'] as int;
        await db.update(
          'product_batches',
          {'remainingPieces': remaining + returnQty},
          where: 'id = ?',
          whereArgs: [batch['id']],
        );
      }
    }
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
          where: 'batchNumber = ?',
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
    final maps = await db.query(
      'sales',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
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

