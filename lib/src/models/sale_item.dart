import '../models/product.dart'; // Necesario para la relación

class SaleItem {
  final int? id; // Nullable para inserción
  final int saleId; // FK a Sale (no debe ser nulo)
  final int productId; // FK a Product (no debe ser nulo)
  final int quantity; // Cantidad vendida
  final double unitPriceUsd; // Precio unitario en USD al momento de la venta
  final double unitPriceVes; // Precio unitario en VES al momento de la venta
  final double subtotalUsd; // quantity * unitPriceUsd
  final double subtotalVes; // quantity * unitPriceVes
  final DateTime? createdAt; // Gestionado por la BD

  // Campo opcional para mostrar información relacionada (no mapeado a DB directamente)
  final Product? product;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPriceUsd,
    required this.unitPriceVes,
    required this.subtotalUsd,
    required this.subtotalVes,
    this.createdAt,
    // Para datos relacionados
    this.product,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price_usd': unitPriceUsd,
      'unit_price_ves': unitPriceVes,
      'subtotal_usd': subtotalUsd,
      'subtotal_ves': subtotalVes,
      // createdAt gestionado por DB
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      unitPriceUsd: (map['unit_price_usd'] as num).toDouble(),
      unitPriceVes: (map['unit_price_ves'] as num).toDouble(),
      subtotalUsd: (map['subtotal_usd'] as num).toDouble(),
      subtotalVes: (map['subtotal_ves'] as num).toDouble(),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      // El objeto product no se carga desde este fromMap
    );
  }

  @override
  String toString() {
    return 'SaleItem(id: $id, saleId: $saleId, productId: $productId, quantity: $quantity, unitPriceUsd: $unitPriceUsd, unitPriceVes: $unitPriceVes)';
  }

  // Método copyWith
  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? quantity,
    double? unitPriceUsd,
    double? unitPriceVes,
    double? subtotalUsd,
    double? subtotalVes,
    Product? product,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPriceUsd: unitPriceUsd ?? this.unitPriceUsd,
      unitPriceVes: unitPriceVes ?? this.unitPriceVes,
      subtotalUsd: subtotalUsd ?? this.subtotalUsd,
      subtotalVes: subtotalVes ?? this.subtotalVes,
      createdAt: createdAt,
      product: product ?? this.product,
    );
  }
} 