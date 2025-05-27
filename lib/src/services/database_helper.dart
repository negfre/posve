import 'dart:async';
import 'dart:io';
// Importar para generar aleatorios

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart'; // Importar User
import '../models/product.dart'; // Importar Product
import '../models/supplier.dart'; // Asegúrate de importar Supplier si es necesario
import '../models/inventory_movement.dart'; // Importar InventoryMovement
import '../models/category.dart'; // Importar Category
import '../models/client.dart'; // <-- Importar Client
import '../models/payment_method.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Si creas un modelo para AppSetting

// Modelo auxiliar para combinar datos de movimiento y producto
class MovementWithProductInfo {
  final InventoryMovement movement;
  final String productName;

  MovementWithProductInfo({required this.movement, required this.productName});
}

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  // Versión de la base de datos
  static const _databaseVersion = 13; // Incrementado para la nueva migración

  // Claves para app_settings
  static const String exchangeRateKey = 'exchange_rate_usd_ves';
  static const String defaultTaxRateKey = 'default_tax_rate'; // Clave para tasa de impuesto
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'inventory_app.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTablesV6(db);
    // Crear tabla de historial de tipos de cambio
    await db.execute('''
      CREATE TABLE exchange_rate_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rate REAL NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Insertar configuraciones iniciales
    await db.insert('app_settings', {'key': exchangeRateKey, 'value': '1.0'},
                    conflictAlgorithm: ConflictAlgorithm.ignore); 
    await db.insert('app_settings', {'key': defaultTaxRateKey, 'value': '0.16'},
                    conflictAlgorithm: ConflictAlgorithm.ignore); 
    
    // --- YA NO SE EJECUTA SEEDING AUTOMÁTICO AQUÍ ---
    // print("***** Ejecutando Seeding de Datos de Prueba *****");
    // await _seedDataV1(db); 
    // print("***** Seeding Completado *****");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Actualizando BD de versión $oldVersion a $newVersion");
    if (oldVersion < 2) {
      // --- Migración de v1 a v2 ---
      print("Aplicando migración v1 a v2...");
      await db.execute("ALTER TABLE products RENAME COLUMN purchase_price TO purchase_price_usd;");
      await db.execute("ALTER TABLE products RENAME COLUMN selling_price TO selling_price_usd;");
      await db.execute("ALTER TABLE products ADD COLUMN selling_price_ves REAL NOT NULL DEFAULT 0.0;");
      
      await db.execute("ALTER TABLE inventory_movements RENAME COLUMN unit_price TO unit_price_usd;");
      await db.execute("ALTER TABLE inventory_movements ADD COLUMN unit_price_ves REAL NOT NULL DEFAULT 0.0;");
      await db.execute("ALTER TABLE inventory_movements ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 1.0;");
      // Insertar configuracion inicial si no existe
      await db.execute("CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)");
      await db.insert('app_settings', {'key': exchangeRateKey, 'value': '1.0'}, 
                    conflictAlgorithm: ConflictAlgorithm.ignore);
      print("Migración v1 a v2 completada.");
    }
    if (oldVersion < 3) {
      // Aplicar cambios de v2 a v3
      print("Aplicando migración v2 a v3...");
      // Añadir columna observations a suppliers
      await db.execute("ALTER TABLE suppliers ADD COLUMN observations TEXT;");
      // Nota: SQLite no tiene un comando fácil para ELIMINAR columnas.
      // La forma robusta sería crear tabla nueva, copiar datos, borrar vieja, renombrar nueva.
      // Para simplificar en desarrollo, dejaremos las columnas email/address (no se usarán)
      // Alternativamente, si estás en desarrollo temprano, desinstalar/reinstalar es más fácil.
      print("Migración v2 a v3 completada (observations añadida).");
    }
    if (oldVersion < 4) {
      // Aplicar cambios de v3 a v4
      print("Aplicando migración v3 a v4...");
      // 1. Crear tabla categories
      await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      print("Tabla categories creada.");
      // 2. Añadir columna category_id a products
      await db.execute("ALTER TABLE products ADD COLUMN category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL;");
      print("Columna category_id añadida a products.");
      print("Migración v3 a v4 completada.");
    }
    if (oldVersion < 5) {
      print("Aplicando migración v4 a v5...");
      await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tax_id TEXT UNIQUE NOT NULL, 
        phone TEXT,
        address TEXT,
        email TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      print("Tabla clients creada.");
      // Aquí podríamos añadir columnas a otras tablas si fuera necesario para v5
      print("Migración v4 a v5 completada.");
    }
    if (oldVersion < 6) {
      // Aplicar cambios de v5 a v6
      print("Aplicando migración v5 a v6...");
      // 1. Crear tabla payment_methods
      await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1, -- 1 for true, 0 for false
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      // Añadir columna si la tabla ya existía pero no tenía la columna (para robustez)
      try {
        await db.execute("ALTER TABLE payment_methods ADD COLUMN description TEXT;");
        print("Columna description añadida a payment_methods (si no existía).");
      } catch (e) {
        // Ignorar error si la columna ya existe
        if (!e.toString().contains('duplicate column name')) {
            print("Error añadiendo columna description (puede que ya exista): $e");
        }
      }
      print("Tabla payment_methods creada/actualizada.");

      // 2. Crear tabla sales
      await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        client_id INTEGER, 
        payment_method_id INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0.0, 
        tax_amount REAL NOT NULL DEFAULT 0.0, 
        total REAL NOT NULL,
        exchange_rate REAL NOT NULL, 
        sale_date TEXT NOT NULL,
        payment_details TEXT, 
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT 
      )
      ''');
      print("Tabla sales creada.");

      // 3. Crear tabla sale_items
      await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_usd REAL NOT NULL, -- Precio al momento de la venta (USD)
        unit_price_ves REAL NOT NULL, -- Precio al momento de la venta (VES)
        subtotal_usd REAL NOT NULL,   -- quantity * unit_price_usd
        subtotal_ves REAL NOT NULL,   -- quantity * unit_price_ves
        created_at TEXT NOT NULL, -- Mantener timestamp por si acaso
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE, -- Si se borra la venta, se borran los items
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT -- No permitir borrar producto si está en ventas
      )
      ''');
       print("Tabla sale_items creada.");

       // 4. Insertar Tasa de Impuesto por Defecto si no existe
        await db.insert('app_settings', {'key': defaultTaxRateKey, 'value': '0.16'}, 
                       conflictAlgorithm: ConflictAlgorithm.ignore);
        print("Clave default_tax_rate insertada en app_settings (si no existía).");

        // 5. (Opcional pero recomendado) Modificar tabla inventory_movements para que no contenga ventas directas
        // Podríamos renombrar 'sale' a 'adjustment_out' o algo similar si queremos seguir usando 
        // esta tabla para ajustes manuales de inventario (salidas).
        // Por ahora, la dejamos como está, pero las NUEVAS ventas se registrarán en 'sales' y 'sale_items'.
        // Si quisiéramos eliminar 'sale' de los tipos permitidos:
        // Esto requeriría crear una nueva tabla, copiar datos, etc. (complejo en SQLite)
        // Dejémoslo pendiente por ahora.

       print("Migración v5 a v6 completada.");
    }
    if (oldVersion < 8) {
      print("Aplicando migración v7 a v8...");
      // Crear tabla de historial de tipos de cambio
      await db.execute('''
        CREATE TABLE exchange_rate_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rate REAL NOT NULL,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      
      // Obtener la tasa actual y guardarla como primer registro histórico
      final settings = await db.query('app_settings', 
        where: 'key = ?', 
        whereArgs: [exchangeRateKey]
      );
      
      if (settings.isNotEmpty) {
        final currentRate = double.parse(settings.first['value'] as String);
        final now = DateTime.now().toIso8601String();
        
        await db.insert('exchange_rate_history', {
          'rate': currentRate,
          'date': now,
          'created_at': now,
        });
      }
      
      print("Migración v7 a v8 completada.");
    }
    if (oldVersion < 9) {
      await _migrateToV9(db);
    }
    if (oldVersion < 10) {
      await _migrateToV10(db);
    }
    if (oldVersion < 11) {
      print("Aplicando migración v10 a v11...");
      // Añadir columna exchange_rate a la tabla sales
      await db.execute("ALTER TABLE sales ADD COLUMN exchange_rate REAL NOT NULL DEFAULT 1.0;");
      print("Migración v10 a v11 completada.");
    }
    if (oldVersion < 12) {
      await _migrateToV12(db);
    }
    if (oldVersion < 13) {
      await _migrateToV12(db);
    }
  }

  // Nueva migración para añadir soporte de exención de IVA por producto
  Future<void> _migrateToV12(Database db) async {
    print('Iniciando migración a V12...');
    try {
      // Añadir columna is_vat_exempt a la tabla products
      await db.execute('ALTER TABLE products ADD COLUMN is_vat_exempt INTEGER NOT NULL DEFAULT 0;');
      
      print('Migración a V12 completada con éxito');
    } catch (e) {
      print('Error durante la migración a V12: $e');
      rethrow;
    }
  }

  Future<void> _migrateToV9(Database db) async {
    print('Iniciando migración a V9...');
    
    // Añadir columnas email y address a la tabla suppliers
    await db.execute('ALTER TABLE suppliers ADD COLUMN email TEXT;');
    await db.execute('ALTER TABLE suppliers ADD COLUMN address TEXT;');
    
    print('Migración a V9 completada.');
  }

  Future<void> _migrateToV10(Database db) async {
    print('Iniciando migración a V10...');
    try {
      // Añadir columna cost_price_usd a la tabla products
      await db.execute('ALTER TABLE products ADD COLUMN cost_price_usd REAL NOT NULL DEFAULT 0.0;');
      
      // Actualizar los registros existentes para que cost_price_usd sea igual a purchase_price_usd
      await db.execute('UPDATE products SET cost_price_usd = purchase_price_usd;');
      
      // Añadir columnas de stock si no existen (eliminamos current_stock que ya existe)
      // await db.execute('ALTER TABLE products ADD COLUMN current_stock INTEGER NOT NULL DEFAULT 0;');
      await db.execute('ALTER TABLE products ADD COLUMN stock INTEGER NOT NULL DEFAULT 0;');
      await db.execute('ALTER TABLE products ADD COLUMN min_stock INTEGER NOT NULL DEFAULT 5;');
      
      // Actualizar los registros existentes para que stock sea igual a current_stock
      await db.execute('UPDATE products SET stock = current_stock;');
      
      print('Migración a V10 completada exitosamente.');
    } catch (e) {
      print('Error durante la migración a V10: $e');
      rethrow;
    }
  }

  Future _createTablesV6(Database db) async { 
    // Incluir TODAS las tablas, incluyendo las nuevas y las antiguas
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      salt TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      tax_id TEXT UNIQUE NOT NULL,
      phone TEXT,
      email TEXT,
      address TEXT,
      observations TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
     await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      sku TEXT DEFAULT NULL,
      barcode TEXT DEFAULT NULL,
      current_stock INTEGER NOT NULL DEFAULT 0,
      cost_price_usd REAL NOT NULL,
      purchase_price_usd REAL NOT NULL,
      profit_margin REAL NOT NULL,
      selling_price_usd REAL NOT NULL,
      selling_price_ves REAL NOT NULL,
      supplier_id INTEGER,
      category_id INTEGER,
      stock INTEGER NOT NULL DEFAULT 0,
      min_stock INTEGER NOT NULL DEFAULT 5,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    )
    ''');

     await db.execute('''
    CREATE TABLE inventory_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('purchase', 'sale', 'adjustment_in', 'adjustment_out')), -- Considerar ajustar los tipos si 'sale' ya no se usa aquí
      quantity INTEGER NOT NULL,
      movement_date TEXT NOT NULL,
      unit_price_usd REAL NOT NULL, -- Para compras, precio de costo; para ajustes, puede ser 0 o un valor estimado
      unit_price_ves REAL NOT NULL, 
      exchange_rate REAL NOT NULL,
      supplier_id INTEGER, -- Relevante para 'purchase'
      notes TEXT, -- Añadir campo de notas para ajustes
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
    )
    ''');
    // Modificar CHECK constraint si es necesario
    // await db.execute('ALTER TABLE inventory_movements RENAME TO inventory_movements_old;');
    // await db.execute('CREATE TABLE inventory_movements ... (con nuevo CHECK)');
    // await db.execute('INSERT INTO inventory_movements SELECT ... FROM inventory_movements_old;');
    // await db.execute('DROP TABLE inventory_movements_old;');

    await db.execute('''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE clients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      tax_id TEXT UNIQUE NOT NULL, 
      phone TEXT,
      address TEXT,
      email TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // --- Nuevas Tablas V6 ---
     await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1, 
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

     await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        client_id INTEGER, 
        payment_method_id INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0.0, 
        tax_amount REAL NOT NULL DEFAULT 0.0, 
        total REAL NOT NULL,
        exchange_rate REAL NOT NULL, 
        sale_date TEXT NOT NULL,
        payment_details TEXT, 
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT 
      )
      ''');

     await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_usd REAL NOT NULL, 
        unit_price_ves REAL NOT NULL, 
        subtotal_usd REAL NOT NULL,   
        subtotal_ves REAL NOT NULL,   
        created_at TEXT NOT NULL, 
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE, 
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT 
      )
      ''');
  }

  // --- Métodos CRUD --- 

  // Verifica si un email ya existe en la tabla users
  Future<bool> checkEmailExists(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1, // Solo necesitamos saber si existe o no
    );
    return result.isNotEmpty;
  }

  // Inserta un nuevo usuario
  Future<int> insertUser(User user) async {
    final db = await database;
    // Usa el método toMap() del modelo User
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.fail); 
  }

  // Obtiene un usuario por su email
  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      // Usa el factory constructor fromMap() del modelo User
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // --- Gestión de Usuarios Adicional ---

  // Obtiene todos los usuarios
  Future<List<User>> getAllUsers() async {
    final db = await database;
    // Ordenar por email o id para consistencia
    final List<Map<String, dynamic>> maps = await db.query('users', orderBy: 'email ASC');

    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Obtiene un usuario por su ID
  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Elimina un usuario por su ID
  Future<int> deleteUser(int id) async {
    final db = await database;
    // Considerar qué pasa si el usuario que se elimina es el logueado actualmente
    // O si tiene datos asociados en otras tablas (aunque no hay FK directas a users por ahora)
    print("Intentando eliminar usuario con ID: $id");
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualiza la contraseña de un usuario por su ID
  Future<int> updateUserPassword(int id, String newPasswordHash, String newSalt) async {
    final db = await database;
    print("Actualizando contraseña para usuario ID: $id");
    return await db.update(
      'users',
      {
        'password_hash': newPasswordHash,
        'salt': newSalt,
        // Podríamos actualizar un campo 'updated_at' si existiera
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Fin Gestión de Usuarios Adicional ---

  // Obtiene un valor de configuración
  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // Inserta o reemplaza un valor de configuración
  Future<int> insertSetting(String key, String value) async {
    final db = await database;
    return await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      // Si la clave ya existe, reemplaza el valor
      conflictAlgorithm: ConflictAlgorithm.replace, 
    );
  }

  // Obtiene la tasa de cambio actual
  Future<double> getExchangeRate() async {
    final rateString = await getSetting(exchangeRateKey);
    // Devuelve 1.0 si no existe o no es número válido
    return double.tryParse(rateString ?? '1.0') ?? 1.0; 
  }

  // Obtiene la tasa de impuesto por defecto
  Future<double> getDefaultTaxRate() async {
    final rateString = await getSetting(defaultTaxRateKey);
     // Devuelve 0.16 (16%) si no existe o no es número válido
    return double.tryParse(rateString ?? '0.16') ?? 0.16;
  }

  // Actualiza la tasa de cambio
  Future<void> updateExchangeRate(double newRate) async {
    final db = await database;
    await db.transaction((txn) async {
      // Actualizar la tasa actual
      await txn.update(
        'app_settings',
        {'value': newRate.toString()},
        where: 'key = ?',
        whereArgs: [exchangeRateKey],
      );
      
      // Guardar en el historial
      final now = DateTime.now().toIso8601String();
      await txn.insert('exchange_rate_history', {
        'rate': newRate,
        'date': now,
        'created_at': now,
      });
    });
  }

  // Actualiza la tasa de impuesto por defecto
  Future<int> updateDefaultTaxRate(double newRate) async {
    if (newRate < 0 || newRate > 1) {
      throw ArgumentError('La tasa de impuesto debe estar entre 0.0 y 1.0');
    }
    return await insertSetting(defaultTaxRateKey, newRate.toString());
  }

  // Inicia el período de prueba si aún no ha comenzado
  Future<void> startTrialIfNeeded() async {
    const trialKey = 'trial_start_date';
    final existingValue = await getSetting(trialKey);
    if (existingValue == null) {
      // Si no existe la clave, la insertamos con la fecha actual
      await insertSetting(trialKey, DateTime.now().toIso8601String());
    }
  }

  // --- CRUD Productos ---

  // Obtiene todos los productos ordenados por nombre
  Future<List<Product>> getProducts() async {
    try {
      print("DatabaseHelper: Iniciando getProducts()");
    final db = await database;
      print("DatabaseHelper: Conexión a BD obtenida");
      
    // Ordenar por nombre para una visualización consistente
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'name ASC');
      print("DatabaseHelper: Query ejecutado, encontrados ${maps.length} productos");
      
      if (maps.isEmpty) {
        print("DatabaseHelper: ADVERTENCIA - No se encontraron productos en la BD");
      } else {
        print("DatabaseHelper: Primer producto encontrado: ${maps[0]['name']}");
      }

      final products = List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
      
      print("DatabaseHelper: getProducts() completado con éxito, retornando ${products.length} productos");
      return products;
    } catch (e) {
      print("DatabaseHelper: ERROR en getProducts(): $e");
      print("DatabaseHelper: Traza: ${StackTrace.current}");
      // Relanzamos la excepción para que el llamador la maneje
      rethrow;
    }
  }

  // Inserta un nuevo producto
  Future<int> insertProduct(Product product) async {
    try {
      final db = await database;
      
      // Verificar si existe un producto con el mismo SKU o código de barras (si no son nulos)
      Product? existingProduct;
      if (product.sku != null && product.sku!.isNotEmpty) {
        existingProduct = await getProductBySku(product.sku!);
        if (existingProduct != null) {
          throw Exception('Ya existe un producto con el mismo SKU');
        }
      }
      
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        existingProduct = await getProductByBarcode(product.barcode!);
        if (existingProduct != null) {
          throw Exception('Ya existe un producto con el mismo código de barras');
        }
      }

      final id = await db.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      if (id <= 0) {
        throw Exception('Error al insertar el producto: ID inválido');
      }

      return id;
    } catch (e) {
      print('Error al insertar producto: $e');
      throw Exception('Error al insertar producto: $e');
    }
  }

  // Actualiza un producto existente
  Future<int> updateProduct(Product product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final productMap = product.toMap();
    productMap['updated_at'] = now;
    productMap.remove('created_at'); 
    // Asegurarse que los precios no sean null si la BD no lo permite
    productMap['purchase_price_usd'] ??= 0.0;
    productMap['selling_price_usd'] ??= 0.0;
    productMap['selling_price_ves'] ??= 0.0;
    // category_id puede ser null
    return await db.update(
      'products',
      productMap,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // Borra un producto (opcional)
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualiza el selling_price_ves de todos los productos basado en la nueva tasa
  Future<void> updateAllProductSellingPrices(double newExchangeRate) async {
     final db = await database;
     final List<Product> products = await getProducts(); // Obtener todos los productos
     final Batch batch = db.batch(); // Usar batch para eficiencia

     print("Actualizando precios de venta para ${products.length} productos con tasa: $newExchangeRate");

     for (final product in products) {
        // Recalcular precio en USD (puede que no haya cambiado, pero es más seguro)
       final sellingPriceUsd = Product.calculateSellingPrice(product.purchasePriceUsd, product.profitMargin);
       // Calcular el nuevo precio en VES
       final newSellingPriceVes = sellingPriceUsd * newExchangeRate;

       // Añadir la operación de actualización al batch
        batch.update(
          'products',
          {
            'selling_price_usd': sellingPriceUsd, // Actualizar por si acaso
            'selling_price_ves': newSellingPriceVes,
            'updated_at': DateTime.now().toIso8601String() // Marcar como actualizado
          },
          where: 'id = ?',
          whereArgs: [product.id],
       );
     }
     // Ejecutar todas las operaciones del batch
     await batch.commit(noResult: true);
     print("Actualización masiva de precios completada.");
  }

  // --- CRUD Suppliers ---

  // Obtiene todos los proveedores ordenados por nombre
  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('suppliers', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  // Obtiene un proveedor por su ID
  Future<Supplier?> getSupplierById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Supplier.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Inserta un nuevo proveedor
  Future<int> insertProvider(Map<String, dynamic> provider) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final Map<String, dynamic> providerData = {
      'name': provider['name'],
      'tax_id': provider['tax_id'] ?? 'J-${DateTime.now().millisecondsSinceEpoch}', // Usar tax_id proporcionado o generar uno
      'phone': provider['phone'] ?? '',
      'observations': provider['observations'] ?? '',
      'created_at': now,
      'updated_at': now,
    };
    return await db.insert('suppliers', providerData);
  }

  // Actualiza un proveedor existente
  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final supplierMap = supplier.toMap();
    supplierMap['updated_at'] = now;
    supplierMap.remove('created_at');
    // Asegurar valores no nulos si es necesario
    supplierMap['phone'] ??= '';
    supplierMap['observations'] ??= '';
    return await db.update(
      'suppliers',
      supplierMap,
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  // Borra un proveedor
  Future<int> deleteSupplier(int id) async {
    final db = await database;
    // Considerar qué pasa con los productos asociados (FOREIGN KEY es ON DELETE SET NULL)
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Categories ---

  // Obtiene todas las categorias ordenadas por nombre
  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  // Obtiene una categoria por su ID
  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Inserta una nueva categoria
  Future<int> insertCategory(Category category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final categoryMap = category.toMap();
    categoryMap['created_at'] = now;
    categoryMap['updated_at'] = now;
    // Usar ConflictAlgorithm.fail para evitar nombres duplicados (por el UNIQUE constraint)
    try {
      return await db.insert('categories', categoryMap, conflictAlgorithm: ConflictAlgorithm.fail);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('El nombre de la categoría ya existe.');
      } else {
        rethrow; // Relanzar otros errores de BD
      }
    }
  }

  // Actualiza una categoria existente
  Future<int> updateCategory(Category category) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final categoryMap = category.toMap();
    categoryMap['updated_at'] = now;
    categoryMap.remove('created_at');
    try {
      return await db.update(
        'categories',
        categoryMap,
        where: 'id = ?',
        whereArgs: [category.id],
        conflictAlgorithm: ConflictAlgorithm.fail, // Evitar nombres duplicados
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('El nombre de la categoría ya existe.');
      } else {
        rethrow; 
      }
    }
  }

  // Borra una categoria
  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Los productos asociados tendrán category_id = NULL debido a ON DELETE SET NULL
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtiene todos los productos de una categoría específica
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  // Elimina todos los productos de una categoría
  Future<int> deleteProductsByCategory(int categoryId) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  // Elimina una categoría y todos sus productos asociados
  Future<void> deleteCategoryWithProducts(int categoryId) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Primero eliminar todos los productos de la categoría
      await txn.delete(
        'products',
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      
      // Luego eliminar la categoría
      await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );
    });
  }

  // --- CRUD Inventory Movements --- (Implementar después)
  // ...

  // Obtiene el stock actual de un producto específico
  Future<int> getProductStock(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      columns: ['current_stock'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['current_stock'] as int? ?? 0;
    } else {
      // Considerar lanzar una excepción si el producto no existe
      print("Advertencia: Intentando obtener stock de producto inexistente ID: $productId");
      return 0;
    }
  }

  // Registra una compra (inserta movimiento y actualiza stock)
  Future<void> recordPurchase(InventoryMovement movement) async {
    if (movement.type != 'purchase') {
      throw ArgumentError('Tipo de movimiento inválido para recordPurchase');
    }
    final db = await database;
    final currentStock = await getProductStock(movement.productId);

    await db.transaction((txn) async {
      // 1. Insertar el movimiento
      await txn.insert('inventory_movements', movement.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      // 2. Actualizar el stock del producto
      final newStock = currentStock + movement.quantity;
      await txn.update(
        'products',
        {
           'current_stock': newStock, 
           'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [movement.productId],
      );
    });
    print("Compra registrada y stock actualizado para producto ID: ${movement.productId}");
  }

  // Registra una venta (inserta movimiento y actualiza stock)
  Future<void> recordSale(InventoryMovement movement) async {
     if (movement.type != 'sale') {
      throw ArgumentError('Tipo de movimiento inválido para recordSale');
    }
     // La verificación de stock debe hacerse ANTES de llamar a este método
     final db = await database;
     final currentStock = await getProductStock(movement.productId);

     // Validar de nuevo por si acaso (concurrencia, aunque improbable en offline)
     if (currentStock < movement.quantity) {
       throw Exception('Stock insuficiente (verificación final fallida)');
     }

    await db.transaction((txn) async {
      // 1. Insertar el movimiento
      await txn.insert('inventory_movements', movement.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      // 2. Actualizar el stock del producto (restando)
      final newStock = currentStock - movement.quantity;
       await txn.update(
        'products',
        {
           'current_stock': newStock, 
           'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [movement.productId],
      );
    });
    print("Venta registrada y stock actualizado para producto ID: ${movement.productId}");
  }

  // --- CRUD Inventory Movements (métodos adicionales si son necesarios) ---
  
  // Obtiene todos los movimientos de inventario con el nombre del producto asociado
  Future<List<MovementWithProductInfo>> getAllMovements() async {
    final db = await database;
    // Usar LEFT JOIN para obtener el nombre del producto
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        m.*, 
        p.name as product_name 
      FROM inventory_movements m
      LEFT JOIN products p ON m.product_id = p.id
      ORDER BY m.movement_date DESC
    ''');

    if (maps.isEmpty) {
      return []; // Devuelve lista vacía si no hay movimientos
    }

    // Convertir los mapas a objetos MovementWithProductInfo
    return List.generate(maps.length, (i) {
      // Crear el InventoryMovement desde el mapa
      final movement = InventoryMovement.fromMap(maps[i]);
      // Obtener el nombre del producto (puede ser null si el producto fue eliminado)
      final productName = maps[i]['product_name'] as String? ?? 'Producto Desconocido'; 
      
      return MovementWithProductInfo(
        movement: movement,
        productName: productName,
      );
    });
  }

  // Future<List<InventoryMovement>> getProductMovements(int productId) async { ... }

  // --- CRUD Clients --- 

  // Obtiene todos los clientes ordenados por nombre
  Future<List<Client>> getClients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clients', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  // Obtiene un cliente por su ID
  Future<Client?> getClientById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Client.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Inserta un nuevo cliente
  Future<int> insertClient(Client client) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final clientMap = client.toMap();
    clientMap['created_at'] = now;
    clientMap['updated_at'] = now;
    // Asegurar valores no nulos si es necesario (ej: para campos TEXT NOT NULL sin valor)
    clientMap['phone'] ??= '';
    clientMap['address'] ??= '';
    clientMap['email'] ??= '';
    // Usar ConflictAlgorithm.fail por el UNIQUE constraint en tax_id
    try {
      return await db.insert('clients', clientMap, conflictAlgorithm: ConflictAlgorithm.fail);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        // Podríamos diferenciar por columna si hubiera más de un UNIQUE
        throw Exception('La identificación fiscal (RIF/Cédula) ya existe.');
      } else {
        rethrow;
      }
    }
  }

  // Actualiza un cliente existente
  Future<int> updateClient(Client client) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final clientMap = client.toMap();
    clientMap['updated_at'] = now;
    clientMap.remove('created_at');
    // Asegurar valores no nulos
    clientMap['phone'] ??= '';
    clientMap['address'] ??= '';
    clientMap['email'] ??= '';
    try {
      return await db.update(
        'clients',
        clientMap,
        where: 'id = ?',
        whereArgs: [client.id],
        conflictAlgorithm: ConflictAlgorithm.fail, // Evitar tax_id duplicado
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('La identificación fiscal (RIF/Cédula) ya existe.');
      } else {
        rethrow;
      }
    }
  }

  // Borra un cliente
  Future<int> deleteClient(int id) async {
    final db = await database;
    // Considerar relaciones futuras (ej: foreign key en sales)
    // La FK en sales es ON DELETE SET NULL, así que las ventas asociadas no se borrarán,
    // pero su client_id se volverá NULL.
    return await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD para Payment Methods ---

  // Obtiene todas las formas de pago activas
  Future<List<PaymentMethod>> getActivePaymentMethods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods', 
      where: 'is_active = ?', 
      whereArgs: [1], 
      orderBy: 'name ASC'
    );
    return List.generate(maps.length, (i) => PaymentMethod.fromMap(maps[i]));
  }

  // Obtiene todas las formas de pago (activas e inactivas)
  Future<List<PaymentMethod>> getAllPaymentMethods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('payment_methods', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => PaymentMethod.fromMap(maps[i]));
  }

  // Obtiene una forma de pago por ID
  Future<PaymentMethod?> getPaymentMethodById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payment_methods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PaymentMethod.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Inserta una nueva forma de pago
  Future<int> insertPaymentMethod(PaymentMethod paymentMethod) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final methodMap = paymentMethod.toMap();
    methodMap['created_at'] = now;
    methodMap['updated_at'] = now;
    methodMap['is_active'] = 1; // Por defecto activa al crear
    try {
      return await db.insert('payment_methods', methodMap, conflictAlgorithm: ConflictAlgorithm.fail);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('El nombre de la forma de pago ya existe.');
      } else {
        rethrow;
      }
    }
  }

  // Actualiza una forma de pago
  Future<int> updatePaymentMethod(PaymentMethod paymentMethod) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final methodMap = paymentMethod.toMap();
    methodMap['updated_at'] = now;
    methodMap.remove('created_at'); 
    try {
      return await db.update(
        'payment_methods',
        methodMap,
        where: 'id = ?',
        whereArgs: [paymentMethod.id],
         conflictAlgorithm: ConflictAlgorithm.fail, // Evitar nombres duplicados
      );
    } on DatabaseException catch (e) {
       if (e.toString().contains('FOREIGN KEY constraint failed')) {
         throw Exception('No se puede eliminar la forma de pago porque está asociada a una o más ventas.');
       } else {
         rethrow;
       }
    }
  }

  // Borra una forma de pago (si no está en uso)
  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    // La FK en 'sales' es ON DELETE RESTRICT, así que esto fallará si el método
    // está referenciado en alguna venta. Esto es bueno.
    try {
      return await db.delete(
        'payment_methods',
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
       if (e.toString().contains('FOREIGN KEY constraint failed')) {
         throw Exception('No se puede eliminar la forma de pago porque está asociada a una o más ventas.');
       } else {
         rethrow;
       }
    }
  }


   // --- CRUD para Sales y Sale Items ---

  // Registra una venta completa (venta + items + actualiza stock)
  Future<int> recordCompleteSale({
    required Sale sale,
    required List<SaleItem> items,
    String? paymentDetails,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Obtener la tasa de cambio actual
    final currentExchangeRate = await getExchangeRate();

    // Pre-validación de stock (aunque debería hacerse en la UI también)
    for (final item in items) {
      final currentStock = await getProductStock(item.productId);
      if (currentStock < item.quantity) {
        final product = await db.query('products', where: 'id = ?', whereArgs: [item.productId], limit: 1);
        final productName = product.isNotEmpty ? product.first['name'] : 'ID ${item.productId}';
        throw Exception('Stock insuficiente para $productName (disponible: $currentStock, requerido: ${item.quantity}).');
      }
    }

    int saleId = 0; // Inicializar ID de venta

    await db.transaction((txn) async {
      // 1. Insertar la venta (cabecera)
      final saleMap = sale.toMap();
      saleMap['created_at'] = now;
      saleMap['updated_at'] = now;
      saleMap['sale_date'] = sale.saleDate.toIso8601String();
      saleMap['payment_details'] = paymentDetails;
      saleMap['exchange_rate'] = currentExchangeRate; // Guardar la tasa de cambio actual
      
      // Remover ID si existe (es autoincremental)
      saleMap.remove('id'); 

      // Insertar la venta y obtener su ID
      saleId = await txn.insert('sales', saleMap, conflictAlgorithm: ConflictAlgorithm.fail);
      if (saleId == 0) {
        throw Exception('Error al insertar la cabecera de la venta.');
      }

      // 2. Insertar los items de la venta y actualizar stock
      for (final item in items) {
        // Insertar item
        final itemMap = item.toMap();
        itemMap['sale_id'] = saleId;
        itemMap['created_at'] = now;
        itemMap.remove('id');
        await txn.insert('sale_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);

        // Actualizar stock del producto
        final stockData = await txn.query(
          'products', 
          columns: ['current_stock'], 
          where: 'id = ?', 
          whereArgs: [item.productId], 
          limit: 1
        );
        if (stockData.isEmpty) {
          throw Exception('Producto ID ${item.productId} no encontrado durante la transacción.');
        }
        final currentStockInTx = stockData.first['current_stock'] as int? ?? 0;

        if (currentStockInTx < item.quantity) {
          final product = await txn.query('products', where: 'id = ?', whereArgs: [item.productId], limit: 1);
          final productName = product.isNotEmpty ? product.first['name'] : 'ID ${item.productId}';
          throw Exception('Stock insuficiente detectado durante transacción para $productName.');
        }

        final newStock = currentStockInTx - item.quantity;
        await txn.update(
          'products',
          {'current_stock': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }
    });

    print("Venta completa registrada con ID: $saleId y stock actualizado.");
    return saleId;
  }

  // Obtener todas las ventas con información relacionada
  Future<List<Sale>> getAllSales() async {
    final db = await database;
    
    // Usar joins para obtener la información del cliente y método de pago
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        s.*,
        c.name as client_name,
        c.tax_id as client_tax_id,
        c.email as client_email,
        c.phone as client_phone,
        p.name as payment_method_name,
        p.description as payment_method_description
      FROM sales s
      LEFT JOIN clients c ON s.client_id = c.id
      LEFT JOIN payment_methods p ON s.payment_method_id = p.id
      ORDER BY s.sale_date DESC
    ''');
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      
      // Crear el objeto Client si hay datos del cliente
      Client? client;
      if (map['client_id'] != null && map['client_name'] != null) {
        client = Client(
          id: map['client_id'] as int,
          name: map['client_name'] as String,
          taxId: map['client_tax_id'] as String? ?? 'N/A', // Campo requerido
          email: map['client_email'] as String?,
          phone: map['client_phone'] as String?,
          createdAt: DateTime.now(), // No necesitamos la fecha exacta aquí
          updatedAt: DateTime.now(),
        );
      }
      
      // Crear el objeto PaymentMethod
      PaymentMethod? paymentMethod;
      if (map['payment_method_id'] != null && map['payment_method_name'] != null) {
        paymentMethod = PaymentMethod(
          id: map['payment_method_id'] as int,
          name: map['payment_method_name'] as String,
          description: map['payment_method_description'] as String?,
        );
      }
      
      // Crear el objeto Sale y asociarle client y paymentMethod
      final sale = Sale.fromMap(map);
      return sale.copyWith(
        client: client,
        paymentMethod: paymentMethod,
      );
    });
  }

  // Obtener los items de una venta específica
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    
    // Realizar JOIN con la tabla products para obtener los nombres de productos
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        si.*, 
        p.name as product_name,
        p.description as product_description,
        p.sku as product_sku
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
    ''', [saleId]);
    
    // Crear lista de SaleItem que incluye información del producto
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final now = DateTime.now();
      
      // Crear objeto Product con los datos básicos obtenidos del JOIN
      final product = Product(
        id: map['product_id'] as int,
        name: map['product_name'] as String? ?? 'Producto desconocido',
        description: map['product_description'] as String? ?? '',
        barcode: null,
        sku: map['product_sku'] as String?,
        categoryId: map['category_id'] as int? ?? 0,
        supplierId: map['supplier_id'] as int? ?? 0,
        costPriceUsd: (map['cost_price_usd'] as num?)?.toDouble() ?? 0.0,
        purchasePriceUsd: (map['purchase_price_usd'] as num?)?.toDouble() ?? 0.0,
        profitMargin: (map['profit_margin'] as num?)?.toDouble() ?? 0.0,
        sellingPriceUsd: (map['selling_price_usd'] as num?)?.toDouble() ?? 0.0,
        sellingPriceVes: (map['selling_price_ves'] as num?)?.toDouble() ?? 0.0,
        currentStock: map['current_stock'] as int? ?? 0,
        stock: map['stock'] as int? ?? 0,
        minStock: map['min_stock'] as int? ?? 0,
        isVatExempt: map['product_is_vat_exempt'] == 1, // Convertir 1 a true, 0 a false
        createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      );
      
      // Crear el SaleItem y asociarle el producto
      final saleItem = SaleItem.fromMap(map);
      return saleItem.copyWith(product: product);
    });
  }

  // Obtener detalles completos de una venta (venta + items + cliente + método pago)
  // (Implementación más compleja, usar JOINs o múltiples queries)
  Future<Map<String, dynamic>?> getCompleteSaleDetails(int saleId) async {
     final db = await database;
     final saleMap = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
     if (saleMap.isEmpty) return null;

     final sale = Sale.fromMap(saleMap.first);
     final items = await getSaleItems(saleId);
     final client = sale.clientId != null ? await getClientById(sale.clientId!) : null;
     final paymentMethod = await getPaymentMethodById(sale.paymentMethodId);

     // Recuperar nombres de productos para los items (ejemplo con queries separadas)
     final itemsWithProductNames = <Map<String, dynamic>>[];
     for (final item in items) {
        final productInfo = await db.query('products', columns: ['name'], where: 'id = ?', whereArgs: [item.productId], limit: 1);
        final productName = productInfo.isNotEmpty ? productInfo.first['name'] as String : 'Desconocido';
        final itemDetail = item.toMap();
        itemDetail['product_name'] = productName;
        itemsWithProductNames.add(itemDetail);
     }


     return {
       'sale': sale,
       'items': itemsWithProductNames, // Usar items con nombres
       'client': client,
       'paymentMethod': paymentMethod,
     };
  }

  // --- Fin CRUD Sales y Sale Items ---


  // --- Método Público para Seeding Manual --- 
  Future<void> seedTestData() async {
    final db = await database; 
    print("***** INICIANDO SEEDING MANUAL DE DATOS *****");
    
    try {
      // 0. BORRAR DATOS EXISTENTES EN ORDEN CORRECTO
      print("Iniciando borrado de datos existentes en orden correcto...");
      
      await db.delete('sale_items');
      await db.delete('sales');
      await db.delete('inventory_movements');
      await db.delete('products');
      await db.delete('categories');
      await db.delete('suppliers');

      final now = DateTime.now();

      // --- CREAR 3 PROVEEDORES ---
      final supplier1Id = await db.insert('suppliers', {
        'name': 'Distribuidora Alimentos Caracas',
        'tax_id': 'J123456789',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });

      final supplier2Id = await db.insert('suppliers', {
        'name': 'TecnoGlobal C.A.',
        'tax_id': 'J987654321',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });

      final supplier3Id = await db.insert('suppliers', {
        'name': 'Suministros y Oficina S.A.',
        'tax_id': 'J555123456',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });
      
      print("Proveedores creados: $supplier1Id, $supplier2Id, $supplier3Id");

      // --- CREAR 3 CATEGORÍAS ---
      final category1Id = await db.insert('categories', {
        'name': 'Alimentos',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });

      final category2Id = await db.insert('categories', {
        'name': 'Electrónicos',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });

      final category3Id = await db.insert('categories', {
        'name': 'Oficina',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String()
      });
      
      print("Categorías creadas: $category1Id, $category2Id, $category3Id");

      // --- PRODUCTOS POR CATEGORÍA ---
      final productos = [
        // Alimentos
        {
          'name': 'Harina PAN 1kg',
          'sku': 'ALI-001',
          'cost': 2.5,
          'margin': 0.25,
          'categoryId': category1Id,
          'supplierId': supplier1Id,
        },
        {
          'name': 'Arroz Mary Superior 1kg',
          'sku': 'ALI-002',
          'cost': 3.2,
          'margin': 0.3,
          'categoryId': category1Id,
          'supplierId': supplier1Id,
        },
        {
          'name': 'Pasta Ronco Corta 500g',
          'sku': 'ALI-003',
          'cost': 1.8,
          'margin': 0.28,
          'categoryId': category1Id,
          'supplierId': supplier1Id,
        },
        // Electrónicos
        {
          'name': 'Mouse Óptico Genius',
          'sku': 'ELEC-001',
          'cost': 8.5,
          'margin': 0.4,
          'categoryId': category2Id,
          'supplierId': supplier2Id,
        },
        {
          'name': 'Teclado Logitech K120',
          'sku': 'ELEC-002',
          'cost': 15.0,
          'margin': 0.35,
          'categoryId': category2Id,
          'supplierId': supplier2Id,
        },
        {
          'name': 'Audífonos Bluetooth JBL',
          'sku': 'ELEC-003',
          'cost': 25.0,
          'margin': 0.45,
          'categoryId': category2Id,
          'supplierId': supplier2Id,
        },
        // Oficina
        {
          'name': 'Resma Papel Bond Carta',
          'sku': 'OFI-001',
          'cost': 5.0,
          'margin': 0.3,
          'categoryId': category3Id,
          'supplierId': supplier3Id,
        },
        {
          'name': 'Bolígrafo Kilométrico Negro',
          'sku': 'OFI-002',
          'cost': 0.8,
          'margin': 0.5,
          'categoryId': category3Id,
          'supplierId': supplier3Id,
        },
        {
          'name': 'Grapadora Mediana',
          'sku': 'OFI-003',
          'cost': 3.5,
          'margin': 0.4,
          'categoryId': category3Id,
          'supplierId': supplier3Id,
        },
      ];

      // Insertar productos
      for (var prod in productos) {
        final cost = prod['cost'] as double;
        final margin = prod['margin'] as double;
        final sellingUsd = cost * (1 + margin);
        final sellingVes = sellingUsd * 34.0;

        await db.insert('products', {
          'name': prod['name'],
          'description': 'Descripción de ${prod['name']}',
          'sku': prod['sku'],
          'category_id': prod['categoryId'],
          'supplier_id': prod['supplierId'],
          'cost_price_usd': cost,
          'purchase_price_usd': cost,
          'profit_margin': margin,
          'selling_price_usd': sellingUsd,
          'selling_price_ves': sellingVes,
          'current_stock': 10,
          'stock': 10,
          'min_stock': 5,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      print("9 productos insertados (3 por categoría)");
      print("***** SEEDING MANUAL COMPLETADO CON ÉXITO *****");
    } catch (e) {
      print("ERROR DURANTE SEEDING: $e");
      print("Traza: ${StackTrace.current}");
      rethrow;
    }
  }

  // --- Métodos para borrar datos --- 

  Future<int> deleteAllProducts() async {
    final db = await database;
    print("Borrando TODOS los productos...");
    // Esto también borrará movimientos asociados por ON DELETE CASCADE
    return await db.delete('products'); 
  }

  Future<int> deleteAllMovements() async {
    final db = await database;
    print("Borrando TODOS los movimientos...");
    return await db.delete('inventory_movements'); 
  }

  Future<int> deleteAllCategories() async {
    final db = await database;
    print("Borrando TODAS las categorías...");
    // Productos asociados tendrán category_id = NULL por ON DELETE SET NULL
    return await db.delete('categories'); 
  }

  Future<int> deleteAllSuppliers() async {
    final db = await database;
    print("Borrando TODOS los proveedores...");
    // Productos asociados tendrán supplier_id = NULL por ON DELETE SET NULL
    return await db.delete('suppliers'); 
  }

  Future<int> deleteAllClients() async {
    final db = await database;
    print("Borrando TODOS los clientes...");
    // Ventas asociadas tendrán client_id = NULL por ON DELETE SET NULL
    return await db.delete('clients'); 
  }

  Future<int> deleteAllPaymentMethods() async {
    final db = await database;
    print("Borrando TODAS las formas de pago...");
    // Fallará si alguna está en uso por ON DELETE RESTRICT en sales
     try {
       return await db.delete('payment_methods');
     } on DatabaseException catch (e) {
       if (e.toString().contains('FOREIGN KEY constraint failed')) {
         print("Error: No se pueden borrar todas las formas de pago, algunas están en uso en ventas.");
         return 0; // O lanzar excepción
       } else { rethrow; }
     }
  }

  Future<int> deleteAllSales() async {
     final db = await database;
     print("Borrando TODAS las ventas y sus items...");
     // Borrar los items ocurrirá automáticamente por ON DELETE CASCADE
     return await db.delete('sales');
  }

  // Eliminar una venta específica por su ID
  Future<int> deleteSale(int id) async {
    final db = await database;
    print("Borrando venta ID: $id junto con sus items...");
    // Los items se borrarán automáticamente por ON DELETE CASCADE
    return await db.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Borrar TODOS los datos de negocio (¡CUIDADO!)
  Future<void> deleteAllBusinessData() async {
     print("--- INICIANDO BORRADO COMPLETO DE DATOS DE NEGOCIO ---");
     await deleteAllSales();
     await deleteAllMovements(); // Borra movimientos (incluyendo compras/ajustes)
     await deleteAllProducts(); // Borra productos (y causa cascada en movimientos)
     await deleteAllCategories();
     await deleteAllSuppliers();
     await deleteAllClients();
     await deleteAllPaymentMethods(); // Intentar borrar formas de pago
     print("--- BORRADO COMPLETO DE DATOS DE NEGOCIO FINALIZADO ---");
     // No borramos usuarios ni settings
  }

  // Verifica si hay al menos un producto en la tabla products
  Future<bool> hasAnyProducts() async {
    try {
      print("DatabaseHelper: Verificando si hay algún producto");
      final db = await database;
      
      // Consulta solo el conteo para eficiencia
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
      final int count = Sqflite.firstIntValue(result) ?? 0;
      
      print("DatabaseHelper: Conteo de productos: $count");
      return count > 0;
    } catch (e) {
      print("DatabaseHelper: ERROR al verificar productos: $e");
      return false; // Asumir que no hay productos en caso de error
    }
  }

  // Borra un movimiento específico por su ID
  Future<int> deleteMovement(int id) async {
    final db = await database;
    return await db.delete(
      'inventory_movements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Fin Métodos para borrar datos ---

  // Método para guardar un nuevo tipo de cambio en el historial
  Future<void> saveExchangeRateHistory(double rate) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('exchange_rate_history', {
      'rate': rate,
      'date': now,
      'created_at': now,
    });
  }

  // Método para obtener el historial de tipos de cambio
  Future<List<Map<String, dynamic>>> getExchangeRateHistory() async {
    final db = await database;
    return await db.query(
      'exchange_rate_history',
      orderBy: 'date DESC', // Ordenar por fecha descendente (más reciente primero)
    );
  }

  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print("Verificando estado de onboarding...");
      final completed = prefs.getBool(_keyOnboardingCompleted) ?? false;
      print("Estado de onboarding: $completed");
      return completed;
    } catch (e) {
      print("Error al verificar estado de onboarding: $e");
      return false;
    }
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print("Guardando estado de onboarding: $completed");
      await prefs.setBool(_keyOnboardingCompleted, completed);
      print("Estado de onboarding guardado correctamente");
    } catch (e) {
      print("Error al guardar estado de onboarding: $e");
      rethrow;
    }
  }

  Future<int> addPaymentMethod(String name) async {
    try {
      print("Intentando agregar forma de pago: $name");
      final db = await database;
      
      // Verificar si ya existe
      final existing = await db.query(
        'payment_methods',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      
      if (existing.isNotEmpty) {
        print("La forma de pago ya existe, actualizando estado activo");
        // Si existe, solo actualizamos su estado a activo
        return await db.update(
          'payment_methods',
          {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'name = ?',
          whereArgs: [name],
        );
      }

      // Si no existe, la creamos
      final now = DateTime.now().toIso8601String();
      return await db.insert('payment_methods', {
        'name': name,
        'description': '',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      print("Error al agregar forma de pago: $e");
      rethrow;
    }
  }

  Future<void> updateTaxRate(double rate) async {
    await insertSetting(defaultTaxRateKey, rate.toString());
  }

  Future<int> getCategoryId(String categoryName) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'categories',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [categoryName],
    );
    return result.isNotEmpty ? result.first['id'] as int : -1;
  }

  Future<int> insertCategoryByName(String name) async {
    final db = await database;
    return await db.insert(
      'categories',
      {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // --- Métodos para configuración de IVA y tasa de cambio ---
  
  Future<void> setVatEnabled(bool enabled) async {
    await insertSetting('vat_enabled', enabled.toString());
  }

  Future<void> setVatPercentage(double percentage) async {
    await insertSetting('vat_percentage', percentage.toString());
  }

  Future<void> setExchangeRate(double rate) async {
    await updateExchangeRate(rate);
  }

  Future<bool> getVatEnabled() async {
    final value = await getSetting('vat_enabled');
    return value == 'true';
  }

  Future<double> getVatPercentage() async {
    final value = await getSetting('vat_percentage');
    return double.tryParse(value ?? '0.0') ?? 0.0;
  }

  Future<int> getProviderId(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'suppliers',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty ? result.first['id'] as int : -1;
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Método para eliminar la base de datos
  Future<void> deleteDatabaseFile() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'inventory_app.db');
    
    try {
      if (await databaseExists(path)) {
        await _closeDatabase();
        await databaseFactory.deleteDatabase(path);
        _database = null;
        print('Base de datos eliminada exitosamente');
      }
    } catch (e) {
      print('Error al eliminar la base de datos: $e');
      rethrow;
    }
  }

  // Método para cerrar la conexión a la base de datos
  Future<void> _closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        print('Conexión a la base de datos cerrada exitosamente');
      }
    } catch (e) {
      print('Error al cerrar la base de datos: $e');
      rethrow;
    }
  }



  Future<Product?> getProductBySku(String sku) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  // Alias para getActivePaymentMethods para compatibilidad con onboarding
  Future<List<PaymentMethod>> getPaymentMethods() async {
    return await getActivePaymentMethods();
  }

  // Obtener todas las categorías
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  // Obtener todos los proveedores
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Supplier.fromMap(maps[i]);
    });
  }

  // Obtener ventas por rango de fechas (para reportes)
  Future<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    
    // Convertir las fechas a formato ISO para la consulta SQL
    final startDateIso = startDate.toIso8601String();
    final endDateIso = endDate.toIso8601String();
    
    // Hacer consulta con JOIN para obtener información relacionada
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        s.*,
        c.name as client_name,
        c.tax_id as client_tax_id,
        c.email as client_email,
        c.phone as client_phone,
        p.name as payment_method_name,
        p.description as payment_method_description
      FROM sales s
      LEFT JOIN clients c ON s.client_id = c.id
      LEFT JOIN payment_methods p ON s.payment_method_id = p.id
      WHERE s.sale_date BETWEEN ? AND ?
      ORDER BY s.sale_date DESC
    ''', [startDateIso, endDateIso]);
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      
      // Crear el objeto Client si hay datos del cliente
      Client? client;
      if (map['client_id'] != null && map['client_name'] != null) {
        client = Client(
          id: map['client_id'] as int,
          name: map['client_name'] as String,
          taxId: map['client_tax_id'] as String? ?? 'N/A',
          email: map['client_email'] as String?,
          phone: map['client_phone'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      // Crear el objeto PaymentMethod
      PaymentMethod? paymentMethod;
      if (map['payment_method_id'] != null && map['payment_method_name'] != null) {
        paymentMethod = PaymentMethod(
          id: map['payment_method_id'] as int,
          name: map['payment_method_name'] as String,
          description: map['payment_method_description'] as String?,
        );
      }
      
      // Crear el objeto Sale y asociarle client y paymentMethod
      final sale = Sale.fromMap(map);
      return sale.copyWith(
        client: client,
        paymentMethod: paymentMethod,
      );
    });
  }

  // Obtener ventas del día actual
  Future<List<Sale>> getSalesToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  // Obtener ventas de la semana actual
  Future<List<Sale>> getSalesThisWeek() async {
    final now = DateTime.now();
    // Encuentra el primer día de la semana (lunes)
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day);
    final endOfWeek = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return getSalesByDateRange(startOfWeek, endOfWeek);
  }

  // Obtener ventas del mes actual
  Future<List<Sale>> getSalesThisMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return getSalesByDateRange(startOfMonth, endOfMonth);
  }

  // Obtener resumen de ventas por período (para gráficos y estadísticas)
  Future<Map<String, dynamic>> getSalesSummary(DateTime startDate, DateTime endDate) async {
    final sales = await getSalesByDateRange(startDate, endDate);
    
    if (sales.isEmpty) {
      return {
        'total_sales': 0,
        'total_amount': 0.0,
        'avg_amount': 0.0,
        'total_tax': 0.0,
        'sales_count': 0,
        'payment_methods': <String, int>{},
        'payment_methods_amounts': <String, double>{},
      };
    }
    
    double totalAmount = 0.0;
    double totalTax = 0.0;
    final paymentMethods = <String, int>{};
    final paymentMethodsAmounts = <String, double>{};
    
    for (final sale in sales) {
      totalAmount += sale.total;
      totalTax += sale.taxAmount;
      
      final paymentMethodName = sale.paymentMethod?.name ?? 'Desconocido';
      
      // Contar transacciones por método de pago
      paymentMethods[paymentMethodName] = (paymentMethods[paymentMethodName] ?? 0) + 1;
      
      // Sumar montos por método de pago
      paymentMethodsAmounts[paymentMethodName] = (paymentMethodsAmounts[paymentMethodName] ?? 0.0) + sale.total;
    }
    
    return {
      'total_sales': sales.length,
      'total_amount': totalAmount,
      'avg_amount': sales.isEmpty ? 0.0 : totalAmount / sales.length,
      'total_tax': totalTax,
      'sales_count': sales.length,
      'payment_methods': paymentMethods,
      'payment_methods_amounts': paymentMethodsAmounts,
    };
  }
} // Final de la clase DatabaseHelper
