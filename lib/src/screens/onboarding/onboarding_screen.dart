import 'package:flutter/material.dart';
import 'package:posve/src/screens/settings/terms_of_service_page.dart';
import '../../services/database_helper.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _termsAccepted = false;
  
  // Variables de configuración (añadidas)
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Set<String> _selectedPaymentMethods = {};
  double? _exchangeRate;
  bool _vatEnabled = true;
  bool _shouldCreateTestProducts = true;
  
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> onboardingPages = [
      _buildPage(
        icon: Icons.store,
        title: 'Bienvenido a POSVE',
        description: 'La solución completa para gestionar tu punto de venta. Controla tu inventario, ventas, clientes y más, todo en un solo lugar.',
      ),
      _buildPage(
        icon: Icons.inventory_2,
        title: 'Gestión de Inventario Fácil',
        description: 'Añade productos, gestiona el stock y recibe alertas cuando tus productos estén por agotarse. Nunca pierdas una venta por falta de inventario.',
      ),
      _buildPage(
        icon: Icons.point_of_sale,
        title: 'Proceso de Venta Rápido',
        description: 'Realiza ventas de forma rápida y eficiente. Registra múltiples métodos de pago y genera recibos para tus clientes al instante.',
      ),
      _buildTermsPage(), // Página de términos y condiciones
      _buildPaymentMethodsPage(), // Nueva página: Configuración de formas de pago
      _buildTaxAndExchangePage(), // Nueva página: Configuración de IVA y tasa de cambio
      _buildTestProductsPage(), // Nueva página: Opción de productos de prueba
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: onboardingPages,
              ),
            ),
            _buildControls(onboardingPages.length),
          ],
                        ),
                      ),
                    );
  }

  Widget _buildPage({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTermsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
          Text('Acuerdo de Servicio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SingleChildScrollView(
                child: Text(
                  // Resumen del acuerdo
                  'Antes de continuar, es importante que entiendas que POSVE es una herramienta para control interno y no es un sistema de facturación homologado por el SENIAT. El uso de esta app para fines fiscales es tu responsabilidad. Te recomendamos leer el acuerdo completo.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
            child: Text(
              'Leer Acuerdo de Servicio Completo',
              style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 16),
          Row(
      children: [
              Checkbox(
                value: _termsAccepted,
            onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
              ),
              const Expanded(child: Text('He leído y acepto el Acuerdo de Servicio.')),
            ],
          ),
        ],
      ),
    );
  }

  // Nueva página: Configuración de formas de pago
  Widget _buildPaymentMethodsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(
            'Formas de Pago',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecciona las formas de pago que aceptarás en tu negocio:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: _paymentMethods.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (bool? value) {
                    setState(() {
                      _paymentMethods[entry.key] = value ?? false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Nueva página: Configuración de IVA y tasa de cambio
  Widget _buildTaxAndExchangePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(
            'Configuración Fiscal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Tasa de cambio
                  TextFormField(
                    controller: _exchangeRateController,
                    decoration: const InputDecoration(
                      labelText: 'Tasa de Cambio USD/VES',
                      hintText: 'Ej: 35.50',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese la tasa de cambio';
                      }
                      final rate = double.tryParse(value.replaceAll(',', '.'));
                      if (rate == null || rate <= 0) {
                        return 'Ingrese una tasa válida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Configuración de IVA
                  SwitchListTile(
                    title: const Text('Habilitar IVA'),
                    subtitle: const Text('Aplicar impuesto al valor agregado'),
                    value: _vatEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _vatEnabled = value;
                      });
                    },
                  ),
                  
                  if (_vatEnabled) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ivaController,
                      decoration: const InputDecoration(
                        labelText: 'Porcentaje de IVA',
                        hintText: 'Ej: 16',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el porcentaje de IVA';
                        }
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0 || rate > 100) {
                          return 'Ingrese un porcentaje válido (0-100)';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nueva página: Opción de productos de prueba
  Widget _buildTestProductsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(
            'Productos de Prueba',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Deseas crear productos de ejemplo para probar la aplicación?',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SwitchListTile(
                  title: const Text('Crear productos de prueba'),
                  subtitle: const Text('Se crearán 10 productos de ejemplo con diferentes categorías'),
                  value: _shouldCreateTestProducts,
                  onChanged: (bool value) {
                    setState(() {
                      _shouldCreateTestProducts = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_shouldCreateTestProducts) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          'Se crearán productos como: Coca Cola, Doritos, Chocolate, etc.',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(int pageCount) {
    bool isLastPage = _currentPage == pageCount - 1;
    bool canProceed = _canProceedToNextPage();
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          Row(
            children: List.generate(pageCount, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              );
            }),
          ),
          ElevatedButton(
            onPressed: canProceed ? () {
              if (isLastPage) {
                _finishOnboarding();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? Theme.of(context).primaryColor : Colors.grey,
            ),
            child: Text(isLastPage ? 'Finalizar Configuración' : 'Siguiente'),
          ),
        ],
      ),
    );
  }

  // Validar si puede proceder a la siguiente página
  bool _canProceedToNextPage() {
    switch (_currentPage) {
      case 3: // Página de términos
        return _termsAccepted;
      case 4: // Página de formas de pago
        return _paymentMethods.values.any((value) => value);
      case 5: // Página de configuración fiscal
        return _exchangeRateController.text.isNotEmpty && 
               double.tryParse(_exchangeRateController.text.replaceAll(',', '.')) != null;
      default:
        return true;
    }
  }

  void _finishOnboarding() async {
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
      _exchangeRate = double.tryParse(_exchangeRateController.text.replaceAll(',', '.'));
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
      
      print("Navegando a registro...");
      Navigator.pushReplacementNamed(context, '/register');
      
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
        // Nombre, descripción, categoría, proveedor, precio costo, precio venta, margen
        ['Coca Cola 2Lt', 'Refresco de cola', 0, 0, 0.80, 1.50, 0.875],
        ['Pepsi 2Lt', 'Refresco de cola', 0, 1, 0.75, 1.40, 0.867],
        ['Doritos Nacho', 'Snack de maíz', 1, 0, 0.75, 1.50, 1.0],
        ['Cheetos', 'Snack de queso', 1, 1, 0.70, 1.40, 1.0],
        ['Chocolate Savoy', 'Chocolate con leche', 2, 0, 0.60, 1.20, 1.0],
        ['Caramelos Surtidos', 'Caramelos variados', 2, 1, 0.30, 0.60, 1.0],
        ['Atún enlatado', 'Atún en aceite', 3, 0, 1.20, 2.40, 1.0],
        ['Sardinas', 'Sardinas en salsa de tomate', 3, 1, 0.90, 1.80, 1.0],
        ['Leche en polvo', 'Leche completa', 4, 0, 2.00, 3.50, 0.75],
        ['Queso blanco', 'Queso fresco', 4, 1, 2.50, 4.00, 0.6],
      ];

      final exchangeRate = await dbHelper.getExchangeRate();
      
      final products = <Product>[];
      int skuCounter = 1;
      
      for (var data in productData) {
        final product = Product(
          id: 0,
          name: data[0] as String,
          description: data[1] as String,
          sku: 'SKU${skuCounter.toString().padLeft(3, '0')}',
          categoryId: categoryIds[data[2] as int],
          supplierId: providerIds[data[3] as int],
          costPriceUsd: (data[4] as num).toDouble(),
          purchasePriceUsd: (data[4] as num).toDouble(),
          profitMargin: (data[6] as num).toDouble(),
          sellingPriceUsd: (data[5] as num).toDouble(),
          sellingPriceVes: (data[5] as num).toDouble() * exchangeRate,
          currentStock: 50,
          minStock: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        products.add(product);
        skuCounter++;
      }

      for (Product product in products) {
        await dbHelper.insertProduct(product);
      }

      print("Productos de prueba creados exitosamente");
    } catch (e) {
      print("Error creando productos de prueba: $e");
      rethrow;
    }
  }
} 