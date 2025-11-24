import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../constants/app_colors.dart';

// Item del carrito
class CartItem {
  final Product product;
  int quantity;
  final bool isSale; // true para venta, false para compra

  CartItem({
    required this.product,
    this.quantity = 1,
    required this.isSale,
  });

  double get subtotalUsd => isSale 
      ? quantity * product.sellingPriceUsd 
      : quantity * product.purchasePriceUsd;
}

// Widget de carrito flotante
class FloatingCart extends StatefulWidget {
  final List<CartItem> items;
  final VoidCallback onTap;
  final Function(CartItem) onRemove;
  final Function(CartItem, int) onUpdateQuantity;

  const FloatingCart({
    super.key,
    required this.items,
    required this.onTap,
    required this.onRemove,
    required this.onUpdateQuantity,
  });

  @override
  State<FloatingCart> createState() => _FloatingCartState();
}

class _FloatingCartState extends State<FloatingCart> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  bool _isExpanded = false;

  double get _total {
    return widget.items.fold(0.0, (sum, item) => sum + item.subtotalUsd);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular altura dinámica basada en cantidad de items
    final maxHeight = MediaQuery.of(context).size.height * 0.6; // Máximo 60% de la pantalla
    final itemHeight = 70.0;
    final headerHeight = 70.0;
    final footerHeight = 60.0;
    final calculatedHeight = headerHeight + 
        (widget.items.length * itemHeight).clamp(0.0, maxHeight - headerHeight - footerHeight) + 
        footerHeight;
    
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        height: _isExpanded ? calculatedHeight : 70,
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header del carrito
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                          if (widget.items.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${widget.items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carrito (${widget.items.length} ${widget.items.length == 1 ? 'producto' : 'productos'})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total: ${_currencyFormatter.format(_total)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              // Lista de items (expandible)
              if (_isExpanded)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return _buildCartItem(item, index);
                    },
                  ),
                ),
              // Botón de acción
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ${_currencyFormatter.format(_total)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continuar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: item.isSale ? AppColors.saleColor : AppColors.purchaseColor,
          child: Icon(
            item.isSale ? Icons.point_of_sale : Icons.shopping_cart,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          item.product.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _currencyFormatter.format(item.subtotalUsd),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón de disminuir cantidad
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () {
                if (item.quantity > 1) {
                  widget.onUpdateQuantity(item, item.quantity - 1);
                } else {
                  widget.onRemove(item);
                }
              },
              color: AppColors.errorColor,
            ),
            // Cantidad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            // Botón de aumentar cantidad
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () {
                if (item.isSale && item.quantity >= item.product.currentStock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock máximo: ${item.product.currentStock}'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  widget.onUpdateQuantity(item, item.quantity + 1);
                }
              },
              color: AppColors.successColor,
            ),
            // Botón de eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => widget.onRemove(item),
              color: AppColors.errorColor,
            ),
          ],
        ),
      ),
    );
  }
}



