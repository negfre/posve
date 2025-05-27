import '../models/client.dart'; // Necesario para la relación
import '../models/payment_method.dart'; // Necesario para la relación

class Sale {
  final int? id; // Nullable para inserción
  final String invoiceNumber; // Número de factura/nota de entrega (debe ser único)
  final int? clientId; // FK a Client (nullable si es consumidor final)
  final int paymentMethodId; // FK a PaymentMethod (no puede ser nulo)
  final double subtotal; // Suma de subtotales de los items (sin impuesto)
  final double taxRate; // Tasa de impuesto aplicada (ej: 0.16)
  final double taxAmount; // Monto del impuesto calculado (subtotal * taxRate)
  final double total; // Monto final (subtotal + taxAmount)
  final double exchangeRate; // Tasa de cambio al momento de la venta
  final DateTime saleDate; // Fecha y hora de la venta
  final String? paymentDetails; // Detalles adicionales del pago (referencia, banco, etc.)
  final DateTime? createdAt; // Gestionado por la BD
  final DateTime? updatedAt; // Gestionado por la BD

  // Campos opcionales para mostrar información relacionada (no mapeados a DB directamente)
  final Client? client; 
  final PaymentMethod? paymentMethod;

  Sale({
    this.id,
    required this.invoiceNumber,
    this.clientId,
    required this.paymentMethodId,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.total,
    required this.exchangeRate,
    required this.saleDate,
    this.paymentDetails,
    this.createdAt,
    this.updatedAt,
    // Para datos relacionados
    this.client,
    this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'client_id': clientId,
      'payment_method_id': paymentMethodId,
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total': total,
      'exchange_rate': exchangeRate,
      'sale_date': saleDate.toIso8601String(), // Convertir a ISO String para DB
      'payment_details': paymentDetails,
      // createdAt y updatedAt son gestionados por la BD usualmente, no los incluimos aquí
      // al insertar/actualizar, a menos que la lógica lo requiera explícitamente.
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      clientId: map['client_id'] as int?,
      paymentMethodId: map['payment_method_id'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0, // Manejar posible null
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0, // Manejar posible null
      total: (map['total'] as num).toDouble(),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      saleDate: DateTime.parse(map['sale_date'] as String), // Convertir desde ISO String
      paymentDetails: map['payment_details'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
      // Los objetos client y paymentMethod no se cargan desde este fromMap,
      // se cargarían por separado si es necesario.
    );
  }

  @override
  String toString() {
    return 'Sale(id: $id, invoiceNumber: $invoiceNumber, clientId: $clientId, paymentMethodId: $paymentMethodId, subtotal: $subtotal, taxRate: $taxRate, taxAmount: $taxAmount, total: $total, exchangeRate: $exchangeRate, saleDate: $saleDate, paymentDetails: $paymentDetails)';
  }

  // Método copyWith si necesitas modificar objetos Sale
  Sale copyWith({
    int? id,
    String? invoiceNumber,
    int? clientId, // Ojo: permitir null aquí puede ser complejo si antes no lo era
    int? paymentMethodId,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? total,
    double? exchangeRate,
    DateTime? saleDate,
    String? paymentDetails,
    Client? client,
    PaymentMethod? paymentMethod,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      clientId: clientId ?? this.clientId, 
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      saleDate: saleDate ?? this.saleDate,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      createdAt: createdAt, // No suelen copiarse
      updatedAt: updatedAt, // No suelen copiarse
      client: client ?? this.client,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
} 