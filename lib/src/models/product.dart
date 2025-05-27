class Product {
  final int? id;
  final String name;
  final String description;
  final String? sku;
  final String? barcode;
  final int categoryId;
  final int supplierId;
  final double costPriceUsd;
  final double purchasePriceUsd;
  final double profitMargin;
  final double sellingPriceUsd;
  final double sellingPriceVes;
  final int currentStock;
  final int stock;
  final int minStock;
  final bool isVatExempt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    this.id,
    required this.name,
    this.description = '',
    this.sku,
    this.barcode,
    required this.categoryId,
    required this.supplierId,
    required this.costPriceUsd,
    required this.purchasePriceUsd,
    required this.profitMargin,
    required this.sellingPriceUsd,
    required this.sellingPriceVes,
    this.currentStock = 0,
    this.stock = 0,
    this.minStock = 0,
    this.isVatExempt = false,
    this.createdAt,
    this.updatedAt,
  });

  static double calculateSellingPrice(double purchasePriceUsd, double profitMargin) {
    if (purchasePriceUsd <= 0 || profitMargin < 0) {
      return purchasePriceUsd;
    }
    final result = purchasePriceUsd * (1 + profitMargin);
    // Redondear a 2 decimales
    return double.parse(result.toStringAsFixed(2));
  }

  // Método para calcular el precio final con IVA si corresponde
  static double calculateFinalPrice(double basePrice, bool isVatEnabled, double taxRate, {bool isProductExempt = false}) {
    // Si el producto está exento o el IVA está deshabilitado globalmente, no aplicar IVA
    if (isProductExempt || !isVatEnabled || taxRate <= 0) {
      return basePrice; // Devolver el precio base sin IVA
    }
    final priceWithTax = basePrice * (1 + taxRate);
    // Redondear a 2 decimales
    return double.parse(priceWithTax.toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null && id! > 0) 'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'cost_price_usd': costPriceUsd,
      'purchase_price_usd': purchasePriceUsd,
      'profit_margin': profitMargin,
      'selling_price_usd': sellingPriceUsd,
      'selling_price_ves': sellingPriceVes,
      'current_stock': currentStock,
      'stock': stock,
      'min_stock': minStock,
      'created_at': createdAt?.toIso8601String() ?? now,
      'updated_at': updatedAt?.toIso8601String() ?? now,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    try {
      return Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        sku: map['sku'] as String?,
        barcode: map['barcode'] as String?,
        categoryId: (map['category_id'] == null) ? 0 : (map['category_id'] as int),
        supplierId: (map['supplier_id'] == null) ? 0 : (map['supplier_id'] as int),
        costPriceUsd: (map['cost_price_usd'] as num?)?.toDouble() ?? 0.0,
        purchasePriceUsd: (map['purchase_price_usd'] as num).toDouble(),
        profitMargin: (map['profit_margin'] as num).toDouble(),
        sellingPriceUsd: (map['selling_price_usd'] as num).toDouble(),
        sellingPriceVes: (map['selling_price_ves'] as num).toDouble(),
        currentStock: map['current_stock'] as int? ?? 0,
        stock: map['stock'] as int? ?? 0,
        minStock: map['min_stock'] as int? ?? 0,
        isVatExempt: map.containsKey('is_vat_exempt') ? (map['is_vat_exempt'] as int? ?? 0) == 1 : false,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
      );
    } catch (e) {
      print('Error al convertir el mapa en producto: $e');
      print('Mapa con error: $map');
      rethrow;
    }
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    int? categoryId,
    int? supplierId,
    double? costPriceUsd,
    double? purchasePriceUsd,
    double? profitMargin,
    double? sellingPriceUsd,
    double? sellingPriceVes,
    int? currentStock,
    int? stock,
    int? minStock,
    bool? isVatExempt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      costPriceUsd: costPriceUsd ?? this.costPriceUsd,
      purchasePriceUsd: purchasePriceUsd ?? this.purchasePriceUsd,
      profitMargin: profitMargin ?? this.profitMargin,
      sellingPriceUsd: sellingPriceUsd ?? this.sellingPriceUsd,
      sellingPriceVes: sellingPriceVes ?? this.sellingPriceVes,
      currentStock: currentStock ?? this.currentStock,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      isVatExempt: isVatExempt ?? this.isVatExempt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 