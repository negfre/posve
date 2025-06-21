import 'package:flutter/material.dart';
import '../../services/database_helper.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../models/client.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Variables de estado para el onboarding
  final Set<String> _selectedPaymentMethods = {};
  double? _exchangeRate;
  bool _vatEnabled = true;
  final int _testProductCount = 0;

  // Formas de pago
  final Map<String, bool> _paymentMethods = {
    'Efectivo en Bs': false,
    'Efectivo en USD': false,
    'Pago Móvil Banco Venezuela': false,
    'Transferencia Banco Venezuela': false,
  };

  // Controladores para IVA y tasa de cambio
  final _ivaController = TextEditingController(text: '16');
  final _exchangeRateController = TextEditingController();
  
  // Cambiar a usar un simple booleano en lugar de un número
  bool _shouldCreateTestProducts = true;

  @override
  void initState() {
    super.initState();
    
    // Añadir listener para validación en tiempo real de la tasa de cambio
    _exchangeRateController.addListener(() {
      setState(() {}); // Actualizar UI para validación
    });
  }

  @override
  void dispose() {
    _ivaController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Configurando tu aplicación...'),
            ],
          ),
        );
      },
    );

    try {
      print("Iniciando proceso de finalización de onboarding...");
      
      // Convertir _paymentMethods a _selectedPaymentMethods
      _selectedPaymentMethods.clear();
      _paymentMethods.forEach((key, value) {
        if (value) {
          _selectedPaymentMethods.add(key);
        }
      });
      
      if (_selectedPaymentMethods.isEmpty) {
        Navigator.of(context).pop(); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor seleccione al menos una forma de pago'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_exchangeRateController.text.isEmpty) {
        Navigator.of(context).pop(); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingrese una tasa de cambio válida'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _exchangeRate = double.tryParse(_exchangeRateController.text.replaceAll(',', '.'));
      if (_exchangeRate == null || _exchangeRate! <= 0) {
        Navigator.of(context).pop(); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingrese una tasa de cambio válida'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Guardar formas de pago seleccionadas
      print("Guardando formas de pago seleccionadas: $_selectedPaymentMethods");
      for (String method in _selectedPaymentMethods) {
        print("Agregando forma de pago: $method");
        await _dbHelper.addPaymentMethod(method);
      }

      // Configurar IVA
      print("Configurando IVA...");
      await _dbHelper.setVatEnabled(_vatEnabled);
      await _dbHelper.setVatPercentage(_vatEnabled ? double.tryParse(_ivaController.text) ?? 16.0 : 0.0);

      // Guardar tasa de cambio
      print("Guardando tasa de cambio: $_exchangeRate");
      await _dbHelper.setExchangeRate(_exchangeRate!);

      // Crear productos de prueba si se seleccionaron
      if (_shouldCreateTestProducts) {
        print("Creando productos de prueba...");
        await _createTestProducts();
      }

      print("Marcando onboarding como completado...");
      await _dbHelper.setOnboardingCompleted(true);

      if (!mounted) return;
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('¡Configuración completada exitosamente!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      print("Navegando a la pantalla principal...");
      Navigator.of(context).pushReplacementNamed('/home');
      
    } catch (e) {
      print("Error durante el proceso de onboarding: $e");
      if (!mounted) return;
      
      // Cerrar diálogo de carga
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error al finalizar la configuración: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _createTestProducts() async {
    try {
      final dbHelper = DatabaseHelper();
      final categories = ['Bebidas', 'Snacks', 'Dulces', 'Enlatados', 'Lácteos'];
      final List<int> categoryIds = [];

      // Verificar o crear categorías
      for (String categoryName in categories) {
        int categoryId = await dbHelper.getCategoryId(categoryName);
        if (categoryId == -1) {
          categoryId = await dbHelper.insertCategoryByName(categoryName);
        }
        categoryIds.add(categoryId);
      }

      // Crear dos proveedores de prueba
      final providerNames = ['Distribuidora Nacional', 'Importadora Global'];
      final providerIds = <int>[];

      for (int i = 0; i < providerNames.length; i++) {
        int providerId = await dbHelper.getProviderId(providerNames[i]);
        if (providerId == -1) {
          final provider = Supplier(
            id: 0,
            name: providerNames[i],
            taxId: 'J-12345${i+1}78-9',
            phone: '0424123456${i+1}',
            email: 'proveedor${i+1}@example.com',
            address: 'Dirección del proveedor ${i+1}',
            observations: 'Proveedor de prueba ${i+1}',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          providerId = await dbHelper.insertSupplier(provider);
        }
        providerIds.add(providerId);
      }

      // Crear productos de prueba
      final productData = [
        // Nombre, descripción, categoría, proveedor, precio costo, precio venta
        ['Coca Cola 2Lt', 'Refresco de cola', 0, 0, 0.80, 1.50],
        ['Pepsi 2Lt', 'Refresco de cola', 0, 1, 0.75, 1.40],
        ['Doritos Nacho', 'Snack de maíz', 1, 0, 0.75, 1.50],
        ['Cheetos', 'Snack de queso', 1, 1, 0.70, 1.40],
        ['Chocolate Savoy', 'Chocolate con leche', 2, 0, 0.60, 1.20],
        ['Caramelos Surtidos', 'Caramelos variados', 2, 1, 0.30, 0.60],
        ['Atún enlatado', 'Atún en aceite', 3, 0, 1.20, 2.40],
        ['Sardinas', 'Sardinas en salsa de tomate', 3, 1, 0.90, 1.80],
        ['Leche en polvo', 'Leche completa', 4, 0, 2.00, 3.50],
        ['Queso blanco', 'Queso fresco', 4, 1, 2.50, 4.00],
      ];

      final exchangeRate = await dbHelper.getExchangeRate();
      
      final products = <Product>[];
      int skuCounter = 1;

      for (var data in productData) {
        final sku = 'SKU${skuCounter.toString().padLeft(3, '0')}';
        skuCounter++;

        final product = Product(
          id: 0,
          name: data[0] as String,
          description: data[1] as String,
          barcode: '759${(10000 + skuCounter).toString()}',
          sku: sku,
          categoryId: categoryIds[data[2] as int],
          supplierId: providerIds[data[3] as int],
          costPriceUsd: data[4] as double,
          purchasePriceUsd: data[4] as double,
          profitMargin: 1.0,
          sellingPriceUsd: data[5] as double,
          sellingPriceVes: (data[5] as double) * exchangeRate,
          currentStock: 10, // Stock inicial de 10 unidades
          stock: 10,
          minStock: 3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Guardar el producto e obtener el ID
        final productId = await dbHelper.insertProduct(product);
        
        // Crear un nuevo objeto con el ID asignado
        final savedProduct = Product(
          id: productId,
          name: product.name,
          description: product.description,
          barcode: product.barcode,
          sku: product.sku,
          categoryId: product.categoryId,
          supplierId: product.supplierId,
          costPriceUsd: product.costPriceUsd,
          purchasePriceUsd: product.purchasePriceUsd,
          profitMargin: product.profitMargin,
          sellingPriceUsd: product.sellingPriceUsd,
          sellingPriceVes: product.sellingPriceVes,
          currentStock: product.currentStock,
          stock: product.stock,
          minStock: product.minStock,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        );
        
        products.add(savedProduct);
      }

      print('${products.length} productos de prueba creados exitosamente');
      
      // Crear ventas de prueba
      if (_testProductCount > 0) {
        await _createDemoSales(products);
      }
      
    } catch (e) {
      print('Error al crear productos de prueba: $e');
      rethrow; // Re-lanzar para que se capture en _finishOnboarding
    }
  }

  Future<void> _createDemoSales(List<Product> products) async {
    try {
      final dbHelper = DatabaseHelper();
      
      // Verificar si hay métodos de pago disponibles
      final paymentMethods = await dbHelper.getPaymentMethods();
      if (paymentMethods.isEmpty) {
        print('No hay métodos de pago para crear ventas de prueba');
        return;
      }
      
      // Verificar si hay clientes, o crear uno
      final clients = await dbHelper.getClients();
      int? clientId;
      
      if (clients.isEmpty) {
        // Crear cliente de prueba
        final client = Client(
          id: 0,
          name: 'Cliente Frecuente',
          taxId: 'V-12345678',
          phone: '04141234567',
          email: 'cliente@example.com',
          address: 'Dirección del cliente',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        clientId = await dbHelper.insertClient(client);
        
        // Crear 2 clientes adicionales
        final cliente2 = Client(
          id: 0,
          name: 'Empresa XYZ',
          taxId: 'J-87654321',
          phone: '02125678901',
          email: 'contacto@xyz.com',
          address: 'Av. Principal, Edificio XYZ',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await dbHelper.insertClient(cliente2);
        
        final cliente3 = Client(
          id: 0,
          name: 'María González',
          taxId: 'V-98765432',
          phone: '04249876543',
          email: 'maria@gmail.com',
          address: 'Calle 5, Casa 10',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await dbHelper.insertClient(cliente3);
      } else {
        clientId = clients.first.id;
      }
      
      // Obtener todos los clientes después de asegurarnos que existen
      final allClients = await dbHelper.getClients();
      
      // Obtener tasa de cambio actual
      final exchangeRate = await dbHelper.getExchangeRate();
      final taxRate = await dbHelper.getDefaultTaxRate();
      
      // Fecha actual
      final now = DateTime.now();
      
      // Crear aproximadamente 30 ventas: 15 en el mes actual y 15 en el mes pasado
      print('Creando 30 ventas de prueba (históricas)...');
      
      // Crear ventas del mes pasado
      final lastMonth = DateTime(now.year, now.month-1, 1);
      final daysInLastMonth = DateTime(now.year, now.month, 0).day;
      
      for (int i = 0; i < 15; i++) {
        // Distribuir las ventas a lo largo del mes pasado
        final day = 1 + (i * daysInLastMonth ~/ 15);
        final saleDate = DateTime(lastMonth.year, lastMonth.month, day);
        
        // Seleccionar cliente aleatorio, a veces null (consumidor final)
        final randomClientIndex = i % 3;
        final saleClientId = randomClientIndex == 0 ? null : allClients[randomClientIndex % allClients.length].id;
        
        // Seleccionar método de pago aleatorio
        final paymentMethodId = paymentMethods[i % paymentMethods.length].id!;
        
        await _createSingleDemoSale(
          products: products, 
          saleDate: saleDate, 
          exchangeRate: exchangeRate, 
          taxRate: taxRate, 
          clientId: saleClientId, 
          paymentMethodId: paymentMethodId,
          index: i
        );
      }
      
      // Crear ventas del mes actual
      final currentMonth = DateTime(now.year, now.month, 1);
      final daysInCurrentMonth = now.day; // Solo hasta el día actual
      
      for (int i = 0; i < 15; i++) {
        // Distribuir las ventas hasta el día actual
        final day = 1 + (i * daysInCurrentMonth ~/ 15);
        final saleDate = DateTime(currentMonth.year, currentMonth.month, day);
        
        // Seleccionar cliente aleatorio, a veces null (consumidor final)
        final randomClientIndex = i % 4;
        final saleClientId = randomClientIndex == 0 ? null : allClients[randomClientIndex % allClients.length].id;
        
        // Seleccionar método de pago aleatorio
        final paymentMethodId = paymentMethods[i % paymentMethods.length].id!;
        
        await _createSingleDemoSale(
          products: products, 
          saleDate: saleDate, 
          exchangeRate: exchangeRate, 
          taxRate: taxRate, 
          clientId: saleClientId, 
          paymentMethodId: paymentMethodId,
          index: i + 15
        );
      }
      
      print('30 ventas de prueba creadas exitosamente');
    } catch (e) {
      print('Error al crear ventas de prueba: $e');
      // No lanzar excepción para no interrumpir el onboarding
    }
  }
  
  // Método auxiliar para crear una venta individual de prueba
  Future<void> _createSingleDemoSale({
    required List<Product> products,
    required DateTime saleDate,
    required double exchangeRate,
    required double taxRate,
    required int? clientId,
    required int paymentMethodId,
    required int index
  }) async {
    final dbHelper = DatabaseHelper();
    
    // Generar un número aleatorio de productos (entre 1 y 4)
    final itemCount = 1 + (index % 4);
    double subtotal = 0;
    
    final saleItems = <SaleItem>[];
    
    // Crear items de venta
    for (int j = 0; j < itemCount; j++) {
      final productIndex = (index + j) % products.length;
      final product = products[productIndex];
      final quantity = 1 + (j % 3); // 1, 2, 3 unidades
      
      final unitPriceUsd = product.sellingPriceUsd;
      final unitPriceVes = product.sellingPriceVes;
      final subtotalUsd = unitPriceUsd * quantity;
      final subtotalVes = unitPriceVes * quantity;
      
      subtotal += subtotalUsd;
      
      saleItems.add(SaleItem(
        saleId: 0, // Se actualizará después
        productId: product.id!,
        quantity: quantity,
        unitPriceUsd: unitPriceUsd,
        unitPriceVes: unitPriceVes,
        subtotalUsd: subtotalUsd,
        subtotalVes: subtotalVes,
      ));
    }
    
    // Calcular impuesto y total
    final taxAmount = subtotal * taxRate;
    final total = subtotal + taxAmount;
    
    // Crear encabezado de venta
    final sale = Sale(
      invoiceNumber: 'V-${1000 + index}',
      clientId: clientId,
      paymentMethodId: paymentMethodId,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
      exchangeRate: exchangeRate,
      saleDate: saleDate,
      paymentDetails: 'Venta de prueba ${index + 1}',
    );
    
    // Registrar la venta completa
    try {
      await dbHelper.recordCompleteSale(
        sale: sale,
        items: saleItems,
        paymentDetails: 'Venta de prueba ${index + 1}',
      );
      
      print('Venta de prueba ${index + 1} creada para la fecha ${saleDate.toString()}');
    } catch (e) {
      print('Error al registrar venta ${index + 1}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Configuración Inicial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header con progreso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Indicador de progreso
                Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: index <= _currentStep 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  'Paso ${_currentStep + 1} de 4',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStepTitle(_currentStep),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(_currentStep),
            ),
          ),
          
          // Botones de navegación
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentStep--);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Anterior',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canContinueToNextStep() ? () {
                      if (_currentStep < 3) {
                        setState(() => _currentStep++);
                      } else {
                        _finishOnboarding();
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentStep < 3 ? 'Siguiente' : 'Finalizar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Formas de Pago';
      case 1:
        return 'Productos de Prueba';
      case 2:
        return 'Configuración de IVA';
      case 3:
        return 'Tasa de Cambio';
      default:
        return '';
    }
  }

  bool _canContinueToNextStep() {
    switch (_currentStep) {
      case 0:
        return _paymentMethods.values.any((value) => value);
      case 1:
        return true; // Siempre se puede continuar
      case 2:
        return true; // Siempre se puede continuar
      case 3:
        final rateText = _exchangeRateController.text.trim();
        if (rateText.isEmpty) return false;
        final rate = double.tryParse(rateText.replaceAll(',', '.'));
        return rate != null && rate > 0;
      default:
        return false;
    }
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildPaymentMethodsStep();
      case 1:
        return _buildTestProductsStep();
      case 2:
        return _buildVatStep();
      case 3:
        return _buildExchangeRateStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPaymentMethodsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.payment,
          title: 'Formas de Pago',
          subtitle: 'Selecciona las formas de pago que deseas habilitar en tu negocio',
        ),
        const SizedBox(height: 24),
        ..._paymentMethods.entries.map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: entry.value ? Theme.of(context).primaryColor : Colors.grey.shade300,
              width: entry.value ? 2 : 1,
            ),
          ),
          child: CheckboxListTile(
            title: Text(
              entry.key,
              style: TextStyle(
                fontWeight: entry.value ? FontWeight.bold : FontWeight.normal,
                color: entry.value ? Theme.of(context).primaryColor : Colors.black87,
              ),
            ),
            value: entry.value,
            onChanged: (bool? value) {
              setState(() => _paymentMethods[entry.key] = value ?? false);
            },
            activeColor: Theme.of(context).primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        )),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Podrás agregar más formas de pago después desde la configuración.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestProductsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.inventory,
          title: 'Productos de Prueba',
          subtitle: '¿Deseas crear productos de ejemplo para comenzar?',
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SwitchListTile(
            title: const Text(
              'Crear productos de ejemplo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Se crearán 10 productos de diferentes categorías con 10 unidades de stock cada uno',
            ),
            value: _shouldCreateTestProducts,
            onChanged: (value) {
              setState(() => _shouldCreateTestProducts = value);
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        ),
        if (_shouldCreateTestProducts) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Productos que se crearán:',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• 10 productos de diferentes categorías'),
                const Text('• Stock inicial de 10 unidades cada uno'),
                const Text('• Categorías: Bebidas, Snacks, Dulces, Enlatados, Lácteos'),
                const Text('• 2 proveedores de ejemplo'),
                const Text('• 30 ventas de prueba (históricas)'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVatStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.receipt,
          title: 'Configuración de IVA',
          subtitle: 'Configura el impuesto al valor agregado para tus productos',
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SwitchListTile(
            title: const Text(
              '¿Usar IVA?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Habilitar el cálculo automático de IVA en las ventas'),
            value: _vatEnabled,
            onChanged: (value) {
              setState(() => _vatEnabled = value);
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        ),
        if (_vatEnabled) ...[
          const SizedBox(height: 20),
          TextFormField(
            controller: _ivaController,
            decoration: const InputDecoration(
              labelText: 'Porcentaje de IVA',
              suffixText: '%',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.percent),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Podrás cambiar esta configuración después desde la configuración de impuestos.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRateStep() {
    final rateText = _exchangeRateController.text.trim();
    final isValidRate = rateText.isNotEmpty && 
                       double.tryParse(rateText.replaceAll(',', '.')) != null &&
                       double.tryParse(rateText.replaceAll(',', '.'))! > 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          icon: Icons.currency_exchange,
          title: 'Tasa de Cambio',
          subtitle: 'Configura la tasa de cambio inicial USD a Bolívares',
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _exchangeRateController,
          decoration: InputDecoration(
            labelText: 'Tasa USD → VES',
            hintText: 'Ej: 35.50',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
            suffixText: 'Bs.',
            suffixIcon: rateText.isNotEmpty 
              ? Icon(
                  isValidRate ? Icons.check_circle : Icons.error,
                  color: isValidRate ? Colors.green : Colors.red,
                )
              : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
          ],
        ),
        if (rateText.isNotEmpty && !isValidRate) ...[
          const SizedBox(height: 8),
          Text(
            'Por favor ingresa una tasa de cambio válida mayor a 0',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.update, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Podrás actualizar la tasa de cambio en cualquier momento desde la configuración.',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 32,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
} 