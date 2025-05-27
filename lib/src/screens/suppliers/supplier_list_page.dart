import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/database_helper.dart';
import 'supplier_form_page.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Supplier>> _suppliersFuture;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  void _loadSuppliers() {
    setState(() {
      _suppliersFuture = _dbHelper.getSuppliers();
    });
  }

  void _navigateAndRefresh(BuildContext context, {Supplier? supplier}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormPage(supplier: supplier),
      ),
    );
    if (result == true && mounted) {
      _loadSuppliers();
    }
  }

  Future<void> _deleteSupplier(int id) async {
     bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Borrado'),
            content: const Text('¿Seguro que deseas eliminar este proveedor? Los productos asociados no serán eliminados, pero perderán la referencia.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

     if (confirmDelete) {
        try {
          await _dbHelper.deleteSupplier(id);
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proveedor eliminado'), backgroundColor: Colors.green),
              );
            _loadSuppliers();
          }
        } catch (e) {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Error al eliminar proveedor: $e'), backgroundColor: Colors.red),
               );
            }
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Proveedores'),
      ),
      body: FutureBuilder<List<Supplier>>(
        future: _suppliersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar proveedores: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay proveedores registrados.'));
          }

          final suppliers = snapshot.data!;

          return ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                leading: CircleAvatar(child: Text(supplier.name.substring(0, 1).toUpperCase())),
                title: Text(supplier.name),
                subtitle: Text('RIF: ${supplier.taxId}${supplier.phone != null && supplier.phone!.isNotEmpty ? ' | Telf: ${supplier.phone}' : ''}'),
                 trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Eliminar Proveedor',
                  onPressed: () => _deleteSupplier(supplier.id!), 
                ),
                onTap: () => _navigateAndRefresh(context, supplier: supplier),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(context),
        tooltip: 'Añadir Proveedor',
        child: const Icon(Icons.add),
      ),
    );
  }
} 