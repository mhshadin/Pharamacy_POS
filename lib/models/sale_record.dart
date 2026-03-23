class SaleRecord {
  final String id;
  final String productName;
  final int quantity;
  final double amount;
  final DateTime date;
  final String? invoiceNumber;
  final String? batchNumber;
  final bool isReturned;
  final int returnedQuantity;
  final String? medType;

  SaleRecord({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.amount,
    required this.date,
    this.invoiceNumber,
    this.batchNumber,
    this.isReturned = false,
    this.returnedQuantity = 0,
    this.medType,
  });

  int get effectiveQuantity => quantity - returnedQuantity;
  double get effectiveAmount =>
      quantity > 0 ? (amount / quantity) * effectiveQuantity : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productName': productName,
      'quantity': quantity,
      'amount': amount,
      'date': date.toIso8601String(),
      'invoiceNumber': invoiceNumber,
      'batchNumber': batchNumber,
      'isReturned': isReturned ? 1 : 0,
      'returnedQuantity': returnedQuantity,
      'medType': medType,
    };
  }

  factory SaleRecord.fromMap(Map<String, dynamic> map) {
    return SaleRecord(
      id: map['id'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      invoiceNumber: map['invoiceNumber'] as String?,
      batchNumber: map['batchNumber'] as String?,
      isReturned: (map['isReturned'] as int?) == 1,
      returnedQuantity: map['returnedQuantity'] as int? ?? 0,
      medType: map['medType'] as String?,
    );
  }
}
