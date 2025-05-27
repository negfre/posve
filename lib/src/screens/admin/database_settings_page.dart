import 'package:flutter/material.dart';
import '../../services/database_helper.dart';

class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isSeeding = false;
  bool _isDeleting = false; // Estado general para borrado

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

  @override
  Widget build(BuildContext context) {
    // Deshabilitar botones si alguna operación está en curso
    final bool operationInProgress = _isSeeding || _isDeleting;

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