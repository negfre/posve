import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'package:intl/intl.dart'; // Para fechas y números
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../../models/inventory_movement.dart';
import '../../models/expense.dart';
import '../../services/database_helper.dart';
import '../../widgets/searchable_list_dialog.dart';
import '../suppliers/supplier_form_page.dart'; // <-- Importar formulario de proveedor
import '../products/product_form_page.dart'; // <-- Importar formulario de producto
// Importar cualquier otro widget que necesitemos, como un buscador

// Clase auxiliar para manejar los items dentro de la orden de compra
class PurchaseOrderItem {
  final Product product;
  int quantity;
  double purchasePriceUsd; // Precio unitario para ESTA compra

  PurchaseOrderItem({
    required this.product,
    this.quantity = 1, // Por defecto 1
    required this.purchasePriceUsd,
  });

  // Calcular subtotal para este item
  double get subtotal => quantity * purchasePriceUsd;
}


class PurchaseOrderPage extends StatefulWidget {
  final Product? initialProduct; // Producto inicial para añadir a la compra
  
  const PurchaseOrderPage({
    super.key,
    this.initialProduct
  });

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>(); // Para validaciones futuras
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Estado de la Orden ---
  Supplier? _selectedSupplier;
  final _invoiceController = TextEditingController();
  String _paymentMethod = 'Contado'; // Opciones: Contado, Credito
  DateTime? _dueDate; // Fecha de vencimiento si es crédito
  final List<PurchaseOrderItem> _orderItems = []; // Carrito de compra

  // --- Estado para carga de datos ---
  List<Supplier> _suppliers = [];
  bool _isLoadingSuppliers = false;
  List<Product> _allProducts = []; // Mantener lista completa de productos
  bool _isLoadingProducts = false;

  // --- Formateadores ---
   final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
   final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$'); // USD para precios
   // Formatter para VES (opcional, si queremos mostrar ambos)
   final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');
   double _currentExchangeRate = 1.0; // Guardar tasa de cambio actual

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Cargar proveedores, productos y tasa inicial
  Future<void> _loadInitialData() async {
     await _loadSuppliers();
     await _loadProducts(); // Cargar todos los productos al inicio
     await _loadExchangeRate();
     
     // Si hay un producto inicial, añadirlo
     if (widget.initialProduct != null && mounted) {
       _addInitialProduct();
     }
  }

  Future<void> _loadExchangeRate() async {
     try {
       _currentExchangeRate = await _dbHelper.getExchangeRate();
       // No es necesario setState si solo lo usamos internamente al calcular
     } catch (e) {
       print("Error cargando tasa de cambio: $e");
       // Podríamos mostrar un error si es crítico
     }
   }

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final suppliers = await _dbHelper.getSuppliers();
      if(mounted) { // Verificar antes de llamar a setState
        setState(() {
          _suppliers = suppliers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar proveedores: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuppliers = false);
      }
    }
  }

   Future<void> _loadProducts() async {
     if (_isLoadingProducts) return; // Evitar cargas múltiples
     setState(() => _isLoadingProducts = true);
     try {
       final products = await _dbHelper.getProducts();
        if(mounted) {
          setState(() {
            _allProducts = products;
          });
        }
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cargar productos: $e'), backgroundColor: Colors.red),
         );
       }
     } finally {
       if (mounted) {
         setState(() => _isLoadingProducts = false);
       }
     }
   }

  // --- Lógica para seleccionar fecha ---
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(), // No permitir fechas pasadas
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // Límite razonable
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  // --- NUEVA FUNCIÓN PARA NAVEGAR Y AÑADIR PROVEEDOR ---
  Future<void> _navigateToAddSupplier() async {
     final result = await Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const SupplierFormPage()),
     );

     // Si se guardó un proveedor nuevo (asumiendo que devuelve true)
     if (result == true && mounted) {
       print("Nuevo proveedor guardado, recargando lista...");
       await _loadSuppliers(); // Recargar la lista de proveedores
       // Opcional: intentar seleccionar el último añadido (requiere más lógica)
       // Podríamos intentar obtener el último ID o buscar por nombre/taxid
       // Por simplicidad, solo recargamos; el usuario selecciona de la lista actualizada.
       // Si quisiéramos preseleccionar, necesitaríamos que SupplierFormPage devuelva el ID
       // o hacer una query para encontrar el último añadido.
     }
  }

  // --- NUEVA FUNCIÓN PARA NAVEGAR A CREAR PRODUCTO ---
  Future<void> _navigateToCreateProduct() async {
    // Navegar a ProductFormPage para crear uno nuevo
    // Asumimos que ProductFormPage puede devolver el Product creado
    final newProduct = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (context) => const ProductFormPage()),
    );

    if (newProduct != null && mounted) {
      print("Nuevo producto creado: ${newProduct.name}, ID: ${newProduct.id}");
      // Recargar la lista de productos completa para incluir el nuevo
      await _loadProducts();

      // Abrir diálogo de cantidad/precio para el nuevo producto
      // Usamos un post frame callback para asegurar que el estado esté actualizado
      WidgetsBinding.instance.addPostFrameCallback((_) async {
         if (!mounted) return;
         final Map<String, dynamic>? result = await _showQuantityPriceDialog(newProduct);
         if (result != null) {
           _addOrUpdateOrderItem(newProduct, result['quantity'] as int, result['price'] as double);
         }
      });
    } else {
       print("Creación de producto cancelada o fallida.");
    }
  }

  // --- Lógica para añadir/editar/eliminar items ---

  // 1. Mostrar diálogo de búsqueda de producto
  Future<void> _showProductSearchDialog() async {
    if (_isLoadingProducts) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cargando productos...'), duration: Duration(seconds: 1)),
        );
       return;
    }
    if (_allProducts.isEmpty) {
       await _loadProducts();
       if (_allProducts.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('No hay productos para seleccionar.'), backgroundColor: Colors.orange),
         );
         return;
       }
    }

    final Product? selectedProduct = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return SearchableListDialog<Product>(
           title: 'Buscar Producto',
           items: _allProducts,
           itemBuilder: (product) => ListTile(
              title: Text(product.name),
              subtitle: Text('SKU: ${product.sku ?? 'N/A'} | Stock: ${product.currentStock}'),
            ),
           filterFn: (product, query) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              (product.sku?.toLowerCase().contains(query.toLowerCase()) ?? false),
           onItemSelected: (product) {
              Navigator.of(context).pop(product);
           },
        );
      },
    );

    if (selectedProduct != null) {
      final Map<String, dynamic>? result = await _showQuantityPriceDialog(selectedProduct);
      if (result != null) {
        _addOrUpdateOrderItem(selectedProduct, result['quantity'] as int, result['price'] as double);
      }
    }
  }

  // 2. Mostrar diálogo para cantidad y precio (Refactorizado)
  Future<Map<String, dynamic>?> _showQuantityPriceDialog(Product product) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _QuantityPriceForm(product: product);
      },
    );
  }

  // 3. Añadir o actualizar item en la lista _orderItems
  void _addOrUpdateOrderItem(Product product, int quantity, double price) {
    final existingIndex = _orderItems.indexWhere((item) => item.product.id == product.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (existingIndex >= 0) {
          _orderItems[existingIndex].quantity = quantity;
          _orderItems[existingIndex].purchasePriceUsd = price;
          if (mounted) { // Check mounted again before showing SnackBar
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('${product.name} actualizado en la orden.'), duration: const Duration(seconds: 2)),
             );
          }
        } else {
          _orderItems.add(PurchaseOrderItem(
            product: product,
            quantity: quantity,
            purchasePriceUsd: price,
          ));
        }
      });
    });
  }

  // 4. Eliminar item de la orden
  void _removeProductFromOrder(int index) {
    if (!mounted) return;
    setState(() {
      final removedItem = _orderItems.removeAt(index);
       if (mounted) { // Check mounted again before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${removedItem.product.name} eliminado de la orden.'), duration: const Duration(seconds: 2)),
          );
       }
    });
  }

  // --- Lógica para guardar la orden ---
  Future<void> _savePurchaseOrder() async {
    // 1. Validar formulario de cabecera y que haya items
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Revise los campos de la cabecera (Proveedor, Fecha Límite).'), backgroundColor: Colors.orange),
       );
      return;
    }
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añada al menos un producto a la orden.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // TODO: Mostrar indicador de carga
    // setState(() => _isSaving = true); 

    bool success = true; // Flag para saber si todo salió bien
    String? errorMessage;

    try {
      // Asegurarnos de tener la tasa de cambio más reciente
      await _loadExchangeRate(); 

      // Procesar cada item de la orden
      for (final item in _orderItems) {
        final movement = InventoryMovement(
          productId: item.product.id!, 
          type: 'purchase',
          quantity: item.quantity,
          movementDate: DateTime.now(),
          unitPriceUsd: item.purchasePriceUsd,
          // Calcular precio en VES con la tasa actual
          unitPriceVes: item.purchasePriceUsd * _currentExchangeRate,
          exchangeRate: _currentExchangeRate,
          // Asegurarnos de que _selectedSupplier no sea null (validado por formKey)
          supplierId: _selectedSupplier!.id,
        );
        
        // Registrar la compra (esto actualiza el stock)
        await _dbHelper.recordPurchase(movement);

        // === NUEVO: Registrar gasto por cada producto ===
        final expense = Expense(
          description: 'Compra de ${item.product.name}',
          amount: item.purchasePriceUsd * item.quantity,
          category: 'Compras',
          expenseDate: DateTime.now(),
          notes: 'Compra registrada desde orden de compra',
          receiptNumber: _invoiceController.text.isNotEmpty ? _invoiceController.text : null,
          supplier: _selectedSupplier?.name,
          paymentMethod: _paymentMethod,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _dbHelper.insertExpense(expense);
      }
    } catch (e) {
      success = false;
      errorMessage = e.toString();
      print("Error guardando la orden de compra: $e");
    } finally {
       // TODO: Ocultar indicador de carga
       // if (mounted) {
       //   setState(() => _isSaving = false);
       // }
    }

    // Mostrar resultado y cerrar si fue exitoso
    if (mounted) {
       if (success) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Compra registrada exitosamente.'), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop(true); // Cambiado para notificar éxito
       } else {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al guardar la compra: ${errorMessage ?? 'Error desconocido'}'), backgroundColor: Colors.red),
         );
       }
    }
  }

  // --- Calcular total de la orden ---
  double get _orderTotal {
     return _orderItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Entrada'),
        actions: [
          // Botón para guardar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Guardar Entrada',
              onPressed: (_orderItems.isEmpty || _isLoadingSuppliers || _isLoadingProducts)
                ? null 
                : _savePurchaseOrder,
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Sección Proveedor ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proveedor', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Supplier>(
                              value: _selectedSupplier,
                              hint: const Text('Seleccione Proveedor'),
                              isExpanded: true,
                              items: _suppliers.map((Supplier supplier) {
                                return DropdownMenuItem<Supplier>(
                                  value: supplier,
                                  child: Text(supplier.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: _isLoadingSuppliers ? null : (Supplier? newValue) {
                                setState(() {
                                  _selectedSupplier = newValue;
                                });
                              },
                              validator: (value) => value == null ? 'Seleccione un proveedor' : null,
                              decoration: InputDecoration(
                                prefixIcon: _isLoadingSuppliers 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const Icon(Icons.business),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón para añadir nuevo proveedor
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_business),
                            label: const Text('Nuevo'),
                            onPressed: _isLoadingSuppliers ? null : _navigateToAddSupplier,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // --- Sección Información General (Factura, Fecha) ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Información de Entrada', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      // Número de Factura/Nota
                      TextFormField(
                        controller: _invoiceController,
                        decoration: const InputDecoration(
                          labelText: 'Nro. Factura / Nota de Entrega',
                          prefixIcon: Icon(Icons.receipt_long),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Forma de Pago
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        items: const [
                          DropdownMenuItem(value: 'Contado', child: Text('Contado')),
                          DropdownMenuItem(value: 'Credito', child: Text('Crédito')),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _paymentMethod = newValue;
                              if (_paymentMethod == 'Contado') {
                                _dueDate = null; // Limpiar fecha si es contado
                              }
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Forma de Pago',
                          prefixIcon: Icon(Icons.payment),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // Fecha de Vencimiento (si es crédito)
                      if (_paymentMethod == 'Credito') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: _dueDate == null ? 'Seleccione fecha límite' : _dateFormatter.format(_dueDate!),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Fecha Límite de Pago *',
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit_calendar),
                              onPressed: () => _selectDueDate(context),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          onTap: () => _selectDueDate(context),
                          validator: (value) {
                            if (_paymentMethod == 'Credito' && _dueDate == null) {
                              return 'Seleccione una fecha límite para crédito';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // --- Sección Items ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Productos/Items', style: Theme.of(context).textTheme.titleMedium),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Añadir'),
                            onPressed: _isLoadingProducts ? null : _showProductSearchDialog,
                          )
                        ],
                      ),
                      const Divider(),
                      if (_orderItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('Añada productos a la entrada.')),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _orderItems.length,
                          itemBuilder: (context, index) {
                            final item = _orderItems[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(item.product.name),
                              subtitle: Text(
                                '${item.quantity} x ${_currencyFormatter.format(item.purchasePriceUsd)} = ${_currencyFormatter.format(item.subtotal)}'
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _removeProductFromOrder(index),
                              ),
                              // Permitir editar cantidad/precio tocando el item
                              onTap: () async {
                                final result = await _showQuantityPriceDialog(item.product);
                                if (result != null) {
                                  _addOrUpdateOrderItem(
                                    item.product,
                                    result['quantity'] as int,
                                    result['price'] as double
                                  );
                                }
                              },
                            );
                          },
                        ),
                      if (_isLoadingProducts)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // --- Sección Totales ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL ENTRADA:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormatter.format(_orderTotal),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                _currencyFormatterVes.format(_orderTotal * _currentExchangeRate),
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // --- Botón Guardar ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Completar Entrada'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  onPressed: (_orderItems.isEmpty || _isLoadingSuppliers || _isLoadingProducts)
                    ? null
                    : _savePurchaseOrder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para añadir el producto inicial
  void _addInitialProduct() {
    // Buscar el producto en la lista completa para obtener datos actualizados
    final productToAdd = _allProducts.firstWhere(
      (p) => p.id == widget.initialProduct!.id,
      orElse: () => widget.initialProduct!,
    );
    
    // Mostrar diálogo para ingresar cantidad y precio
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final Map<String, dynamic>? result = await _showQuantityPriceDialog(productToAdd);
      if (result != null) {
        _addOrUpdateOrderItem(productToAdd, result['quantity'] as int, result['price'] as double);
        
        // Mostrar mensaje
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto "${productToAdd.name}" añadido a la compra.'), backgroundColor: Colors.green),
        );
      }
    });
  }

} // Fin _PurchaseOrderPageState 

// --- WIDGET INTERNO PARA EL FORMULARIO DEL DIÁLOGO ---
class _QuantityPriceForm extends StatefulWidget {
  final Product product;

  const _QuantityPriceForm({required this.product});

  @override
  State<_QuantityPriceForm> createState() => _QuantityPriceFormState();
}

class _QuantityPriceFormState extends State<_QuantityPriceForm> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    // Inicializar precio con el último precio de compra o 0
    _priceController = TextEditingController(text: widget.product.purchasePriceUsd.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Añadir ${widget.product.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingrese cantidad';
                final quantity = int.tryParse(value);
                if (quantity == null || quantity <= 0) return 'Cantidad inválida';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio Compra Unitario (USD)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                 FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingrese precio';
                final price = double.tryParse(value);
                if (price == null || price < 0) return 'Precio inválido';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Añadir'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'quantity': int.parse(_quantityController.text),
                'price': double.parse(_priceController.text),
              });
            }
          },
        ),
      ],
    );
  }
} 