
class Client {
  final int? id;
  final String name;
  final String taxId; // Identificación fiscal (RIF/Cédula)
  final String? phone;
  final String? address;
  final String? email; // Añadido email
  final DateTime createdAt;
  final DateTime updatedAt;

  Client({
    this.id,
    required this.name,
    required this.taxId,
    this.phone,
    this.address,
    this.email, // Añadido email
    required this.createdAt,
    required this.updatedAt,
  });

  // Método para convertir un Map (de la BD) a un objeto Client
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      name: map['name'] as String,
      taxId: map['tax_id'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Método para convertir un objeto Client a un Map (para la BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tax_id': taxId,
      'phone': phone,
      'address': address,
      'email': email, // Añadido email
      // No incluimos createdAt/updatedAt aquí, se manejan en la BD
    };
  }
  
 // CopyWith para facilitar actualizaciones inmutables
   Client copyWith({
    int? id,
    String? name,
    String? taxId,
    String? phone,
    String? address,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

} 