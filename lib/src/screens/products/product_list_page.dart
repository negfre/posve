import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear
import '../../models/product.dart';
import '../../models/inventory_movement.dart';
import '../../services/database_helper.dart';
import '../../services/license_service.dart';
import '../../widgets/modern_widgets.dart';
import '../../widgets/floating_cart.dart';
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
  final LicenseService _licenseService = LicenseService();
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
  
  // Carrito emergente
  final List<CartItem> _cartItems = [];

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
      body: Stack(
        children: [
          Column(
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
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: _cartItems.isNotEmpty ? 100 : 16, // Padding extra cuando hay carrito
                    ),
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
          // Carrito flotante
          FloatingCart(
            items: _cartItems,
            onTap: () => _goToOrderPage(),
            onRemove: (item) {
              setState(() {
                _cartItems.remove(item);
              });
            },
            onUpdateQuantity: (item, newQuantity) {
              setState(() {
                item.quantity = newQuantity;
              });
            },
          ),
        ],
      ),
      floatingActionButton: _cartItems.isEmpty
          ? FutureBuilder<bool>(
              future: _licenseService.canAddProduct(),
              builder: (context, snapshot) {
                final canAdd = snapshot.data ?? true;
                return FloatingActionButton.extended(
                  onPressed: canAdd ? () => _navigateAndRefresh(context) : () {
                    _showLimitReachedDialog();
                  },
                  icon: Icon(canAdd ? Icons.add : Icons.info_outline),
                  label: Text(canAdd ? 'Agregar' : 'Límite alcanzado'),
                  backgroundColor: canAdd ? AppColors.primaryColor : Colors.orange,
                );
              },
            )
          : null, // Ocultar FAB cuando hay items en el carrito
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información principal del producto
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del producto
                  Expanded(
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
                  Column(
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
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              
              // Botones de acción en fila
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Vender
                  if (!isOutOfStock)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _quickAddToCart(product, true),
                        icon: const Icon(Icons.point_of_sale, size: 16),
                        label: const Text(
                          'Vender',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.saleColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                  if (!isOutOfStock) const SizedBox(width: 6),
                  // Botón Entrada
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _registerDirectEntry(product),
                      icon: const Icon(Icons.input, size: 16),
                      label: const Text(
                        'Entrada',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purchaseColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Botón Editar
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: AppColors.primaryColor,
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _navigateAndRefresh(context, product: product),
                  ),
                  const SizedBox(width: 4),
                  // Menú de opciones
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      switch (value) {
                        case 'delete':
                          _deleteProduct(product);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLimitReachedDialog() async {
    final currentCount = await _licenseService.getCurrentProductCount();
    final maxLimit = await _licenseService.getMaxProductsLimit();
    
    if (maxLimit == null) return; // Sin límite (tiene licencia)
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Límite de Productos Alcanzado'),
            ],
          ),
          content: Text(
            'Has alcanzado el límite de $maxLimit productos en el modo de prueba.\n\n'
            'Actualmente tienes $currentCount productos.\n\n'
            'Para agregar más productos, activa una licencia en Configuración > Activar Licencia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/activate-license');
              },
              child: const Text('Activar Licencia'),
            ),
          ],
        );
      },
    );
  }

  // Añadir producto al carrito rápidamente
  Future<void> _quickAddToCart(Product product, bool isSale) async {
    // Verificar stock para ventas
    if (isSale && product.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay stock disponible para ${product.name}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar si ya está en el carrito
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id && item.isSale == isSale,
    );

    int quantity = 1;
    if (existingIndex != -1) {
      // Si ya existe, aumentar cantidad
      quantity = _cartItems[existingIndex].quantity + 1;
      
      // Verificar límite de stock para ventas
      if (isSale && quantity > product.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock máximo: ${product.currentStock}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      setState(() {
        _cartItems[existingIndex].quantity = quantity;
      });
    } else {
      // Mostrar diálogo para cantidad inicial
      final int? selectedQuantity = await _showQuickQuantityDialog(product, isSale);
      if (selectedQuantity != null && selectedQuantity > 0) {
        setState(() {
          _cartItems.add(CartItem(
            product: product,
            quantity: selectedQuantity,
            isSale: isSale,
          ));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product.name} añadido al carrito',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: isSale ? AppColors.saleColor : AppColors.purchaseColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Registrar entrada directamente desde el botón
  Future<void> _registerDirectEntry(Product product) async {
    // Mostrar diálogo para seleccionar cantidad
    final int? quantity = await _showQuickQuantityDialog(product, false);
    
    if (quantity == null || quantity <= 0) {
      return; // Usuario canceló o cantidad inválida
    }

    try {
      // Obtener tasa de cambio actual
      final exchangeRate = await _dbHelper.getExchangeRate();
      
      // Crear movimiento de entrada
      final movement = InventoryMovement(
        productId: product.id!,
        type: 'purchase',
        quantity: quantity,
        movementDate: DateTime.now(),
        unitPriceUsd: product.purchasePriceUsd,
        unitPriceVes: product.purchasePriceUsd * exchangeRate,
        exchangeRate: exchangeRate,
        supplierId: null, // Entrada directa sin proveedor específico
      );

      // Registrar el movimiento (actualiza stock automáticamente)
      await _dbHelper.recordPurchase(movement);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entrada de $quantity ${product.name} registrada correctamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Recargar productos para actualizar el stock
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar entrada: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print("Error registrando entrada: $e");
    }
  }

  // Diálogo rápido para seleccionar cantidad
  Future<int?> _showQuickQuantityDialog(Product product, bool isSale) async {
    int quantity = 1;
    int maxQuantity = isSale ? product.currentStock : 999; // Para compras no hay límite práctico

    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isSale ? 'Cantidad a vender' : 'Cantidad de entrada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle),
                        onPressed: quantity > 1
                            ? () => setDialogState(() => quantity--)
                            : null,
                        color: AppColors.errorColor,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: quantity < maxQuantity
                            ? () => setDialogState(() => quantity++)
                            : null,
                        color: AppColors.successColor,
                      ),
                    ],
                  ),
                  if (isSale)
                    Text(
                      'Stock disponible: ${product.currentStock}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(quantity),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSale ? AppColors.saleColor : AppColors.purchaseColor,
                  ),
                  child: const Text('Añadir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Ir a la página de orden (venta o compra)
  void _goToOrderPage() {
    if (_cartItems.isEmpty) return;

    // Separar items de venta y compra
    final saleItems = _cartItems.where((item) => item.isSale).toList();
    final purchaseItems = _cartItems.where((item) => !item.isSale).toList();

    // Si hay items de venta, ir a venta
    if (saleItems.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalesOrderPage(initialCartItems: saleItems),
        ),
      ).then((_) {
        // Limpiar items de venta del carrito
        setState(() {
          _cartItems.removeWhere((item) => item.isSale);
        });
      });
    }
    
    // Si hay items de compra, ir a compra
    if (purchaseItems.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseOrderPage(initialCartItems: purchaseItems),
        ),
      ).then((result) {
        // Limpiar items de compra del carrito
        if (result == true) {
          setState(() {
            _cartItems.removeWhere((item) => !item.isSale);
            _loadProducts(); // Recargar productos
          });
        }
      });
    }
  }
} 