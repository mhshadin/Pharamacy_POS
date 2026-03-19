class StockBatch {
  final String id;
  final String productId;
  final String batchNumber;
  final DateTime expiryDate;
  final int initialPieces;
  int remainingPieces;
  final DateTime dateAdded;

  StockBatch({
    required this.id,
    required this.productId,
    required this.batchNumber,
    required this.expiryDate,
    required this.initialPieces,
    required this.remainingPieces,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate.toIso8601String(),
      'initialPieces': initialPieces,
      'remainingPieces': remainingPieces,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    return StockBatch(
      id: map['id'] as String,
      productId: map['productId'] as String,
      batchNumber: map['batchNumber'] as String,
      expiryDate: DateTime.parse(map['expiryDate'] as String),
      initialPieces: map['initialPieces'] as int,
      remainingPieces: map['remainingPieces'] as int,
      dateAdded: DateTime.parse(map['dateAdded'] as String),
    );
  }

  /// Helper to check if this batch is expired
  bool get isExpired => expiryDate.isBefore(DateTime.now());

  /// Helper to check if batch is fully sold/depleted
  bool get isDepleted => remainingPieces <= 0;
}
