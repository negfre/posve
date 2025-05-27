import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear
import '../../models/product.dart';
import '../../services/database_helper.dart';
import 'product_form_page.dart'; // Para navegar al formulario
import '../sales/sales_order_page.dart'; // Para navegación a ventas
import '../purchases/purchase_order_page.dart'; // Para navegación a compras

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Product>> _productsFuture;
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
  final _futureBuilderKey = UniqueKey();
  
  // Variables para búsqueda y filtros
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showLowStock = false; // Filtro para stock < 5
  bool _showOutOfStock = false; // Filtro para stock = 0
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    // Añadir listener para la búsqueda
    _searchController.addListener(() {
      _applyFilters();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = _dbHelper.getProducts();
      _productsFuture.then((products) {
        _filteredProducts = List.from(products);
        _applyFilters();
      });
    });
  }

  // Método para aplicar filtros y búsqueda
  void _applyFilters() {
    if (!mounted) return;
    
    _productsFuture.then((allProducts) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        
        // Aplicar todos los filtros en secuencia
        _filteredProducts = allProducts.where((product) {
          // Búsqueda por texto
          bool matchesSearch = _searchQuery.isEmpty || 
              product.name.toLowerCase().contains(_searchQuery) ||
              (product.description.toLowerCase().contains(_searchQuery)) ||
              (product.sku?.toLowerCase().contains(_searchQuery) ?? false);
          
          // Filtro de bajo stock (<5)
          if (_showLowStock && !_showOutOfStock) {
            return matchesSearch && product.currentStock < 5 && product.currentStock > 0;
          }
          
          // Filtro de sin stock (0)
          if (_showOutOfStock && !_showLowStock) {
            return matchesSearch && product.currentStock == 0;
          }
          
          // Ambos filtros
          if (_showLowStock && _showOutOfStock) {
            return matchesSearch && product.currentStock < 5;
          }
          
          // Sin filtros de stock
          return matchesSearch;
        }).toList();
      });
    });
  }

  // Método para navegar a la página de compras con el producto seleccionado
  void _navigateToPurchase(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseOrderPage(initialProduct: product),
      ),
    ).then((_) {
      // Recargar productos al regresar (opcional)
      _loadProducts();
    });
  }

  // Método para navegar a la página de ventas con el producto seleccionado
  void _navigateToSale(Product product) {
    // Verificación de stock antes de navegar
    if (product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay stock disponible para vender.'),
          backgroundColor: Colors.orange
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesOrderPage(initialProduct: product),
      ),
    ).then((_) {
      // Recargar productos al regresar (opcional)
      _loadProducts();
    });
  }

  void _navigateAndRefresh(BuildContext context, {Product? product}) async {
    // Navegar al formulario y esperar resultado
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormPage(product: product),
      ),
    );

    // Si el formulario devolvió true (indicando cambios), recargar la lista
    if (result == true && mounted) {
      _loadProducts(); // Esto recargará los productos y aplicará los filtros
    }
  }

  Future<void> _deleteProduct(int id) async {
    // Implementar diálogo de confirmación
     bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Borrado'),
            content: const Text('¿Estás seguro de que deseas eliminar este producto?\n\nNota: No se podrá eliminar si está asociado a ventas.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red, // Color rojo para acción destructiva
                ),
                child: const Text('Eliminar'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false; // Si se cierra el diálogo sin seleccionar, retorna false

     if (confirmDelete) {
        try {
          await _dbHelper.deleteProduct(id);
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.green),
              );
              _loadProducts(); // Recargar lista
           }
        } catch (e) {
            if (mounted) {
              // Mostrar un mensaje más claro si el error es por restricción de clave externa
              String errorMessage = 'Error al eliminar producto';
              
              if (e.toString().contains('FOREIGN KEY constraint failed')) {
                errorMessage = 'No se puede eliminar: producto asociado a ventas existentes';
              } else {
                errorMessage = 'Error al eliminar producto: $e';
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
              );
            }
        }
     }
  }

  // Widget para construir la fila de filtros
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Filtro de stock bajo
          FilterChip(
            label: const Text('Stock bajo (<5)'),
            selected: _showLowStock,
            onSelected: (selected) {
              setState(() {
                _showLowStock = selected;
                _applyFilters();
              });
            },
            avatar: Icon(
              _showLowStock ? Icons.check_circle : Icons.warning_amber_rounded,
              color: _showLowStock ? Colors.white : Colors.orange,
            ),
            backgroundColor: Colors.grey.shade200,
            selectedColor: Colors.orange,
            checkmarkColor: Colors.white,
          ),
          const SizedBox(width: 8),
          // Filtro de sin stock
          FilterChip(
            label: const Text('Sin stock (0)'),
            selected: _showOutOfStock,
            onSelected: (selected) {
              setState(() {
                _showOutOfStock = selected;
                _applyFilters();
              });
            },
            avatar: Icon(
              _showOutOfStock ? Icons.check_circle : Icons.error_outline,
              color: _showOutOfStock ? Colors.white : Colors.red,
            ),
            backgroundColor: Colors.grey.shade200,
            selectedColor: Colors.red,
            checkmarkColor: Colors.white,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Productos'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar productos',
                hintText: 'Nombre, descripción, SKU...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          
          // Fila de filtros (chips)
          _buildFilterBar(),
          
          // Lista de productos
          Expanded(
            child: FutureBuilder<List<Product>>(
              key: _futureBuilderKey,
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar productos: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay productos registrados.'));
                }

                if (_filteredProducts.isEmpty) {
                  return const Center(child: Text('No se encontraron productos con los filtros aplicados.'));
                }

                return ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    
                    // Determinar el color del stock según la cantidad
                    Color stockColor = Colors.black;
                    if (product.currentStock == 0) {
                      stockColor = Colors.red;
                    } else if (product.currentStock < 5) {
                      stockColor = Colors.orange;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Stock: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${product.currentStock}',
                                  style: TextStyle(
                                    color: stockColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text('PVP: ${_currencyFormatter.format(product.sellingPriceVes)}'),
                              ],
                            ),
                            if (product.sku != null && product.sku!.isNotEmpty)
                              Text('SKU: ${product.sku}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        // Trailing con botones de acción
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón de Venta (Salidas)
                            InkWell(
                              onTap: () => _navigateToSale(product),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.logout, color: Colors.green, size: 24),
                                  const Text('Salidas', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Botón de Compra (Entradas)
                            InkWell(
                              onTap: () => _navigateToPurchase(product),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.login, color: Colors.blue, size: 24),
                                  const Text('Entradas', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Botón Eliminar Producto
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              tooltip: 'Eliminar Producto',
                              onPressed: () => _deleteProduct(product.id!),
                            ),
                          ],
                        ),
                        onTap: () => _navigateAndRefresh(context, product: product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(context),
        tooltip: 'Añadir Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
} 