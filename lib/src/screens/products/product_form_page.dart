import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import '../../models/product.dart';
import '../../models/supplier.dart'; // Importar Supplier
import '../../models/category.dart'; // Importar Category
import '../../services/database_helper.dart';
import '../../services/trial_service.dart'; // Para verificar el trial
import 'package:intl/intl.dart'; // Para formatear números
import '../../screens/categories/category_form_page.dart'; // Importar form categoría
import '../../screens/suppliers/supplier_form_page.dart'; // <-- Importar formulario de proveedor

class ProductFormPage extends StatefulWidget {
  final Product? product; // Producto existente para editar, o null para añadir

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();
  final _trialService = TrialService();

  // Controladores para los campos del formulario
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _stockController;
  late TextEditingController _purchasePriceUsdController;
  late TextEditingController _profitMarginController;

  // FocusNodes para limpiar campos numéricos
  late FocusNode _stockFocusNode;
  late FocusNode _purchasePriceFocusNode;
  late FocusNode _profitMarginFocusNode;

  double _calculatedSellingPriceUsd = 0.0;
  double _calculatedSellingPriceVes = 0.0;
  double _currentExchangeRate = 1.0; // Tasa actual (se leerá)
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _isRateLoading = true; // Para saber si la tasa ya se cargó
  double _defaultTaxRate = 0.16; // Valor por defecto
  bool _isVatEnabled = true; // Valor por defecto
  bool _isProductVatExempt = false; // Estado para indicar si el producto está exento de IVA

  // Estado para proveedores y categorías
  List<Supplier> _suppliers = [];
  int? _selectedSupplierId; // ID del proveedor seleccionado
  bool _suppliersLoading = true; // Para el dropdown
  List<Category> _categories = []; // <-- Añadido
  int? _selectedCategoryId; // <-- Añadido
  bool _categoriesLoading = true; // <-- Añadido

  final NumberFormat _usdFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$ ');
  final NumberFormat _vesFormatter = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');

  // Valores iniciales por defecto para comparación
  static const String _defaultStock = '0';
  static const String _defaultPrice = '0.00';
  static const String _defaultMarginPercent = '20'; // Margen por defecto 20%

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.product != null;

    // Inicializar controladores con datos del producto si estamos editando
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    // El stock inicial solo se pide al añadir, al editar se muestra el actual (no editable aquí)
    _stockController = TextEditingController(text: _isEditMode ? widget.product!.currentStock.toString() : _defaultStock);
    _purchasePriceUsdController = TextEditingController(text: _isEditMode ? widget.product!.purchasePriceUsd.toStringAsFixed(2) : _defaultPrice);
    _profitMarginController = TextEditingController(text: _isEditMode ? (widget.product!.profitMargin * 100).toStringAsFixed(0) : _defaultMarginPercent);

    // Asignar el supplierId inicial si estamos editando
    _selectedSupplierId = widget.product?.supplierId;
    _selectedCategoryId = widget.product?.categoryId; // <-- Añadido
    _isProductVatExempt = widget.product?.isVatExempt ?? false; // Estado inicial de exención de IVA

    // Inicializar FocusNodes
    _stockFocusNode = FocusNode();
    _purchasePriceFocusNode = FocusNode();
    _profitMarginFocusNode = FocusNode();

    // Añadir listeners a FocusNodes para limpiar campos
    _stockFocusNode.addListener(_handleFocusChange(_stockController, _defaultStock));
    _purchasePriceFocusNode.addListener(_handleFocusChange(_purchasePriceUsdController, _defaultPrice));
    _profitMarginFocusNode.addListener(_handleFocusChange(_profitMarginController, _defaultMarginPercent));

    // Cargar datos necesarios (tasa, proveedores, categorías)
    _loadInitialData();

    // Añadir listeners para recalcular precio de venta
    _purchasePriceUsdController.addListener(_calculatePrices);
    _profitMarginController.addListener(_calculatePrices);
  }

  @override
  void dispose() {
    // Limpiar controladores
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _purchasePriceUsdController.dispose();
    _profitMarginController.dispose();
    // Limpiar FocusNodes
    _stockFocusNode.removeListener(_handleFocusChange(_stockController, _defaultStock));
    _purchasePriceFocusNode.removeListener(_handleFocusChange(_purchasePriceUsdController, _defaultPrice));
    _profitMarginFocusNode.removeListener(_handleFocusChange(_profitMarginController, _defaultMarginPercent));
    _stockFocusNode.dispose();
    _purchasePriceFocusNode.dispose();
    _profitMarginFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({int? selectCategoryIdAfterLoad}) async {
    setState(() {
      _isRateLoading = true;
      _suppliersLoading = true;
      _categoriesLoading = true; // <-- Añadido
    });
    try {
      // Cargar todo en paralelo
      final results = await Future.wait([
        _dbHelper.getExchangeRate(),
        _dbHelper.getSuppliers(),
        _dbHelper.getCategories(), // <-- Añadido
        _dbHelper.getDefaultTaxRate(),
        _dbHelper.getVatEnabled(), // Cargar si el IVA está habilitado
      ]);

      _currentExchangeRate = results[0] as double;
      _suppliers = results[1] as List<Supplier>;
      _categories = results[2] as List<Category>; // <-- Añadido
      _defaultTaxRate = results[3] as double;
      _isVatEnabled = results[4] as bool; // Asignar el estado del IVA

      // Validar IDs seleccionados iniciales
      if (_selectedSupplierId != null && !_suppliers.any((s) => s.id == _selectedSupplierId)) {
        print("Advertencia: El ID de proveedor guardado ($_selectedSupplierId) no existe en la lista actual. Reiniciando selección.");
        _selectedSupplierId = null; // Reiniciar si no existe
      }
      if (_selectedCategoryId != null && !_categories.any((c) => c.id == _selectedCategoryId)) { // <-- Añadido
        print("Advertencia: El ID de categoría guardado ($_selectedCategoryId) no existe en la lista actual. Reiniciando selección.");
        _selectedCategoryId = null; // Reiniciar si no existe
      }

      // Si se pasó un ID para seleccionar después de cargar, asignarlo
      if (selectCategoryIdAfterLoad != null) {
         _selectedCategoryId = selectCategoryIdAfterLoad;
      }

      _calculatePrices(); // Calcular precios con la tasa cargada

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos iniciales: $e'), backgroundColor: Colors.red),
        );
        _currentExchangeRate = 1.0;
        _suppliers = []; // Lista vacía en caso de error
        _categories = []; // <-- Añadido
        _defaultTaxRate = 0.16; // Valor por defecto
        _isVatEnabled = true; // Valor por defecto
        _calculatePrices();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRateLoading = false;
          _suppliersLoading = false;
          _categoriesLoading = false; // <-- Añadido
          print('[ProductFormPage] Datos iniciales cargados.');
        });
      }
    }
  }

  void _calculatePrices() {
    final purchasePriceUsd = double.tryParse(_purchasePriceUsdController.text) ?? 0.0;
    final profitMarginPercent = double.tryParse(_profitMarginController.text) ?? 0.0;
    final profitMarginDecimal = profitMarginPercent / 100.0;

    // --- DEBUG PRINT ---
    print('--- Calculando Precios ---');
    print('Costo USD: $purchasePriceUsd');
    print('Margen %: $profitMarginPercent');
    print('Margen Dec: $profitMarginDecimal');
    print('Tasa Cambio: $_currentExchangeRate');
    print('IVA Habilitado: $_isVatEnabled');
    print('Producto Exento: $_isProductVatExempt');
    print('Tasa de IVA: ${_defaultTaxRate * 100}%');
    // --- FIN DEBUG PRINT ---

    if (profitMarginDecimal >= 1.0) {
      if (mounted) {
        setState(() {
          _calculatedSellingPriceUsd = 0.0;
          _calculatedSellingPriceVes = 0.0;
        });
      }
      print('Margen >= 100%, precios reseteados a 0.'); // Debug
      return;
    }

    // Calcular el precio base sin IVA
    final baseSellingPriceUsd = Product.calculateSellingPrice(purchasePriceUsd, profitMarginDecimal);
    
    // Aplicar IVA si está habilitado usando el método estático del modelo
    final sellingPriceUsd = Product.calculateFinalPrice(
      baseSellingPriceUsd, 
      _isVatEnabled, 
      _defaultTaxRate, 
      isProductExempt: _isProductVatExempt
    );
    
    // Redondear el precio en bolívares a 2 decimales
    final sellingPriceVes = double.parse((sellingPriceUsd * _currentExchangeRate).toStringAsFixed(2));

    // --- DEBUG PRINT ---
    print('Precio Base USD (Sin IVA): $baseSellingPriceUsd');
    print('Precio Venta USD (Final): $sellingPriceUsd');
    print('Precio Venta VES (Final): $sellingPriceVes');
    print('------------------------');
    // --- FIN DEBUG PRINT ---

    if (mounted) {
      setState(() {
        _calculatedSellingPriceUsd = sellingPriceUsd;
        _calculatedSellingPriceVes = sellingPriceVes;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar límite de productos en versión trial
      if (!_isEditMode) {
        final trialStatus = await _trialService.checkTrialStatus();
        if (trialStatus.state == TrialState.expired) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Período de prueba finalizado. No se pueden añadir nuevos productos.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Calcular los precios de venta final con el método más reciente
      final purchasePriceUsd = double.parse(_purchasePriceUsdController.text);
      final profitMarginDecimal = double.parse(_profitMarginController.text) / 100;
      final baseSellingPriceUsd = Product.calculateSellingPrice(purchasePriceUsd, profitMarginDecimal);
      final finalSellingPriceUsd = Product.calculateFinalPrice(
        baseSellingPriceUsd, 
        _isVatEnabled, 
        _defaultTaxRate,
        isProductExempt: _isProductVatExempt
      );
      final finalSellingPriceVes = double.parse((finalSellingPriceUsd * _currentExchangeRate).toStringAsFixed(2));

      // Crear o actualizar producto
      final product = Product(
        id: widget.product?.id,
        name: _nameController.text,
        description: _descriptionController.text,
        sku: _skuController.text.isEmpty ? null : _skuController.text,
        categoryId: _selectedCategoryId ?? (_categories.isNotEmpty ? _categories.first.id! : 1), // Usar primera categoría disponible o 1
        supplierId: _selectedSupplierId ?? (_suppliers.isNotEmpty ? _suppliers.first.id! : 0), // Usar primer proveedor disponible o 0
        costPriceUsd: purchasePriceUsd,
        purchasePriceUsd: purchasePriceUsd,
        profitMargin: profitMarginDecimal,
        sellingPriceUsd: finalSellingPriceUsd, // Usar el precio calculado con IVA si corresponde
        sellingPriceVes: finalSellingPriceVes, // Usar el precio calculado con IVA si corresponde
        currentStock: _isEditMode ? widget.product!.currentStock : int.parse(_stockController.text),
        stock: _isEditMode ? widget.product!.stock : int.parse(_stockController.text),
        isVatExempt: _isProductVatExempt, // Guardar el estado de exención de IVA
      );

      if (_isEditMode) {
        await _dbHelper.updateProduct(product);
      } else {
        await _dbHelper.insertProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto ${_isEditMode ? 'actualizado' : 'guardado'} exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retornar true para indicar que se debe actualizar la lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ${_isEditMode ? 'actualizar' : 'guardar'} producto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Navega a la pantalla para añadir categoría y refresca
  Future<void> _addCategory() async {
    final newCategory = await Navigator.push<Category>(
      context,
      MaterialPageRoute(builder: (context) => const CategoryFormPage()),
    );

    if (newCategory != null && mounted) {
      // Si se añadió una categoría, recargar datos y seleccionarla
      await _loadInitialData(selectCategoryIdAfterLoad: newCategory.id);
    }
  }

  // ---> NUEVA FUNCIÓN PARA NAVEGAR Y AÑADIR PROVEEDOR <--- 
  Future<void> _navigateToAddSupplier() async {
     final result = await Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const SupplierFormPage()),
     );

     // Si se guardó un proveedor nuevo (asumiendo que devuelve true)
     if (result == true && mounted) {
       print("Nuevo proveedor guardado, recargando lista...");
       // Recargar solo proveedores (no toda la data inicial)
        setState(() { _suppliersLoading = true; });
        try {
           final suppliers = await _dbHelper.getSuppliers();
           if (mounted) {
             setState(() {
               _suppliers = suppliers;
               // Opcional: intentar seleccionar el último añadido (más complejo)
             });
           }
        } catch (e) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error recargando proveedores: $e'), backgroundColor: Colors.red),
             );
           }
        } finally {
           if (mounted) {
             setState(() { _suppliersLoading = false; });
           }
        }
     }
  }

  // ---> NUEVA FUNCIÓN PARA NAVEGAR Y AÑADIR CATEGORÍA <--- 
  Future<void> _navigateToAddCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryFormPage()),
    );

    if (result is Category && mounted) {
      print("Nueva categoría guardada (ID: ${result.id}), recargando datos...");
      await _loadInitialData(selectCategoryIdAfterLoad: result.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Producto' : 'Añadir Producto'),
      ),
      body: _isLoading || _isRateLoading || _suppliersLoading || _categoriesLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Producto',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El nombre es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU / Código (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                      // Aquí podrías añadir validación de unicidad si es necesario (más complejo)
                    ),
                    const SizedBox(height: 20),
                    // Mostrar stock actual si se edita, permitir input si se añade
                    _isEditMode
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Stock Actual: ${widget.product!.currentStock}', style: Theme.of(context).textTheme.titleMedium),
                        )
                      : TextFormField(
                          controller: _stockController,
                          focusNode: _stockFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Stock Inicial',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                           validator: (value) {
                             if (value == null || value.isEmpty) {
                               return 'Ingresa un stock inicial (puede ser 0)';
                             }
                             if (int.tryParse(value) == null) {
                                return 'Ingresa un número válido';
                             }
                             return null;
                           },
                        ),
                    const SizedBox(height: 20),
                     TextFormField(
                      controller: _purchasePriceUsdController,
                      focusNode: _purchasePriceFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Precio de Costo (USD)', 
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El precio de costo (USD) es requerido';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                           return 'Ingresa un precio válido mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                     TextFormField(
                      controller: _profitMarginController,
                      focusNode: _profitMarginFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Margen de Rentabilidad (%)', 
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'El margen es requerido';
                        }
                        final marginPercent = double.tryParse(value);
                        if (marginPercent == null || marginPercent < 0 || marginPercent >= 100) {
                           return 'Ingresa un porcentaje válido (0-99.99)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Mostrar Precios Calculados USD y VES
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio de Venta (Bs.): ${_vesFormatter.format(_calculatedSellingPriceVes)}',
                             style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Mostrar si el IVA está aplicado o no
                          Row(
                            children: [
                              Icon(
                                _isVatEnabled && !_isProductVatExempt ? Icons.check_circle : Icons.cancel,
                                color: _isVatEnabled && !_isProductVatExempt ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isVatEnabled && !_isProductVatExempt 
                                  ? "IVA incluido (${(_defaultTaxRate * 100).toStringAsFixed(0)}%)" 
                                  : "Precio sin IVA",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isVatEnabled && !_isProductVatExempt ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Checkbox para eximir de IVA a este producto específico
                    CheckboxListTile(
                      title: const Text('Producto Exento de IVA'),
                      subtitle: const Text('Marcar si este producto está exento del pago de impuestos'),
                      value: _isProductVatExempt,
                      activeColor: Colors.red, // Color rojo para destacar visualmente que está exento
                      onChanged: (bool? value) {
                        setState(() {
                          _isProductVatExempt = value ?? false;
                          _calculatePrices(); // Recalcular los precios al cambiar el estado
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 24),
                    // --- Dropdown de Proveedores ---
                    Text("Proveedor (Opcional)", style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedSupplierId,
                            hint: const Text('Seleccione'),
                            isExpanded: true,
                            items: _suppliers.map((Supplier supplier) {
                              return DropdownMenuItem<int>(
                                value: supplier.id,
                                child: Text(supplier.name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: _suppliersLoading ? null : (int? newValue) {
                              setState(() {
                                _selectedSupplierId = newValue;
                              });
                            },
                            // No añadir validación obligatoria
                            decoration: InputDecoration(
                              // labelText: 'Proveedor (Opcional)', // Quitar si ya hay texto arriba
                              prefixIcon: _suppliersLoading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const Icon(Icons.business_outlined),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón para añadir nuevo proveedor
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          tooltip: 'Añadir Nuevo Proveedor',
                          onPressed: _suppliersLoading ? null : _navigateToAddSupplier,
                          style: IconButton.styleFrom(padding: const EdgeInsets.all(12)), // Ajustar padding
                        ),
                      ],
                    ),
                    // --- Fin Dropdown ---

                    const SizedBox(height: 24), // Espacio antes de categoría

                    // --- Fila para Dropdown de Categoría y Botón Añadir ---
                    Text("Categoría (Opcional)", style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                             value: _selectedCategoryId,
                             hint: const Text('Seleccione'),
                             isExpanded: true,
                             items: _categories.map((Category category) {
                               return DropdownMenuItem<int>(
                                 value: category.id,
                                 child: Text(category.name, overflow: TextOverflow.ellipsis),
                               );
                             }).toList(),
                             onChanged: _categoriesLoading ? null : (int? newValue) {
                               setState(() {
                                 _selectedCategoryId = newValue;
                               });
                             },
                             validator: (value) {
                               if (value == null) return 'Seleccione una categoría';
                               return null;
                             },
                             decoration: InputDecoration(
                               labelText: 'Categoría',
                               prefixIcon: _categoriesLoading
                                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                   : const Icon(Icons.category_outlined),
                               contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                               border: const OutlineInputBorder(),
                             ),
                          ),
                        ),
                         const SizedBox(width: 8),
                         // Botón para añadir nueva categoría
                         IconButton.filledTonal(
                           icon: const Icon(Icons.add),
                           tooltip: 'Añadir Nueva Categoría',
                           onPressed: _categoriesLoading ? null : _navigateToAddCategory,
                           style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                         ),
                      ],
                    ),
                    // --- Fin Fila Categoría ---

                    const SizedBox(height: 40),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isEditMode ? 'Actualizar Producto' : 'Guardar Producto',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper para crear el listener del foco
  VoidCallback _handleFocusChange(TextEditingController controller, String defaultValue) {
    return () {
      if (_stockFocusNode.hasFocus && controller.text == defaultValue) {
        controller.clear();
      }
    };
  }
} 