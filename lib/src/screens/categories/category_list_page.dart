import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/database_helper.dart';
import 'category_form_page.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = _dbHelper.getCategories();
    });
  }

  void _navigateAndRefresh(BuildContext context, {Category? category}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormPage(category: category),
      ),
    );
    // Refrescar si se guardó algo (podría devolver la categoría o solo true)
    if (result != null && mounted) { 
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(int id) async {
     // Verificar si hay productos asociados a esta categoría
     final productsInCategory = await _dbHelper.getProductsByCategory(id);
     final hasProducts = productsInCategory.isNotEmpty;
     
     if (hasProducts) {
       // Mostrar mensaje de error si la categoría tiene productos
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('No se puede eliminar: La categoría tiene ${productsInCategory.length} productos asociados'),
           backgroundColor: Colors.red,
           action: SnackBarAction(
             label: 'Ver Productos',
             onPressed: () {
               // Aquí se podría navegar a la lista de productos filtrada
               // Navigator.push(context, MaterialPageRoute(...))
             },
             textColor: Colors.white,
           ),
         ),
       );
       return;
     }
     
     // Si no hay productos, confirmar el borrado
     bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Borrado'),
            content: const Text('¿Seguro que deseas eliminar esta categoría?'),
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
          // Eliminar la categoría
          await _dbHelper.deleteCategory(id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Categoría eliminada'), backgroundColor: Colors.green),
            );
            _loadCategories();
          }
        } catch (e) {
          if (mounted) {
            // Mostrar un mensaje más claro si el error es por restricción de clave externa
            String errorMessage = 'Error al eliminar categoría';
            
            if (e.toString().contains('FOREIGN KEY constraint failed')) {
              errorMessage = 'No se puede eliminar: categoría asociada a ventas u otros registros';
            } else {
              errorMessage = 'Error al eliminar categoría: $e';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
            );
          }
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Categorías'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar categorías: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay categorías registradas.'));
          }

          final categories = snapshot.data!;

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(child: Text(category.name.substring(0, 1).toUpperCase())),
                title: Text(category.name),
                 trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Eliminar Categoría',
                  onPressed: () => _deleteCategory(category.id!), 
                ),
                onTap: () => _navigateAndRefresh(context, category: category),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(context),
        tooltip: 'Añadir Categoría',
        child: const Icon(Icons.add),
      ),
    );
  }
} 