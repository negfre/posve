import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/database_helper.dart';

class CategoryFormPage extends StatefulWidget {
  final Category? category; // Categoría existente para editar, o null para añadir

  const CategoryFormPage({super.key, this.category});

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();
  late TextEditingController _nameController;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.category != null;
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final name = _nameController.text.trim();
      Category? savedCategory;

      try {
        if (_isEditMode) {
          final updatedCategory = Category(
            id: widget.category!.id,
            name: name,
            createdAt: widget.category!.createdAt,
            updatedAt: DateTime.now(),
          );
          await _dbHelper.updateCategory(updatedCategory);
          savedCategory = updatedCategory;
        } else {
          final newCategory = Category(
            name: name,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final newId = await _dbHelper.insertCategory(newCategory);
          savedCategory = Category(
            id: newId,
            name: name,
            createdAt: newCategory.createdAt,
            updatedAt: newCategory.updatedAt
          );
        }

        if (mounted) {
          Navigator.pop(context, savedCategory);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar categoría: ${e.toString()}'), backgroundColor: Colors.red),
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
        title: Text(_isEditMode ? 'Editar Categoría' : 'Añadir Categoría'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre de la Categoría'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveCategory,
                        child: Text(_isEditMode ? 'Actualizar Categoría' : 'Guardar Categoría'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 