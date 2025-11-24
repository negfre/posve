import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/database_helper.dart';
import '../../services/license_service.dart';

class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LicenseService _licenseService = LicenseService();
  bool _isSeeding = false;
  bool _isDeleting = false; // Estado general para borrado
  bool _isExporting = false;
  bool _isImporting = false;

  // Función genérica para mostrar diálogo de confirmación de borrado
  Future<bool> _showDeleteConfirmationDialog(String itemType) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Borrado - $itemType'),
          content: Text(
            '¿Estás seguro de que quieres borrar TODOS los $itemType?\nEsta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sí, Borrar Todo'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Función para ejecutar el seeding
  Future<void> _triggerSeeding() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Generar Datos'),
          content: const Text(
            'Esto borrará TODOS los productos y movimientos actuales y los reemplazará con datos de prueba.\n¿Estás seguro?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Sí, Generar Datos'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return; 

    setState(() => _isSeeding = true);
    try {
      await _dbHelper.seedTestData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos de prueba generados exitosamente.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar datos de prueba: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { setState(() => _isSeeding = false); }
    }
  }

  // Función genérica para ejecutar borrado
  Future<void> _triggerDelete(String itemType, Future<int> Function() deleteFunction) async {
    final confirm = await _showDeleteConfirmationDialog(itemType);
    if (!confirm) return;

    setState(() => _isDeleting = true);
    String message = '';
    Color bgColor = Colors.grey;

    try {
      int count = await deleteFunction();
      message = '$count $itemType eliminados exitosamente.';
      bgColor = Colors.green;
    } catch (e) {
      message = 'Error al borrar $itemType: ${e.toString()}';
      bgColor = Colors.red;
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: bgColor),
        );
      }
    }
  }

  // Función para exportar toda la base de datos
  Future<void> _exportDatabase() async {
    print("📤 Iniciando proceso de exportación...");
    setState(() => _isExporting = true);
    
    try {
      print("📊 Obteniendo datos de la base de datos...");
      
      // Obtener todos los datos de la base de datos
      print("  - Obteniendo productos...");
      final products = await _dbHelper.getAllProductsForExport();
      print("    ✅ Productos: ${products.length} registros");
      
      print("  - Obteniendo categorías...");
      final categories = await _dbHelper.getAllCategoriesForExport();
      print("    ✅ Categorías: ${categories.length} registros");
      
      print("  - Obteniendo proveedores...");
      final suppliers = await _dbHelper.getAllSuppliersForExport();
      print("    ✅ Proveedores: ${suppliers.length} registros");
      
      print("  - Obteniendo clientes...");
      final clients = await _dbHelper.getAllClientsForExport();
      print("    ✅ Clientes: ${clients.length} registros");
      
      print("  - Obteniendo ventas...");
      final sales = await _dbHelper.getAllSalesForExport();
      print("    ✅ Ventas: ${sales.length} registros");
      
      print("  - Obteniendo items de venta...");
      final saleItems = await _dbHelper.getAllSaleItemsForExport();
      print("    ✅ Items de venta: ${saleItems.length} registros");
      
      print("  - Obteniendo compras...");
      final purchases = await _dbHelper.getAllPurchasesForExport();
      print("    ✅ Compras: ${purchases.length} registros");
      
      print("  - Obteniendo movimientos...");
      final movements = await _dbHelper.getAllMovementsForExport();
      print("    ✅ Movimientos: ${movements.length} registros");
      
      print("  - Obteniendo gastos...");
      final expenses = await _dbHelper.getAllExpensesForExport();
      print("    ✅ Gastos: ${expenses.length} registros");
      
      print("  - Obteniendo categorías de gastos...");
      final expenseCategories = await _dbHelper.getAllExpenseCategoriesForExport();
      print("    ✅ Categorías de gastos: ${expenseCategories.length} registros");
      
      print("  - Obteniendo métodos de pago...");
      final paymentMethods = await _dbHelper.getAllPaymentMethodsForExport();
      print("    ✅ Métodos de pago: ${paymentMethods.length} registros");
      
      print("  - Obteniendo usuarios...");
      final users = await _dbHelper.getAllUsersForExport();
      print("    ✅ Usuarios: ${users.length} registros");
      
      print("  - Obteniendo configuraciones...");
      final settings = await _dbHelper.getAllSettingsForExport();
      print("    ✅ Configuraciones: ${settings.length} registros");
      
      print("📦 Construyendo objeto de exportación...");
      final exportData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'products': products,
        'categories': categories,
        'suppliers': suppliers,
        'clients': clients,
        'sales': sales,
        'sale_items': saleItems,
        'purchases': purchases,
        'movements': movements,
        'expenses': expenses,
        'expense_categories': expenseCategories,
        'paymentMethods': paymentMethods,
        'users': users,
        'settings': settings,
      };
      
      print("📋 Claves en exportData: ${exportData.keys.toList()}");
      print("📊 Total de registros: ${products.length + categories.length + suppliers.length + clients.length + sales.length + saleItems.length + purchases.length + movements.length + expenses.length + expenseCategories.length + paymentMethods.length + users.length + settings.length}");

      // Convertir a JSON
      print("🔄 Convirtiendo a JSON...");
      final jsonData = json.encode(exportData);
      print("✅ JSON generado: ${jsonData.length} caracteres");
      
      if (jsonData.isEmpty) {
        throw Exception('El JSON generado está vacío. Verifica los datos de exportación.');
      }
      
      // Mostrar vista previa
      final preview = jsonData.length > 200 ? jsonData.substring(0, 200) : jsonData;
      print("📄 Vista previa del JSON (primeros 200 caracteres): $preview...");
      
      // Obtener directorio temporal
      print("📁 Obteniendo directorio temporal...");
      final directory = await getTemporaryDirectory();
      print("✅ Directorio: ${directory.path}");
      
      final fileName = 'posve_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      print("📝 Archivo a crear: ${file.path}");
      
      // Escribir archivo temporal
      print("💾 Escribiendo archivo...");
      await file.writeAsString(jsonData);
      
      // Verificar que se escribió correctamente
      final fileSize = await file.length();
      print("✅ Archivo escrito: $fileSize bytes");
      
      if (fileSize == 0) {
        throw Exception('El archivo se escribió pero está vacío. Error al escribir datos.');
      }
      
      print("✅ Exportación completada exitosamente");
      
      // Mostrar diálogo con opciones
      if (mounted) {
        _showExportOptionsDialog(file, fileName);
      }
    } catch (e, stackTrace) {
      print("❌ ERROR DURANTE EXPORTACIÓN:");
      print("   Tipo de error: ${e.runtimeType}");
      print("   Mensaje: ${e.toString()}");
      print("   Stack trace: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
      print("🏁 Proceso de exportación finalizado");
    }
  }

  // Mostrar diálogo con opciones de exportación
  void _showExportOptionsDialog(File file, String fileName) async {
    // Verificar estado de licencia
    final isValid = await _licenseService.isLicenseValid();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download, color: Colors.blue),
              SizedBox(width: 8),
              Text('Backup Exportado'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El backup se ha creado exitosamente.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isValid ? Icons.verified : Icons.info_outline,
                            color: isValid ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isValid ? 'Licencia Activa' : 'Modo de Prueba',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isValid ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isValid) ...[
                        const Text(
                          '📋 Información sobre Licencias:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• El backup incluye todos tus datos (productos, ventas, compras, etc.)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Las licencias NO se exportan por seguridad',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Al importar en otro dispositivo, necesitarás activar una nueva licencia',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Para desbloquear todas las funciones (exportar reportes, productos ilimitados), activa una licencia en Configuración > Activar Licencia',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          '✅ Tienes una licencia activa. Todas las funciones están desbloqueadas.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Archivo: $fileName',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes compartirlo o guardarlo usando el botón de abajo.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _shareFile(file);
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir/Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            if (!isValid)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/activate-license');
                },
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('Activar Licencia'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
          ],
        );
      },
    );
  }

  // Compartir archivo (también permite guardar)
  Future<void> _shareFile(File file) async {
    try {
      print("📤 Iniciando compartir/guardar archivo...");
      print("📁 Archivo: ${file.path}");
      
      // Verificar que el archivo existe
      if (!await file.exists()) {
        throw Exception('El archivo no existe: ${file.path}');
      }
      
      final fileSize = await file.length();
      print("📏 Tamaño del archivo: $fileSize bytes");
      
      if (fileSize == 0) {
        throw Exception('El archivo está vacío');
      }
      
      print("📤 Compartiendo archivo...");
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup de POSVE - ${DateTime.now().toString().substring(0, 19)}\n\nPuedes guardar este archivo en tu dispositivo o compartirlo.',
        subject: 'Backup POSVE',
      );
      
      print("✅ Archivo compartido exitosamente");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Archivo compartido. Puedes guardarlo desde el menú de compartir.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print("❌ ERROR al compartir archivo:");
      print("   Error: $e");
      print("   Tipo: ${e.runtimeType}");
      print("   Stack: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Función para importar base de datos
  Future<void> _importDatabase() async {
    try {
      print("📥 Iniciando proceso de importación...");
      
      // Seleccionar archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null) {
        print("❌ Usuario canceló la selección de archivo");
        return;
      }

      print("✅ Archivo seleccionado: ${result.files.single.path}");
      setState(() => _isImporting = true);

      // Leer archivo
      final file = File(result.files.single.path!);
      print("📖 Leyendo archivo desde: ${file.path}");
      
      // Verificar que el archivo existe
      if (!await file.exists()) {
        print("❌ ERROR: El archivo no existe");
        throw Exception('El archivo seleccionado no existe o no se puede acceder');
      }
      
      // Verificar tamaño del archivo
      final fileSize = await file.length();
      print("📄 Tamaño del archivo: $fileSize bytes");
      
      if (fileSize == 0) {
        print("❌ ERROR: El archivo está vacío (0 bytes)");
        throw Exception('El archivo seleccionado está vacío. Por favor, selecciona un archivo válido de backup de POSVE.');
      }
      
      print("📖 Leyendo contenido del archivo...");
      final jsonString = await file.readAsString();
      print("📄 Contenido leído: ${jsonString.length} caracteres");
      
      if (jsonString.isEmpty || jsonString.trim().isEmpty) {
        print("❌ ERROR: El contenido del archivo está vacío después de leer");
        throw Exception('El archivo está vacío o no se pudo leer correctamente.');
      }
      
      // Mostrar primeros caracteres para debugging
      final preview = jsonString.length > 100 ? jsonString.substring(0, 100) : jsonString;
      print("📄 Vista previa del contenido (primeros 100 caracteres): $preview...");
      
      print("🔍 Decodificando JSON...");
      Map<String, dynamic> importData;
      try {
        importData = json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        print("❌ ERROR al decodificar JSON: $e");
        print("📄 Contenido completo del archivo: $jsonString");
        rethrow;
      }
      
      print("✅ JSON decodificado exitosamente");
      print("📋 Claves encontradas en JSON: ${importData.keys.toList()}");

      // Verificar que sea un archivo válido de POSVE
      print("🔎 Validando estructura del archivo...");
      print("📋 Claves encontradas: ${importData.keys.toList()}");
      
      // Claves esperadas en un archivo POSVE
      final expectedKeys = ['version', 'products', 'categories', 'suppliers', 'clients', 
                           'sales', 'sale_items', 'movements', 'expenses', 'paymentMethods'];
      final foundKeys = importData.keys.toList();
      
      // Verificar claves mínimas requeridas
      if (!importData.containsKey('version')) {
        print("❌ ERROR: El archivo no contiene la clave 'version'");
        throw Exception('Archivo no válido de POSVE: falta la clave "version"');
      }
      if (!importData.containsKey('products')) {
        print("❌ ERROR: El archivo no contiene la clave 'products'");
        throw Exception('Archivo no válido de POSVE: falta la clave "products"');
      }
      
      // Detectar si es un archivo de otra aplicación
      final suspiciousKeys = ['follows', 'posts', 'comments', 'likes', 'followers', 'following'];
      final hasSuspiciousKeys = foundKeys.any((key) => suspiciousKeys.contains(key));
      
      if (hasSuspiciousKeys) {
        print("❌ ERROR: El archivo parece ser de otra aplicación");
        print("   Claves sospechosas encontradas: ${foundKeys.where((k) => suspiciousKeys.contains(k)).toList()}");
        throw Exception('Este archivo no es de POSVE. Parece ser de otra aplicación.\n\n'
                       'POSVE espera: products, categories, suppliers, sales, etc.\n'
                       'Este archivo tiene: ${foundKeys.where((k) => suspiciousKeys.contains(k)).join(", ")}');
      }
      
      // Verificar que tenga al menos algunas claves esperadas de POSVE
      final hasPosveKeys = foundKeys.any((key) => expectedKeys.contains(key));
      if (!hasPosveKeys) {
        print("❌ ERROR: El archivo no tiene claves reconocidas de POSVE");
        throw Exception('Este archivo no parece ser de POSVE.\n\n'
                       'Claves esperadas: ${expectedKeys.join(", ")}\n'
                       'Claves encontradas: ${foundKeys.join(", ")}');
      }
      
      print("✅ Estructura del archivo válida para POSVE");

      // Mostrar diálogo de confirmación
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Importación'),
            content: const Text(
              'Esto reemplazará todos los datos actuales con los del archivo seleccionado.\n\n'
              '⚠️ ADVERTENCIA: Esta acción no se puede deshacer.\n\n'
              '¿Estás seguro de continuar?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Sí, Importar'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (!confirm) {
        setState(() => _isImporting = false);
        return;
      }

      // Importar datos (excluyendo licencias)
      print("💾 Iniciando importación de datos...");
      await _dbHelper.importData(importData);
      print("✅ Importación completada exitosamente");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos importados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print("❌ ERROR DURANTE IMPORTACIÓN:");
      print("   Tipo de error: ${e.runtimeType}");
      print("   Mensaje: ${e.toString()}");
      print("   Stack trace: $stackTrace");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
      print("🏁 Proceso de importación finalizado");
    }
  }

  // Función para simular el paso de 10 días sin licencia
  Future<void> _simulateTenDaysPassed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Simulación de Licencia'),
          content: const Text(
            'Esta acción simulará que han pasado más de 10 días sin una licencia válida. En el próximo reinicio de la aplicación, los productos deberían ser eliminados automáticamente.\n\n¿Estás seguro de continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text('Sí, Simular'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final elevenDaysAgo = DateTime.now().subtract(const Duration(days: 11)).toIso8601String();
    
    // Establecer la fecha de última limpieza a hace 11 días
    await prefs.setString('last_cleanup_date', elevenDaysAgo);
    
    // Asegurarse de que no hay una licencia activa
    await prefs.remove('app_license');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulación activada. Reinicia la app para ver el efecto.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Deshabilitar botones si alguna operación está en curso
    final bool operationInProgress = _isSeeding || _isDeleting || _isExporting || _isImporting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes de Base de Datos'),
      ),
      body: SingleChildScrollView( // Para evitar overflow si hay muchos botones
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Botón Seeding ---
            ElevatedButton.icon(
              icon: _isSeeding 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.data_exploration_outlined), 
              label: Text(_isSeeding ? 'Generando...' : 'Generar Datos de Prueba'),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: operationInProgress ? null : _triggerSeeding,
            ),
            const SizedBox(height: 10),
            const Text(
              '(Borra productos/movimientos actuales)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 40),
            
            // --- Botones de Exportar e Importar ---
            Text('Backup y Restauración:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_download_outlined),
              label: Text(_isExporting ? 'Exportando...' : 'Exportar Base de Datos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: operationInProgress ? null : _exportDatabase,
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: _isImporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_upload_outlined),
              label: Text(_isImporting ? 'Importando...' : 'Importar Base de Datos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: operationInProgress ? null : _importDatabase,
            ),
            const SizedBox(height: 10),
            const Text(
              '(Exporta/importa todos los datos excepto licencias)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 40),
            
            // --- Botones de Borrado Individual ---
            Text('Borrado Individual:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text('Borrar TODOS los Productos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: operationInProgress ? null : () => _triggerDelete('Productos', _dbHelper.deleteAllProducts),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text('Borrar TODOS los Movimientos'),
               style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: operationInProgress ? null : () => _triggerDelete('Movimientos', _dbHelper.deleteAllMovements),
            ),
             const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text('Borrar TODAS las Categorías'),
               style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: operationInProgress ? null : () => _triggerDelete('Categorías', _dbHelper.deleteAllCategories),
            ),
             const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text('Borrar TODOS los Proveedores'),
               style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: operationInProgress ? null : () => _triggerDelete('Proveedores', _dbHelper.deleteAllSuppliers),
            ),
             const SizedBox(height: 20),
            Text(
              'Advertencia: Las acciones de borrado no se pueden deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold),
            ),

            const Divider(height: 40),

            // --- Sección de Pruebas de Licencia ---
            Text('Pruebas de Licencia', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.deepOrange)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.science_outlined, color: Colors.white),
              label: const Text('Simular Limpieza por Licencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationInProgress ? Colors.grey : Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: operationInProgress ? null : _simulateTenDaysPassed,
            ),
            const SizedBox(height: 10),
            const Text(
              'Forzará la eliminación de productos en el próximo reinicio si la app no tiene una licencia activa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 