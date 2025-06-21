import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Necesario para PaymentMethodProvider
import '../../models/client.dart'; // Cambiado de Supplier a Client
import '../../models/product.dart';
// Necesario para guardar
import '../../models/payment_method.dart'; // Importar PaymentMethod
import '../../providers/payment_method_provider.dart'; // Importar Provider
import '../../services/database_helper.dart';
import '../../widgets/searchable_list_dialog.dart';
// Para añadir nuevo cliente
import '../../models/sale.dart'; // Necesario para guardar
import '../../models/sale_item.dart'; // Necesario para guardar

// Clase auxiliar para manejar los items dentro de la orden de venta
class SalesOrderItem {
  final Product product;
  int quantity;
  // Usaremos el precio de venta del producto al momento de añadirlo
  final double sellingPriceUsd;
  final double sellingPriceVes;

  SalesOrderItem({
    required this.product,
    required this.quantity,
    required this.sellingPriceUsd,
    required this.sellingPriceVes,
  });

  // Calcular subtotal para este item (podríamos elegir USD o VES)
  double get subtotalUsd => quantity * sellingPriceUsd;
  double get subtotalVes => quantity * sellingPriceVes;
  
  // Determinar si este item está exento de IVA
  bool get isVatExempt => product.isVatExempt;
}

// Clase para manejar los pagos mixtos
class PaymentEntry {
  final PaymentMethod method;
  double amountUsd;
  String? reference;

  PaymentEntry({
    required this.method,
    required this.amountUsd,
    this.reference,
  });

  // Calcular el monto en bolívares
  double calculateAmountVes(double exchangeRate) {
    return amountUsd * exchangeRate;
  }

  // Convertir a cadena detallada para guardar
  String toDetailString() {
    final details = '${method.name}: \$${amountUsd.toStringAsFixed(2)}';
    if (reference != null && reference!.isNotEmpty) {
      return '$details (Ref: $reference)';
    }
    return details;
  }
}

class SalesOrderPage extends StatefulWidget {
  final Product? initialProduct; // Producto inicial para añadir automáticamente
  
  const SalesOrderPage({
    super.key, 
    this.initialProduct
  });

  @override
  State<SalesOrderPage> createState() => _SalesOrderPageState();
}

class _SalesOrderPageState extends State<SalesOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Estado de la Orden ---
  Client? _selectedClient; // Cliente seleccionado (null = Consumidor Final)
  final _invoiceNumberController = TextEditingController(); // Para Nro Factura/Control
  // Variable para pagos múltiples
  final List<PaymentEntry> _paymentEntries = [];
  // La referencia general ahora es opcional
  final _paymentDetailsController = TextEditingController(); // Para referencia global
  DateTime _saleDate = DateTime.now(); // Fecha automática
  final List<SalesOrderItem> _orderItems = []; // Carrito de venta

  // --- Estado para carga de datos ---
  List<Client> _clients = []; // Cambiado de Supplier
  bool _isLoadingClients = false; // Cambiado
  List<Product> _allProducts = [];
  bool _isLoadingProducts = false;
  double _currentExchangeRate = 1.0;
  double _defaultTaxRate = 0.16; // Tasa de impuesto por defecto
  bool _isVatEnabled = true; // Variable para controlar si el IVA está habilitado

  // --- Estado de UI ---
  bool _isSaving = false;

  // --- Formateadores ---
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    // Retrasar carga hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Verificar si sigue montado
           _loadInitialData();
        }
    });
    // Generar un número de factura/control inicial (ejemplo simple)
    _invoiceNumberController.text = 'V-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  // Cargar datos iniciales completos
  Future<void> _loadInitialData() async {
    try {
      print("SalesOrderPage: Iniciando carga inicial de datos");
      
      // Intentar cargar productos primero
      print("SalesOrderPage: Cargando productos...");
      await _loadProducts();
      
      // Luego cargar clientes y otros datos
      print("SalesOrderPage: Cargando clientes...");
      await _loadClients();
      
      print("SalesOrderPage: Cargando tasas...");
      await _loadExchangeRateAndTax();
      
      // Verificar si tenemos productos después de cargar
      if (_allProducts.isEmpty) {
        print("SalesOrderPage: ADVERTENCIA - No hay productos cargados después de inicialización");
      } else {
        print("SalesOrderPage: Productos cargados correctamente: ${_allProducts.length}");
      }
      
      // Cargar formas de pago usando el provider
      if (mounted) {
        await Provider.of<PaymentMethodProvider>(context, listen: false).loadPaymentMethods();
      }
      
      // Si hay un producto inicial, añadirlo a la orden
      if (widget.initialProduct != null && mounted) {
        _addInitialProduct();
      }
      
      print("SalesOrderPage: Carga inicial completada");
    } catch (e) {
      print("SalesOrderPage: ERROR en carga inicial: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos iniciales: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

   Future<void> _loadClients() async { // Cambiado de loadSuppliers
    setState(() => _isLoadingClients = true);
    try {
      final clients = await _dbHelper.getClients();
      if (mounted) {
        setState(() {
          _clients = clients;
        });
      }
    } catch (e) {
      // Manejar error
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cargar clientes: $e'), backgroundColor: Colors.red),
         );
       }
    } finally {
      if (mounted) {
        setState(() => _isLoadingClients = false);
      }
    }
  }

  Future<void> _loadProducts() async {
     // ... (igual que en compras)
     if (_isLoadingProducts) return;
     setState(() => _isLoadingProducts = true);
     try {
       print("Intentando cargar productos para venta...");
       final products = await _dbHelper.getProducts();
       print("Productos cargados: ${products.length}");
       
       // Verificar si hay productos realmente
       if (products.isEmpty) {
         print("ADVERTENCIA: Lista de productos vacía desde la base de datos");
       } else {
         // Imprimir algunos productos para verificar
         print("Primer producto: ${products.first.name}, Stock: ${products.first.currentStock}");
       }
        
       if(mounted) {
          setState(() {
            _allProducts = products;
            print("_allProducts actualizado, ahora tiene: ${_allProducts.length} productos");
          });
        }
     } catch (e) {
       // Manejar error con más información
       print("ERROR AL CARGAR PRODUCTOS: $e");
       print("Traza de la pila: ${StackTrace.current}");
       
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

  Future<void> _loadExchangeRateAndTax() async {
      try {
       _currentExchangeRate = await _dbHelper.getExchangeRate();
       _defaultTaxRate = await _dbHelper.getDefaultTaxRate();
       _isVatEnabled = await _dbHelper.getVatEnabled(); // Cargar si el IVA está habilitado
       if(mounted) setState((){}); // Actualizar UI si es necesario
     } catch (e) {
       print("Error cargando tasa de cambio/impuesto: $e");
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error cargando configuración: $e'), backgroundColor: Colors.orange),
           );
        }
     }
   }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _paymentDetailsController.dispose();
    super.dispose();
  }


  Future<void> _selectDueDate(BuildContext context) async {
    // ... (igual que en compras)
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
      });
    }
  }

  // --- Lógica para añadir/editar/eliminar items (Adaptar para ventas) ---

  Future<void> _showProductSearchDialog() async {
     // --- Verificar primero si hay productos en la BD ---
     try {
       print("Verificando si hay productos en la base de datos...");
       bool hasProducts = await _dbHelper.hasAnyProducts();
       
       if (!hasProducts) {
         if (mounted) {
           await showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text('Base de datos vacía'),
               content: const Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('No hay productos registrados en la base de datos.'),
                   SizedBox(height: 8),
                   Text('Por favor, añada productos antes de realizar una venta.'),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.of(ctx).pop(),
                   child: const Text('Entendido'),
                 ),
               ],
             ),
           );
         }
         return;
       }
     } catch (e) {
       print("Error verificando productos: $e");
     }
     
     // --- Forzar recarga de productos --- 
     setState(() => _isLoadingProducts = true); // Mostrar indicador mientras carga
     await _loadProducts(); // Siempre cargar la lista antes de mostrar el diálogo
     setState(() => _isLoadingProducts = false);
     // --- Fin Forzar recarga ---

    if (_allProducts.isEmpty && mounted) {
        // Modificado para mostrar un diálogo con más opciones
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No hay productos disponibles'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No se encontraron productos para añadir a la venta.'),
                const SizedBox(height: 8),
                const Text('Posibles soluciones:'),
                const SizedBox(height: 4),
                const Text('• Verifique que ha añadido productos al inventario'),
                const Text('• Compruebe la conexión con la base de datos'),
                const Text('• Revise los logs para más información'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Intentar cargar productos nuevamente
                  _loadProducts();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
        return;
     }

     final Product? selectedProduct = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return SearchableListDialog<Product>(
           title: 'Buscar Producto para Venta',
           items: _allProducts,
           itemBuilder: (product) {
             final sellingPriceVes = product.sellingPriceUsd * _currentExchangeRate;
             return ListTile(
                title: Text(product.name),
                subtitle: Text(
                   'Stock: ${product.currentStock} | PVP: ${_currencyFormatter.format(product.sellingPriceUsd)} (${_currencyFormatterVes.format(sellingPriceVes)})'
                 ),
                 // Marcar si ya está en la orden
                 trailing: _orderItems.any((item) => item.product.id == product.id)
                   ? const Icon(Icons.check_circle, color: Colors.green)
                   : null,
              );
           },
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
         // Verificar si ya está en la orden para editar cantidad
         final existingItemIndex = _orderItems.indexWhere((item) => item.product.id == selectedProduct.id);
         int initialQuantity = existingItemIndex != -1 ? _orderItems[existingItemIndex].quantity : 1;

         // Calcular stock disponible considerando lo que ya está en la orden
         int availableStock = selectedProduct.currentStock;
         if (existingItemIndex != -1) {
           // Si ya está en la orden, sumar la cantidad actual al stock disponible
           availableStock += _orderItems[existingItemIndex].quantity;
         }

         if (availableStock <= 0 && existingItemIndex == -1) {
             if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text('No hay stock disponible para ${selectedProduct.name}.'),
                       backgroundColor: Colors.orange,
                     ),
                 );
             }
             return;
         }
         
         final int? quantity = await _showQuantityDialogStepped(context, selectedProduct, availableStock);
         if (quantity != null) { // quantity puede ser 0 si se quiere eliminar
             _addOrUpdateSalesItem(selectedProduct, quantity);
         }
     }
 }

 Future<int?> _showQuantityDialogStepped(BuildContext context, Product product, int availableStock) async {
    final TextEditingController quantityController = TextEditingController(text: '1');
    int currentValue = 1;

    try {
      return await showDialog<int>(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Text('Cantidad - ${product.name}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mostrar stock disponible
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: availableStock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: availableStock > 0 ? Colors.green.shade200 : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              availableStock > 0 ? Icons.inventory : Icons.inventory_2,
                              color: availableStock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stock disponible: $availableStock unidades',
                                style: TextStyle(
                                  color: availableStock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: currentValue > 1 ? () {
                              setState(() {
                                currentValue--;
                                quantityController.text = currentValue.toString();
                              });
                            } : null,
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                final newValue = int.tryParse(value);
                                if (newValue != null && newValue > 0) {
                                  setState(() {
                                    // Limitar al stock disponible
                                    currentValue = newValue > availableStock ? availableStock : newValue;
                                    quantityController.text = currentValue.toString();
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                errorText: currentValue > availableStock ? 'Excede stock disponible' : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: currentValue < availableStock ? () {
                              setState(() {
                                currentValue++;
                                quantityController.text = currentValue.toString();
                              });
                            } : null,
                          ),
                        ],
                      ),
                      // Mostrar mensaje de advertencia si no hay stock
                      if (availableStock <= 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No hay stock disponible para este producto',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () {
                      quantityController.dispose();
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Aceptar'),
                    onPressed: availableStock > 0 ? () {
                      final quantity = int.tryParse(quantityController.text);
                      if (quantity != null && quantity > 0 && quantity <= availableStock) {
                        quantityController.dispose();
                        Navigator.of(dialogContext).pop(quantity);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cantidad inválida. Máximo disponible: $availableStock'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } : null, // Deshabilitar si no hay stock
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error mostrando diálogo de cantidad: $e');
      return null;
    }
  }

  void _addOrUpdateSalesItem(Product product, int quantity) {
    setState(() {
      final index = _orderItems.indexWhere((item) => item.product.id == product.id);
      if (index != -1) {
        // Actualizar cantidad o eliminar si es 0
        if (quantity > 0) {
          _orderItems[index].quantity = quantity;
        } else {
          _orderItems.removeAt(index);
        }
      } else if (quantity > 0) {
        // Añadir nuevo item
        _orderItems.add(SalesOrderItem(
          product: product,
          quantity: quantity,
          sellingPriceUsd: product.sellingPriceUsd, // Guardar precio al momento de añadir
          sellingPriceVes: product.sellingPriceUsd * _currentExchangeRate,
        ));
      }
      // Ordenar items (opcional)
      _orderItems.sort((a, b) => a.product.name.compareTo(b.product.name));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  // --- Lógica de Cálculo de Totales ---
  double get _subtotalUsd {
    return _orderItems.fold(0.0, (sum, item) => sum + item.subtotalUsd);
  }
  double get _subtotalVes {
     return _orderItems.fold(0.0, (sum, item) => sum + item.subtotalVes);
  }
  
  // Subtotal solo de productos gravables (no exentos)
  double get _taxableSubtotalUsd {
    return _orderItems
        .where((item) => !item.isVatExempt) // Filtrar solo productos no exentos
        .fold(0.0, (sum, item) => sum + item.subtotalUsd);
  }
  
  double get _taxableSubtotalVes {
    return _orderItems
        .where((item) => !item.isVatExempt) // Filtrar solo productos no exentos
        .fold(0.0, (sum, item) => sum + item.subtotalVes);
  }
  
  // Subtotal solo de productos exentos
  double get _exemptSubtotalUsd {
    return _orderItems
        .where((item) => item.isVatExempt) // Filtrar solo productos exentos
        .fold(0.0, (sum, item) => sum + item.subtotalUsd);
  }
  
  double get _exemptSubtotalVes {
    return _orderItems
        .where((item) => item.isVatExempt) // Filtrar solo productos exentos
        .fold(0.0, (sum, item) => sum + item.subtotalVes);
  }
  
  // Cálculo de impuestos sobre productos gravables
  double get _taxAmountUsd {
     return _isVatEnabled ? _taxableSubtotalUsd * _defaultTaxRate : 0.0;
  }
  
  double get _taxAmountVes {
     return _isVatEnabled ? _taxableSubtotalVes * _defaultTaxRate : 0.0;
  }
  
  // Total general (productos gravables + impuesto + productos exentos)
  double get _totalUsd {
     return _subtotalUsd + _taxAmountUsd;
  }
  
  double get _totalVes {
     return _subtotalVes + _taxAmountVes;
  }

  // --- Lógica de Guardado ---
  Future<void> _saveSale() async {
     // Validaciones básicas
     if (_orderItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añada al menos un producto a la venta.'), backgroundColor: Colors.orange));
        return;
     }
     
     // Validar stock disponible
     for (var item in _orderItems) {
       if (item.quantity > item.product.currentStock) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Stock insuficiente para ${item.product.name}. Disponible: ${item.product.currentStock}'),
             backgroundColor: Colors.orange
           )
         );
         return;
       }
     }
     
     // Validar que hay al menos un método de pago
     if (_paymentEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe agregar al menos un método de pago.'), backgroundColor: Colors.orange));
        return;
     }
     
     // Validar que el total de pagos coincida con el total de la venta
     final totalPayments = _paymentEntries.fold(0.0, (sum, entry) => sum + entry.amountUsd);
     if ((totalPayments - _totalUsd).abs() > 0.01) { // Permitir pequeña diferencia por redondeo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El total de pagos (\$${totalPayments.toStringAsFixed(2)}) no coincide con el total de la venta (\$${_totalUsd.toStringAsFixed(2)}).'),
            backgroundColor: Colors.orange
          )
        );
        return;
     }
     
      if (!(_formKey.currentState?.validate() ?? false)) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revise los campos marcados en rojo.'), backgroundColor: Colors.orange));
         return;
      }

      setState(() => _isSaving = true);
      
      // Construir detalles de pago
      String paymentDetailsText = "";
      if (_paymentEntries.length == 1) {
        // Si solo hay un método de pago, usar ese y añadir referencia general si existe
        final entry = _paymentEntries.first;
        paymentDetailsText = entry.toDetailString();
        if (_paymentDetailsController.text.isNotEmpty) {
          paymentDetailsText += " | ${_paymentDetailsController.text.trim()}";
        }
      } else {
        // Si hay múltiples métodos, listarlos todos
        paymentDetailsText = _paymentEntries.map((e) => e.toDetailString()).join(" | ");
        if (_paymentDetailsController.text.isNotEmpty) {
          paymentDetailsText += " | Nota: ${_paymentDetailsController.text.trim()}";
        }
      }

      final Sale saleHeader = Sale(
        // id se genera automáticamente
        invoiceNumber: _invoiceNumberController.text.trim(),
        clientId: _selectedClient?.id, // Puede ser null para Consumidor Final
        paymentMethodId: _paymentEntries.first.method.id!, // Guardamos el primer método como principal
        subtotal: _subtotalUsd, // Guardaremos en USD como base
        taxRate: _isVatEnabled ? _defaultTaxRate : 0.0, // Usar 0 si el impuesto está deshabilitado
        taxAmount: _taxAmountUsd,
        total: _totalUsd,
        exchangeRate: _currentExchangeRate,
        saleDate: _saleDate,
        paymentDetails: paymentDetailsText,
      );

      final List<SaleItem> saleItemsDetail = _orderItems.map((orderItem) => SaleItem(
          saleId: 0, // Se actualizará en la base de datos
          productId: orderItem.product.id!,
          quantity: orderItem.quantity,
          unitPriceUsd: orderItem.sellingPriceUsd,
          unitPriceVes: orderItem.sellingPriceVes,
          subtotalUsd: orderItem.subtotalUsd,
          subtotalVes: orderItem.subtotalVes,
       )).toList();

       try {
          // Usar una transacción para asegurar la atomicidad
          final int saleId = await _dbHelper.recordCompleteSale(
            sale: saleHeader,
            items: saleItemsDetail,
            paymentDetails: paymentDetailsText,
          );

          if (saleId <= 0) {
            throw Exception('Error al guardar la venta: ID inválido');
          }

          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Venta registrada con éxito.'), backgroundColor: Colors.green),
             );
             Navigator.of(context).pop(true); // Retornar true para indicar éxito
          }

       } catch (e) {
          print("Error guardando venta: $e");
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('Error al registrar la venta: ${e.toString()}'),
                 backgroundColor: Colors.red,
                 duration: const Duration(seconds: 5),
               ),
             );
          }
       } finally {
          if (mounted) {
            setState(() => _isSaving = false);
          }
       }
  }

   // --- Lógica para seleccionar Cliente ---
  Future<void> _showClientSearchDialog() async {
    if (_isLoadingClients && _clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cargando clientes...")));
      await _loadClients();
    }
    // No mostramos error si la carga falló, simplemente no habrá clientes

    final Client? selectedClientResult = await showDialog<Client>(
      context: context,
      builder: (BuildContext context) {
        return SearchableListDialog<Client?>(
           // Usamos Client? para permitir null (Consumidor Final)
           title: 'Seleccionar Cliente',
           // Añadir opción "Consumidor Final" al inicio de la lista de items
           items: [null, ..._clients], 
           itemBuilder: (client) {
             if (client == null) {
               return const ListTile(
                 leading: Icon(Icons.person_outline), 
                 title: Text('Consumidor Final'),
                 subtitle: Text('Venta sin cliente registrado'),
               );
             }
             return ListTile(
                leading: CircleAvatar(child: Text(client.name.substring(0, 1).toUpperCase())),
                title: Text(client.name),
                subtitle: Text(client.taxId), // Mostrar RIF/Cédula
                 trailing: _selectedClient?.id == client.id
                   ? const Icon(Icons.check_circle, color: Colors.green)
                   : null,
              );
           },
           filterFn: (client, query) {
             if (client == null) { // Siempre mostrar "Consumidor Final" si la búsqueda está vacía
                return query.isEmpty || 'consumidor final'.contains(query.toLowerCase());
             }
             return client.name.toLowerCase().contains(query.toLowerCase()) ||
                    client.taxId.toLowerCase().contains(query.toLowerCase());
           },
           onItemSelected: (client) {
              Navigator.of(context).pop(client);
           },
           // Añadir acción para crear nuevo cliente
           // (Esto requeriría adaptar SearchableListDialog o añadir un botón fuera)
           /*
           additionalActions: [
             TextButton.icon(
               icon: const Icon(Icons.add_circle_outline),
               label: const Text("Nuevo Cliente"),
               onPressed: () async {
                  Navigator.of(context).pop(); // Cerrar diálogo de búsqueda
                  final newClientId = await Navigator.push<int?>(
                       context, 
                       MaterialPageRoute(builder: (_) => const ClientFormPage())
                  );
                  if (newClientId != null) {
                      await _loadClients(); // Recargar clientes
                      final newClient = _clients.firstWhere((c) => c.id == newClientId, orElse: () => null);
                      if (newClient != null && mounted) {
                          setState(() => _selectedClient = newClient);
                      }
                  }
               },
             )
           ]
           */
        );
      },
    );

    // Actualizar estado solo si el resultado es diferente (o si se seleccionó "Consumidor Final")
    if (selectedClientResult != _selectedClient) {
       setState(() {
          _selectedClient = selectedClientResult;
       });
    }
 }

  // Método para añadir el producto inicial a la orden
  void _addInitialProduct() {
    // Buscar el producto en la lista completa para asegurar que tenemos los datos actualizados
    final productToAdd = _allProducts.firstWhere(
      (p) => p.id == widget.initialProduct!.id,
      orElse: () => widget.initialProduct!,
    );
    
    // Verificar stock
    if (productToAdd.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El producto seleccionado no tiene stock disponible.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Añadir el producto a la lista de items
    _addItem(
      productToAdd, 
      1, // Cantidad inicial 1
      productToAdd.sellingPriceUsd,
      productToAdd.sellingPriceVes
    );
    
    // Mostrar mensaje de confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Producto "${productToAdd.name}" añadido a la venta.'), backgroundColor: Colors.green),
    );
  }
  
  // Añadir item a la orden (esta función debe existir en tu código)
  void _addItem(Product product, int quantity, double priceUsd, double priceVes) {
    setState(() {
      _orderItems.add(SalesOrderItem(
        product: product,
        quantity: quantity,
        sellingPriceUsd: priceUsd,
        sellingPriceVes: priceVes,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar PaymentMethodProvider
    final paymentMethodProvider = context.watch<PaymentMethodProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Venta'),
        actions: [
          // Botón para guardar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving 
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Guardar Venta',
                  onPressed: _saveSale,
                ),
          )
        ],
      ),
      // Usar un Form para validaciones (ej: Nro Factura si se requiere)
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Sección Cliente ---
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cliente', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ListTile(
                         leading: const Icon(Icons.person_pin_circle_outlined, color: Colors.blueGrey),
                        title: Text(_selectedClient?.name ?? 'Consumidor Final'),
                        subtitle: Text(_selectedClient?.taxId ?? 'Venta sin cliente específico'),
                        trailing: const Icon(Icons.arrow_drop_down), 
                        onTap: _showClientSearchDialog,
                      ),
                      // Podríamos añadir aquí el botón para crear cliente nuevo si no se hace en el diálogo
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
                   child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Nº Factura/Control',
                              prefixIcon: Icon(Icons.receipt_long_outlined)
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Requerido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                         Expanded(
                          child: InputDecorator(
                             decoration: const InputDecoration(
                               labelText: 'Fecha Venta',
                               prefixIcon: Icon(Icons.calendar_today_outlined),
                               border: InputBorder.none, // Quitar borde para que parezca texto
                             ),
                             child: Text(_dateFormatter.format(_saleDate)),
                           ),
                        ),
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
                            onPressed: _showProductSearchDialog,
                           )
                        ],
                      ),
                      const Divider(),
                      if (_orderItems.isEmpty)
                        const Padding(
                           padding: EdgeInsets.symmetric(vertical: 24.0),
                           child: Center(child: Text('Añada productos a la venta.')),
                        )
                      else
                        // Usar ListView.builder para eficiencia si la lista puede ser larga
                        ListView.builder(
                          shrinkWrap: true, // Necesario dentro de SingleChildScrollView
                          physics: const NeverScrollableScrollPhysics(), // Deshabilitar scroll propio
                          itemCount: _orderItems.length,
                          itemBuilder: (context, index) {
                            final item = _orderItems[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Row(
                                children: [
                                  Expanded(child: Text(item.product.name)),
                                  if (item.isVatExempt) _buildExemptionIndicator(item),
                                ],
                              ),
                              subtitle: Text(
                                '${item.quantity} x ${_currencyFormatter.format(item.sellingPriceUsd)} = ${_currencyFormatter.format(item.subtotalUsd)} (${_currencyFormatterVes.format(item.subtotalVes)})'
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _removeItem(index),
                              ),
                              // Permitir editar cantidad tocando el item
                              onTap: () async {
                                // Calcular stock disponible considerando la cantidad actual
                                int availableStock = item.product.currentStock + item.quantity;
                                final int? newQuantity = await _showQuantityDialogStepped(context, item.product, availableStock);
                                if (newQuantity != null) {
                                    _addOrUpdateSalesItem(item.product, newQuantity);
                                }
                              },
                            );
                          },
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
                     crossAxisAlignment: CrossAxisAlignment.stretch, // Alinear texto a la derecha
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
                           Row(
                             children: [
                               Icon(
                                 _isVatEnabled ? Icons.check_circle : Icons.cancel,
                                 color: _isVatEnabled ? Colors.green : Colors.red,
                                 size: 18,
                               ),
                               const SizedBox(width: 4),
                               Text(
                                 _isVatEnabled 
                                   ? 'IVA ${(_defaultTaxRate * 100).toStringAsFixed(0)}% aplicado' 
                                   : 'IVA no aplicado',
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: _isVatEnabled ? Colors.green : Colors.red,
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ),
                       const Divider(),
                       
                       // Si hay productos exentos, mostrar el subtotal gravable y exento separados
                       if (_exemptSubtotalUsd > 0)
                         _buildTotalRow('Subtotal Gravable:', _taxableSubtotalUsd, _taxableSubtotalVes),
                       
                       if (_exemptSubtotalUsd > 0)
                         _buildTotalRow('Subtotal Exento:', _exemptSubtotalUsd, _exemptSubtotalVes),
                         
                       // Si no hay productos exentos, mostrar solo el subtotal normal
                       if (_exemptSubtotalUsd <= 0)
                         _buildTotalRow('Subtotal:', _subtotalUsd, _subtotalVes),
                         
                       if (_isVatEnabled) // Mostrar fila de impuestos solo si está habilitado
                         _buildTotalRow('Impuesto (${(_defaultTaxRate * 100).toStringAsFixed(0)}%):', _taxAmountUsd, _taxAmountVes),
                         
                       const Divider(),
                       _buildTotalRow('TOTAL:', _totalUsd, _totalVes, isTotal: true),
                    ],
                  ),
                ),
              ),

              // --- Sección Pago ---
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
                          Text('Métodos de Pago', style: Theme.of(context).textTheme.titleMedium),
                          paymentMethodProvider.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                tooltip: _isTotalCovered() 
                                  ? 'Monto total cubierto' 
                                  : 'Añadir método de pago',
                                onPressed: _isTotalCovered()
                                  ? null // Desactivar botón si el total está cubierto
                                  : () => _showAddPaymentDialog(paymentMethodProvider),
                                color: _isTotalCovered() ? Colors.grey : Colors.blue,
                              ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Lista de pagos registrados
                      if (_paymentEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text('Añada al menos un método de pago'),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _paymentEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _paymentEntries[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.payment),
                                title: Text(entry.method.name),
                                subtitle: entry.reference != null && entry.reference!.isNotEmpty
                                  ? Text('Ref: ${entry.reference}')
                                  : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _currencyFormatter.format(entry.amountUsd),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _currencyFormatterVes.format(entry.calculateAmountVes(_currentExchangeRate)),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _removePaymentEntry(index),
                                    ),
                                  ],
                                ),
                                onTap: () => _editPaymentEntry(index, paymentMethodProvider),
                              ),
                            );
                          },
                        ),
                        
                      // Resumen de pagos
                      if (_paymentEntries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total pagado:'),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currencyFormatter.format(_paymentEntries.fold(0.0, (sum, entry) => sum + entry.amountUsd)),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _currencyFormatterVes.format(_paymentEntries.fold(0.0, (sum, entry) => sum + entry.calculateAmountVes(_currentExchangeRate))),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                      const SizedBox(height: 16),
                      // Campo para Detalles de Pago adicionales (notas generales)
                      TextFormField(
                         controller: _paymentDetailsController,
                         decoration: const InputDecoration(
                           labelText: 'Notas adicionales (Opcional)',
                           hintText: 'Ej: Cliente habitual, Se enviará pedido mañana, etc.',
                           prefixIcon: Icon(Icons.note_outlined),
                         ),
                         // Sin validador, es opcional
                      ),
                    ],
                  ),
                ),
              ),

              // --- Botón Guardar (si no está en AppBar) ---
               if (!_isSaving) // Ocultar si ya se está guardando
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 20.0),
                   child: ElevatedButton.icon(
                      icon: const Icon(Icons.save), 
                      label: const Text('Completar Venta'),
                      style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15),
                         textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      onPressed: _saveSale,
                   ),
                 )
               else
                 const Center(child: Padding(
                   padding: EdgeInsets.symmetric(vertical: 20.0),
                   child: CircularProgressIndicator(),
                 )),

            ],
          ),
        ),
      ),
    );
  }

  // Helper para filas de totales
  Widget _buildTotalRow(String label, double amountUsd, double amountVes, {bool isTotal = false}) {
     final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
       fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
       color: isTotal ? Theme.of(context).colorScheme.primary : null,
     );
     final vesStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
       fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
       color: isTotal ? Theme.of(context).colorScheme.secondary : Colors.grey[600],
     );

     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(label, style: style),
           Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_currencyFormatter.format(amountUsd), style: style),
              Text(_currencyFormatterVes.format(amountVes), style: vesStyle),
            ],
           )
           
         ],
       ),
     );
  }

  // Helper para indicar si un producto es exento en la lista
  Widget _buildExemptionIndicator(SalesOrderItem item) {
    if (!item.isVatExempt) return const SizedBox.shrink(); // No mostrar nada si no es exento
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: const Text(
        'Exento de IVA',
        style: TextStyle(
          fontSize: 10,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- Manejo de Pagos Múltiples ---
  
  // Verificar si el monto total ya está cubierto por los pagos actuales
  bool _isTotalCovered() {
    if (_orderItems.isEmpty) return false; // Si no hay items, no hay total que cubrir
    
    final totalPaid = _paymentEntries.fold(0.0, (sum, entry) => sum + entry.amountUsd);
    
    // Permitir una pequeña diferencia por redondeo (0.01)
    return (totalPaid - _totalUsd).abs() < 0.01;
  }
  
  // Mostrar diálogo para añadir un método de pago
  Future<void> _showAddPaymentDialog(PaymentMethodProvider provider) async {
    // Verificar si el total ya está cubierto
    if (_isTotalCovered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto total de la venta ya está cubierto'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    
    if (provider.paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay métodos de pago disponibles'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    // Variables para diálogo
    PaymentMethod? selectedMethod = provider.paymentMethods.first;
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    
    // Función para detectar si el método es en USD o Bs
    bool isUsdMethod(PaymentMethod method) {
      final name = method.name.toLowerCase();
      return name.contains('usd') || name.contains('dólar') || name.contains('dolar');
    }
    
    // Función para obtener el monto sugerido en la moneda correcta
    String getSuggestedAmount(PaymentMethod method) {
      final totalPaid = _paymentEntries.fold(0.0, (sum, entry) => sum + entry.amountUsd);
      final remaining = _totalUsd - totalPaid;
      final suggestedAmount = remaining > 0 ? remaining : _totalUsd;
      
      if (isUsdMethod(method)) {
        return suggestedAmount.toStringAsFixed(2);
      } else {
        // Convertir a Bs
        return (suggestedAmount * _currentExchangeRate).toStringAsFixed(2);
      }
    }
    
    // Inicializar el monto sugerido
    amountController.text = getSuggestedAmount(selectedMethod);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Añadir Método de Pago'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Método de pago
                  DropdownButtonFormField<PaymentMethod>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Forma de Pago',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: provider.paymentMethods.map((method) {
                      return DropdownMenuItem<PaymentMethod>(
                        value: method,
                        child: Text(method.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMethod = value;
                          // Actualizar el monto sugerido cuando cambie el método
                          amountController.text = getSuggestedAmount(value);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de monto (se adapta según la moneda)
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: isUsdMethod(selectedMethod!) 
                        ? 'Monto en USD' 
                        : 'Monto en Bs.',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        isUsdMethod(selectedMethod!) 
                          ? Icons.attach_money 
                          : Icons.currency_exchange,
                      ),
                      helperText: isUsdMethod(selectedMethod!)
                        ? 'Total de la venta: ${_currencyFormatter.format(_totalUsd)}'
                        : 'Total de la venta: ${_currencyFormatterVes.format(_totalVes)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      // Validar que el monto no exceda el total disponible
                      final amount = double.tryParse(value);
                      if (amount != null && selectedMethod != null) {
                        final totalPaid = _paymentEntries.fold(0.0, (sum, entry) => sum + entry.amountUsd);
                        final remaining = _totalUsd - totalPaid;
                        
                        if (isUsdMethod(selectedMethod!)) {
                          if (amount > remaining) {
                            // Mostrar advertencia pero no bloquear
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Monto excede el total pendiente: ${_currencyFormatter.format(remaining)}'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          // Convertir Bs a USD para validar
                          final amountUsd = amount / _currentExchangeRate;
                          if (amountUsd > remaining) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Monto excede el total pendiente: ${_currencyFormatterVes.format(remaining * _currentExchangeRate)}'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de referencia
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt_long),
                      hintText: 'Ej: Número transferencia, Banco, etc.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validar monto
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingrese un monto válido'), 
                        backgroundColor: Colors.orange
                      )
                    );
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('Añadir'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result == true && selectedMethod != null) {
      final amount = double.tryParse(amountController.text) ?? 0.0;
      
      // Convertir el monto a USD si es necesario
      double amountUsd;
      if (isUsdMethod(selectedMethod!)) {
        amountUsd = amount;
      } else {
        // Convertir de Bs a USD
        amountUsd = amount / _currentExchangeRate;
      }
      
      setState(() {
        _paymentEntries.add(PaymentEntry(
          method: selectedMethod!,
          amountUsd: amountUsd,
          reference: referenceController.text.isNotEmpty ? referenceController.text : null,
        ));
      });
    }
  }
  
  // Editar un pago existente
  Future<void> _editPaymentEntry(int index, PaymentMethodProvider provider) async {
    final entry = _paymentEntries[index];
    PaymentMethod? selectedMethod = entry.method;
    final amountController = TextEditingController();
    final referenceController = TextEditingController(
      text: entry.reference ?? ''
    );
    
    // Función para detectar si el método es en USD o Bs
    bool isUsdMethod(PaymentMethod method) {
      final name = method.name.toLowerCase();
      return name.contains('usd') || name.contains('dólar') || name.contains('dolar');
    }
    
    // Función para obtener el monto en la moneda correcta para mostrar
    String getAmountForDisplay(PaymentMethod method, double amountUsd) {
      if (isUsdMethod(method)) {
        return amountUsd.toStringAsFixed(2);
      } else {
        // Convertir USD a Bs para mostrar
        return (amountUsd * _currentExchangeRate).toStringAsFixed(2);
      }
    }
    
    // Inicializar el monto en la moneda correcta
    amountController.text = getAmountForDisplay(selectedMethod, entry.amountUsd);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Editar Método de Pago'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Método de pago
                  DropdownButtonFormField<PaymentMethod>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Forma de Pago',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payment),
                    ),
                    items: provider.paymentMethods.map((method) {
                      return DropdownMenuItem<PaymentMethod>(
                        value: method,
                        child: Text(method.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMethod = value;
                          // Actualizar el monto cuando cambie el método
                          amountController.text = getAmountForDisplay(value, entry.amountUsd);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de monto (se adapta según la moneda)
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: isUsdMethod(selectedMethod!) 
                        ? 'Monto en USD' 
                        : 'Monto en Bs.',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        isUsdMethod(selectedMethod!) 
                          ? Icons.attach_money 
                          : Icons.currency_exchange,
                      ),
                      helperText: isUsdMethod(selectedMethod!)
                        ? 'Total de la venta: ${_currencyFormatter.format(_totalUsd)}'
                        : 'Total de la venta: ${_currencyFormatterVes.format(_totalVes)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de referencia
                  TextFormField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt_long),
                      hintText: 'Ej: Número transferencia, Banco, etc.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validar monto
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingrese un monto válido'), 
                        backgroundColor: Colors.orange
                      )
                    );
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result == true && selectedMethod != null) {
      final amount = double.tryParse(amountController.text) ?? 0.0;
      
      // Convertir el monto a USD si es necesario
      double amountUsd;
      if (isUsdMethod(selectedMethod!)) {
        amountUsd = amount;
      } else {
        // Convertir de Bs a USD
        amountUsd = amount / _currentExchangeRate;
      }
      
      setState(() {
        _paymentEntries[index] = PaymentEntry(
          method: selectedMethod!,
          amountUsd: amountUsd,
          reference: referenceController.text.isNotEmpty ? referenceController.text : null,
        );
      });
    }
  }
  
  // Eliminar un método de pago
  void _removePaymentEntry(int index) {
    setState(() {
      _paymentEntries.removeAt(index);
    });
  }
} 