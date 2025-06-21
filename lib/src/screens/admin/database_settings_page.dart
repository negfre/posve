import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    setState(() => _isExporting = true);
    
    try {
      // Obtener todos los datos de la base de datos
      final exportData = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'products': await _dbHelper.getAllProductsForExport(),
        'categories': await _dbHelper.getAllCategoriesForExport(),
        'suppliers': await _dbHelper.getAllSuppliersForExport(),
        'clients': await _dbHelper.getAllClientsForExport(),
        'sales': await _dbHelper.getAllSalesForExport(),
        'sale_items': await _dbHelper.getAllSaleItemsForExport(),
        'purchases': await _dbHelper.getAllPurchasesForExport(),
        'movements': await _dbHelper.getAllMovementsForExport(),
        'expenses': await _dbHelper.getAllExpensesForExport(),
        'expense_categories': await _dbHelper.getAllExpenseCategoriesForExport(),
        'paymentMethods': await _dbHelper.getAllPaymentMethodsForExport(),
        'users': await _dbHelper.getAllUsersForExport(),
        'settings': await _dbHelper.getAllSettingsForExport(),
      };

      // Convertir a JSON
      final jsonData = json.encode(exportData);
      
      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final fileName = 'posve_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      
      // Escribir archivo temporal
      await file.writeAsString(jsonData);
      
      // Mostrar diálogo con opciones
      if (mounted) {
        _showExportOptionsDialog(file, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // Mostrar diálogo con opciones de exportación
  void _showExportOptionsDialog(File file, String fileName) {
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('El backup se ha creado exitosamente.'),
              const SizedBox(height: 16),
              Text('Archivo: $fileName'),
              const SizedBox(height: 16),
              const Text('¿Qué deseas hacer con el archivo?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _promptAndSaveToDevice(file, fileName);
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar en Dispositivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _shareFile(file);
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Guardar archivo en el dispositivo
  Future<void> _promptAndSaveToDevice(File sourceFile, String fileName) async {
    try {
      // Pedir al usuario que elija una ubicación para guardar
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Por favor, selecciona dónde guardar el backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputPath == null) {
        // User canceled the picker
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado cancelado por el usuario.')),
          );
        }
        return;
      }

      // Copiar el archivo temporal a la ubicación elegida
      final destinationFile = File(outputPath);
      await sourceFile.copy(destinationFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup guardado exitosamente!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Compartir',
              onPressed: () => _shareFile(destinationFile),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Compartir archivo
  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup de POSVE - ${DateTime.now().toString().substring(0, 19)}',
        subject: 'Backup POSVE',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Función para importar base de datos
  Future<void> _importDatabase() async {
    try {
      // Seleccionar archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null) return;

      setState(() => _isImporting = true);

      // Leer archivo
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final importData = json.decode(jsonString) as Map<String, dynamic>;

      // Verificar que sea un archivo válido de POSVE
      if (!importData.containsKey('version') || !importData.containsKey('products')) {
        throw Exception('Archivo no válido de POSVE');
      }

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
      await _dbHelper.importData(importData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos importados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
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
                backgroundColor: operationInProgress ? null : Colors.red[700],
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
          ],
        ),
      ),
    );
  }
} 