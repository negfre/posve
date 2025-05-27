class InventoryMovement {
  final int? id;
  final int productId;
  final String type; // 'purchase' o 'sale'
  final int quantity; // Positivo para compra, negativo para venta (se manejará en lógica)
  final DateTime movementDate;
  final double unitPriceUsd; // Precio base USD al momento del mov.
  final double unitPriceVes; // Precio en VES al momento del mov.
  final double exchangeRate; // Tasa de cambio al momento del mov.
  final int? supplierId; // Relevante para compras

  InventoryMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.movementDate,
    required this.unitPriceUsd,
    required this.unitPriceVes,
    required this.exchangeRate,
    this.supplierId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'movement_date': movementDate.toIso8601String(),
      'unit_price_usd': unitPriceUsd,
      'unit_price_ves': unitPriceVes,
      'exchange_rate': exchangeRate,
      'supplier_id': supplierId,
    };
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    return InventoryMovement(
      id: map['id'],
      productId: map['product_id'],
      type: map['type'],
      quantity: map['quantity'] ?? 0,
      movementDate: DateTime.parse(map['movement_date'] ?? DateTime.now().toIso8601String()),
      unitPriceUsd: map['unit_price_usd']?.toDouble() ?? 0.0,
      unitPriceVes: map['unit_price_ves']?.toDouble() ?? 0.0,
      exchangeRate: map['exchange_rate']?.toDouble() ?? 1.0,
      supplierId: map['supplier_id'],
    );
  }
} 