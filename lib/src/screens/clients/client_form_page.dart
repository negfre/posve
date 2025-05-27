import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/database_helper.dart';

class ClientFormPage extends StatefulWidget {
  final Client? client; // Cliente existente para editar, o null para añadir

  const ClientFormPage({super.key, this.client});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Controladores para los campos del formulario
  late TextEditingController _nameController;
  late TextEditingController _taxIdController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.client != null;

    // Inicializar controladores con datos existentes si es edición
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _taxIdController = TextEditingController(text: widget.client?.taxId ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _addressController = TextEditingController(text: widget.client?.address ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
  }

  @override
  void dispose() {
    // Liberar controladores
    _nameController.dispose();
    _taxIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final clientData = Client(
        id: widget.client?.id, // Mantener ID si es edición
        name: _nameController.text.trim(),
        taxId: _taxIdController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        // Usar fechas existentes si es edición, o la actual si es nuevo
        createdAt: widget.client?.createdAt ?? now,
        updatedAt: now, // Siempre actualizar updatedAt
      );

      try {
        if (_isEditMode) {
          await _dbHelper.updateClient(clientData);
        } else {
          await _dbHelper.insertClient(clientData);
        }
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cliente ${_isEditMode ? 'actualizado' : 'guardado'} exitosamente.'),
                backgroundColor: Colors.green,
              ),
            );
            // Devolver true para indicar éxito y refrescar la lista anterior
            Navigator.of(context).pop(true); 
          }
      } catch (e) {
        // Mostrar error (ej. tax_id duplicado)
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al guardar cliente: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Cliente' : 'Añadir Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre o Razón Social',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingrese el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _taxIdController,
                decoration: const InputDecoration(
                  labelText: 'Identificación Fiscal (RIF/Cédula)',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingrese la identificación fiscal';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico (Opcional)',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección (Opcional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveClient,
        icon: const Icon(Icons.save),
        label: Text(_isEditMode ? 'Guardar Cambios' : 'Guardar Cliente'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
} 