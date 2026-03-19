class Product {
  final String id;
  final String name;
  final String generic;
  final double priceStrip;
  final double pricePc;
  final double priceBox;
  final int pcsPerStrip;
  final int stripsPerBox;
  int stockStrips;
  int stockPcs;
  DateTime? expiryDate;
  final String? barcode;
  final int minStockLevel;
  final String? companyName;
  final String? supplierName;
  final String? supplierPhone;

  /// Cached phonetic hash used by voice search matching.
  /// Computed once at load time by ProductMatcher.precomputeHashes().
  /// Never persisted to the database.
  String? phoneticHash;

  Product({
    required this.id,
    required this.name,
    required this.generic,
    required this.priceStrip,
    required this.pricePc,
    this.priceBox = 0,
    this.pcsPerStrip = 10,
    this.stripsPerBox = 1,
    this.stockStrips = 0,
    this.stockPcs = 0,
    this.expiryDate,
    this.barcode,
    this.minStockLevel = 20,
    this.companyName,
    this.supplierName,
    this.supplierPhone,
  });

  int get totalPieces => (stockStrips * pcsPerStrip) + stockPcs;
  int get stockBoxes => stripsPerBox > 0 ? stockStrips ~/ stripsPerBox : 0;
  int get remainingStrips => stripsPerBox > 0 ? stockStrips % stripsPerBox : 0;

  // NOTE: isLowStock, isExpiringSoon, and isExpiringSoonCritical logic
  // have been moved to AdminProvider to support dynamic thresholds from the settings table.

  int get daysUntilExpiry {
    if (expiryDate == null) return 9999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'generic': generic,
      'priceStrip': priceStrip,
      'pricePc': pricePc,
      'priceBox': priceBox,
      'pcsPerStrip': pcsPerStrip,
      'stripsPerBox': stripsPerBox,
      // 'stockStrips' and 'stockPcs' are NOT saved to the DB, they are accumulated dynamically
      'expiryDate': expiryDate?.toIso8601String(),
      'barcode': barcode,
      'minStockLevel': minStockLevel,
      'companyName': companyName,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      generic: map['generic'] as String,
      priceStrip: (map['priceStrip'] as num).toDouble(),
      pricePc: (map['pricePc'] as num).toDouble(),
      priceBox: (map['priceBox'] as num?)?.toDouble() ?? 0,
      pcsPerStrip: map['pcsPerStrip'] as int? ?? 10,
      stripsPerBox: map['stripsPerBox'] as int? ?? 1,
      // Default to 0, will be immediately overwritten by _populateProductStock
      stockStrips: 0,
      stockPcs: 0,
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
      barcode: map['barcode'] as String?,
      minStockLevel: map['minStockLevel'] as int? ?? 20,
      companyName: map['companyName'] as String?,
      supplierName: map['supplierName'] as String?,
      supplierPhone: map['supplierPhone'] as String?,
    );
  }
}
