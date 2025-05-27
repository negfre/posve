class Supplier {
  final int? id;
  final String name;
  final String taxId; // RIF/ID Fiscal
  final String? phone;
  final String? email;
  final String? address;
  final String? observations;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    this.id,
    required this.name,
    required this.taxId,
    this.phone,
    this.email,
    this.address,
    this.observations,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tax_id': taxId,
      'phone': phone,
      'email': email,
      'address': address,
      'observations': observations,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      taxId: map['tax_id'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      observations: map['observations'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? taxId,
    String? phone,
    String? email,
    String? address,
    String? observations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      observations: observations ?? this.observations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 