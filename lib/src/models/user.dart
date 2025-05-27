class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  // Puedes añadir métodos toJson/fromJson aquí si los necesitas para la BD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      passwordHash: map['password_hash'],
      salt: map['salt'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
} 