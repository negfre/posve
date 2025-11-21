import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear
import '../../models/product.dart';
import '../../services/database_helper.dart';
import '../../widgets/modern_widgets.dart';
import '../../constants/app_colors.dart';
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
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
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
    _searchQuery = _searchController.text.toLowerCase();
    
    _productsFuture.then((products) {
      setState(() {
        _filteredProducts = products.where((product) {
          // Filtro de búsqueda
          bool matchesSearch = product.name.toLowerCase().contains(_searchQuery) ||
                              product.description.toLowerCase().contains(_searchQuery) ||
                              (product.sku?.toLowerCase().contains(_searchQuery) ?? false);
          
          // Filtro de stock bajo
          bool matchesLowStock = !_showLowStock || product.currentStock <= product.minStock;
          
          // Filtro de sin stock
          bool matchesOutOfStock = !_showOutOfStock || product.currentStock == 0;
          
          return matchesSearch && matchesLowStock && matchesOutOfStock;
        }).toList();
      });
    });
  }

  // Método para eliminar producto
  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de eliminar "${product.name}"?\n\nEsta acción no se puede deshacer.'),
          actions: [
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
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteProduct(product.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Producto "${product.name}" eliminado correctamente'),
              backgroundColor: AppColors.successColor,
            ),
          );
          _loadProducts(); // Recargar la lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar producto: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    }
  }

  // Navegar al formulario y recargar al volver
  void _navigateAndRefresh(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(product: product),
      ),
    ).then((_) {
      _loadProducts(); // Recargar la lista al volver
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildSearchAndFilters(),
          
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar productos',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLightColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GradientButton(
                          text: 'Reintentar',
                          onPressed: _loadProducts,
                          icon: Icons.refresh,
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No hay productos',
                    message: 'Comienza agregando tu primer producto para gestionar tu inventario.',
                    icon: Icons.inventory_2,
                    onAction: () => _navigateAndRefresh(context),
                    actionText: 'Agregar Producto',
                  );
                }

                if (_filteredProducts.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No se encontraron productos',
                    message: 'Intenta ajustar los filtros de búsqueda.',
                    icon: Icons.search_off,
                    onAction: () {
                      _searchController.clear();
                      _showLowStock = false;
                      _showOutOfStock = false;
                      _applyFilters();
                    },
                    actionText: 'Limpiar Filtros',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProductCard(product),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateAndRefresh(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        backgroundColor: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
          ),
          const SizedBox(height: 12),
          
          // Filtros
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Stock Bajo'),
                  selected: _showLowStock,
                  onSelected: (selected) {
                    setState(() {
                      _showLowStock = selected;
                      _applyFilters();
                    });
                  },
                  selectedColor: AppColors.warningColor.withOpacity(0.2),
                  checkmarkColor: AppColors.warningColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('Sin Stock'),
                  selected: _showOutOfStock,
                  onSelected: (selected) {
                    setState(() {
                      _showOutOfStock = selected;
                      _applyFilters();
                    });
                  },
                  selectedColor: AppColors.errorColor.withOpacity(0.2),
                  checkmarkColor: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLowStock = product.currentStock <= product.minStock;
    final isOutOfStock = product.currentStock == 0;
    
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateAndRefresh(context, product: product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Información principal del producto
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del producto
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Descripción
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textLightColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // SKU
                    const SizedBox(height: 6),
                    Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Información de stock y precio
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Precios
                    Text(
                      _currencyFormatter.format(product.sellingPriceUsd),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      _currencyFormatterVes.format(product.sellingPriceVes),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedColor,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Stock
                    Text(
                      'Stock: ${product.currentStock}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock 
                            ? AppColors.errorColor 
                            : isLowStock 
                                ? AppColors.warningColor 
                                : AppColors.successColor,
                      ),
                    ),
                    
                    // Estado del stock
                    if (isLowStock && !isOutOfStock)
                      const Text(
                        'Stock bajo',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (isOutOfStock)
                      const Text(
                        'Sin stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.errorColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Botón de acciones
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 24),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _navigateAndRefresh(context, product: product);
                      break;
                    case 'delete':
                      _deleteProduct(product);
                      break;
                    case 'sell':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SalesOrderPage(initialProduct: product),
                        ),
                      );
                      break;
                    case 'buy':
                      _buyProduct(product);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sell',
                    child: Row(
                      children: [
                        Icon(Icons.point_of_sale, size: 20),
                        SizedBox(width: 8),
                        Text('Vender'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'buy',
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 20),
                        SizedBox(width: 8),
                        Text('Comprar'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.errorColor, size: 20),
                        const SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: AppColors.errorColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _buyProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderPage(initialProduct: product),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
  }
} 