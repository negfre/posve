import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/database_helper.dart';

class SupplierFormPage extends StatefulWidget {
  final Supplier? supplier; // Proveedor existente para editar, o null para añadir

  const SupplierFormPage({super.key, this.supplier});

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();

  late TextEditingController _nameController;
  late TextEditingController _taxIdController;
  late TextEditingController _phoneController;
  late TextEditingController _observationsController;

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.supplier != null;

    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _taxIdController = TextEditingController(text: widget.supplier?.taxId ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _observationsController = TextEditingController(text: widget.supplier?.observations ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final name = _nameController.text;
      final taxId = _taxIdController.text;
      final phone = _phoneController.text.isNotEmpty ? _phoneController.text : null;
      final observations = _observationsController.text.isNotEmpty ? _observationsController.text : null;

      try {
        if (_isEditMode) {
          final updatedSupplier = Supplier(
            id: widget.supplier!.id,
            name: name,
            taxId: taxId,
            phone: phone,
            observations: observations,
            createdAt: widget.supplier!.createdAt, // Mantener fecha original
            updatedAt: DateTime.now(), // Se actualizará en el helper
          );
          await _dbHelper.updateSupplier(updatedSupplier);
        } else {
          final newSupplier = Supplier(
            name: name,
            taxId: taxId,
            phone: phone,
            observations: observations,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _dbHelper.insertProvider({
            'name': newSupplier.name,
            'tax_id': newSupplier.taxId,
            'phone': newSupplier.phone,
            'observations': newSupplier.observations,
          });
        }

        if (mounted) {
          Navigator.pop(context, true); // Regresar (true indica cambios)
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar proveedor: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Proveedor' : 'Añadir Proveedor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre del Proveedor'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(labelText: 'RIF / ID Fiscal'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El RIF/ID Fiscal es requerido';
                        }
                        // Aquí podrías añadir validación de formato de RIF si es necesario
                        // y validación de unicidad (más complejo, requiere consulta a BD)
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Teléfono (Opcional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: _observationsController,
                      decoration: const InputDecoration(labelText: 'Observaciones (Opcional)'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveSupplier,
                        child: Text(_isEditMode ? 'Actualizar Proveedor' : 'Guardar Proveedor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 