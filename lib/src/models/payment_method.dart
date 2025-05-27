class PaymentMethod {
  final int? id; // Nullable for insertion
  final String name;
  final String? description; // Nullable description

  PaymentMethod({
    this.id,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // May be null on insert
      'name': name,
      'description': description,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as int?, // Handle potential null if reading before insert
      name: map['name'] as String,
      description: map['description'] as String?, // Handle nullable
    );
  }

  @override
  String toString() => 'PaymentMethod(id: $id, name: $name, description: $description)';

  PaymentMethod copyWith({
    int? id,
    String? name,
    String? description,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
} 