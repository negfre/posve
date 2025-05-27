import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear números
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/inventory_movement.dart';
import '../services/database_helper.dart';
// import 'package:POSVE/src/constants/constants.dart'; // Eliminada por no existir el archivo

class MovementFormDialog extends StatefulWidget {
  final Product product;
  final String movementType; // 'purchase' or 'sale'
  final double currentExchangeRate;

  const MovementFormDialog({
    super.key,
    required this.product,
    required this.movementType,
    required this.currentExchangeRate,
  });

  @override
  _MovementFormDialogState createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  bool _isLoadingSuppliers = false;

  @override
  void initState() {
    super.initState();
    // Pre-llenar el precio basado en el tipo de movimiento
    _priceController.text = widget.movementType == 'purchase'
        ? widget.product.purchasePriceUsd.toStringAsFixed(2)
        : widget.product.sellingPriceUsd.toStringAsFixed(2);

    if (widget.movementType == 'purchase') {
      _loadSuppliers();
    }
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final suppliers = await DatabaseHelper().getSuppliers();
      Supplier? preSelectedSupplier;

      // Buscar el proveedor después de obtener la lista
      try {
        // Usar firstWhere pero manejar la excepción si no se encuentra
        preSelectedSupplier = suppliers.firstWhere(
          (s) => s.id == widget.product.supplierId
        );
      } catch (e) {
        // StateError si no se encuentra, en ese caso preSelectedSupplier sigue siendo null
        print('Proveedor preseleccionado ID ${widget.product.supplierId} no encontrado en la lista.');
      }
    
      setState(() {
        _suppliers = suppliers;
        // Asignar el proveedor seleccionado
        if (preSelectedSupplier != null) {
          _selectedSupplier = preSelectedSupplier;
        } else if (_suppliers.isNotEmpty) {
          // Si no se encontró uno preseleccionado (o no había ID), usar el primero de la lista
          _selectedSupplier = _suppliers.first;
        } else {
          // Si la lista está vacía, asegurarse que sea null
          _selectedSupplier = null;
        }
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      print("Error cargando proveedores: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar proveedores: $e')));
      setState(() => _isLoadingSuppliers = false);
    }
  }


  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    final unitPriceUsd = double.tryParse(_priceController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cantidad debe ser un número positivo.')));
      return;
    }
    if (unitPriceUsd == null || unitPriceUsd < 0) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Precio debe ser un número positivo o cero.')));
      return;
    }

    if (widget.movementType == 'purchase' && _selectedSupplier == null && _suppliers.isNotEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error inesperado: Proveedor no seleccionado.')));
      return;
    }

    final unitPriceVes = unitPriceUsd * widget.currentExchangeRate;

    final movement = InventoryMovement(
      productId: widget.product.id!,
      type: widget.movementType,
      quantity: quantity,
      movementDate: DateTime.now(),
      unitPriceUsd: unitPriceUsd,
      unitPriceVes: unitPriceVes,
      exchangeRate: widget.currentExchangeRate,
      supplierId: (widget.movementType == 'purchase' && _selectedSupplier != null)
          ? _selectedSupplier!.id
          : null,
    );

    Navigator.of(context).pop(movement);
  }

  @override
  Widget build(BuildContext context) {
     final formatCurrency = NumberFormat.currency(locale: 'es_VE', symbol: 'VES ');
     final formatCurrencyUsd = NumberFormat.currency(locale: 'en_US', symbol: '\$');
     final priceLabel = widget.movementType == 'purchase' ? 'Precio Compra (USD)' : 'Precio Venta (USD)';
     final title = widget.movementType == 'purchase' ? 'Registrar Compra' : 'Registrar Venta';

    return AlertDialog(
      title: Text('$title - ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una cantidad';
                  }
                  final n = int.tryParse(value);
                  if (n == null || n <= 0) {
                    return 'Ingrese un número positivo';
                  }
                   // La verificación de stock para ventas se hace *antes* de llamar a recordSale
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: priceLabel,
                  suffixText: '(VES ${formatCurrency.format( (double.tryParse(_priceController.text) ?? 0) * widget.currentExchangeRate)})'
                ),
                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un precio';
                  }
                   final n = double.tryParse(value);
                   if (n == null || n < 0) {
                     return 'Ingrese un número positivo o cero';
                   }
                  return null;
                },
                onChanged: (value) {
                  // Forzar re-render para actualizar el precio en VES
                  setState(() {});
                },
              ),
              if (widget.movementType == 'purchase') ...[
                const SizedBox(height: 16),
                _isLoadingSuppliers
                    ? const CircularProgressIndicator()
                    : (_suppliers.isEmpty
                        ? const Text('No hay proveedores disponibles. Añada uno primero.')
                        : DropdownButtonFormField<Supplier>(
                            value: _selectedSupplier,
                            hint: const Text('Seleccione Proveedor'),
                            decoration: const InputDecoration(labelText: 'Proveedor'),
                            items: _suppliers.map((Supplier supplier) {
                              return DropdownMenuItem<Supplier>(
                                value: supplier,
                                child: Text(supplier.name),
                              );
                            }).toList(),
                            onChanged: (Supplier? newValue) {
                              setState(() {
                                _selectedSupplier = newValue;
                              });
                            },
                            validator: (Supplier? value) => value == null ? 'Seleccione un proveedor' : null,
                          )
                       )
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(), // Devuelve null
        ),
        ElevatedButton(
          onPressed: (_isLoadingSuppliers && widget.movementType == 'purchase') ? null : _submitForm,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
} 