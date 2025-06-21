class Expense {
  final int? id;
  final String description;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? notes;
  final String? receiptNumber;
  final String? supplier;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.notes,
    this.receiptNumber,
    this.supplier,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  // Crear desde Map (para base de datos)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      expenseDate: DateTime.parse(map['expense_date'] as String),
      notes: map['notes'] as String?,
      receiptNumber: map['receipt_number'] as String?,
      supplier: map['supplier'] as String?,
      paymentMethod: map['payment_method'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Convertir a Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'expense_date': expenseDate.toIso8601String(),
      'notes': notes,
      'receipt_number': receiptNumber,
      'supplier': supplier,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Crear copia con cambios
  Expense copyWith({
    int? id,
    String? description,
    double? amount,
    String? category,
    DateTime? expenseDate,
    String? notes,
    String? receiptNumber,
    String? supplier,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      supplier: supplier ?? this.supplier,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Expense(id: $id, description: $description, amount: $amount, category: $category, date: $expenseDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Modelo para categorías de gastos
class ExpenseCategory {
  final int? id;
  final String name;
  final String? description;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseCategory({
    this.id,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseCategory(id: $id, name: $name, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 