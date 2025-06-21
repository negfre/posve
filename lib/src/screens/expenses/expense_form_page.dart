import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/payment_method.dart';
import '../../services/database_helper.dart';
import '../../constants/app_colors.dart';

class ExpenseFormPage extends StatefulWidget {
  final Expense? expense; // Si es null, es un nuevo gasto

  const ExpenseFormPage({super.key, this.expense});

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Controladores
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  final _supplierController = TextEditingController();

  // Variables de estado
  String _selectedCategory = '';
  String _selectedPaymentMethod = '';
  DateTime _expenseDate = DateTime.now();
  List<ExpenseCategory> _categories = [];
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.expense != null) {
      _loadExpenseData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Primero, asegurar que las categorías de gastos existan
      await _dbHelper.initializeDefaultExpenseCategories();
      
      final futures = await Future.wait([
        _dbHelper.getExpenseCategories(),
        _dbHelper.getActivePaymentMethods(),
      ]);

      final categories = futures[0] as List<ExpenseCategory>;
      final paymentMethods = futures[1] as List<PaymentMethod>;

      setState(() {
        _categories = categories;
        _paymentMethods = paymentMethods;
        
        // Seleccionar valores por defecto si no hay gasto existente
        if (widget.expense == null) {
          if (categories.isNotEmpty) {
            _selectedCategory = categories.first.name;
          }
          if (paymentMethods.isNotEmpty) {
            _selectedPaymentMethod = paymentMethods.first.name;
          }
        }
        
        _isLoading = false;
      });

      // Cargar el monto después de que se hayan cargado los métodos de pago
      if (widget.expense != null) {
        await _loadExpenseAmount();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadExpenseData() {
    final expense = widget.expense!;
    _descriptionController.text = expense.description;
    _notesController.text = expense.notes ?? '';
    _receiptNumberController.text = expense.receiptNumber ?? '';
    _supplierController.text = expense.supplier ?? '';
    _selectedCategory = expense.category;
    _selectedPaymentMethod = expense.paymentMethod;
    _expenseDate = expense.expenseDate;
    
    // El monto se cargará después de que se carguen los métodos de pago
    // para poder determinar la moneda correcta
  }

  // Nueva función para cargar el monto después de que se carguen los métodos de pago
  Future<void> _loadExpenseAmount() async {
    if (widget.expense != null) {
      final expense = widget.expense!;
      double amount = expense.amount;
      
      // Convertir de USD a la moneda del método de pago si es necesario
      if (_getCurrencySymbol() == 'Bs') {
        final exchangeRate = await _dbHelper.getExchangeRate();
        amount = amount * exchangeRate;
      }
      
      _amountController.text = amount.toStringAsFixed(2);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedColor = '#2196F3'; // Color por defecto

    final colors = [
      '#FF5722', '#9C27B0', '#2196F3', '#FF9800', '#4CAF50', '#607D8B',
      '#E91E63', '#673AB7', '#3F51B5', '#FFC107', '#8BC34A', '#795548'
    ];

    final result = await showDialog<ExpenseCategory>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva Categoría de Gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la categoría *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse('0xFF${color.substring(1)}')),
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es requerido'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final newCategory = ExpenseCategory(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty 
                        ? null 
                        : descriptionController.text.trim(),
                    color: selectedColor,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  final id = await _dbHelper.insertExpenseCategory(newCategory);
                  final savedCategory = ExpenseCategory(
                    id: id,
                    name: newCategory.name,
                    description: newCategory.description,
                    color: newCategory.color,
                    createdAt: newCategory.createdAt,
                    updatedAt: newCategory.updatedAt,
                  );

                  Navigator.pop(context, savedCategory);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al crear categoría: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // Recargar categorías y seleccionar la nueva
      await _loadInitialData();
      setState(() {
        _selectedCategory = result.name;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Obtener el monto ingresado
      double amount = double.parse(_amountController.text);
      
      // Convertir a USD si está en bolívares
      if (_getCurrencySymbol() == 'Bs') {
        final exchangeRate = await _dbHelper.getExchangeRate();
        amount = amount / exchangeRate;
      }

      final expense = Expense(
        id: widget.expense?.id,
        description: _descriptionController.text.trim(),
        amount: amount, // Monto ya convertido a USD
        category: _selectedCategory,
        expenseDate: _expenseDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        receiptNumber: _receiptNumberController.text.trim().isEmpty ? null : _receiptNumberController.text.trim(),
        supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.expense == null) {
        await _dbHelper.insertExpense(expense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gasto registrado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _dbHelper.updateExpense(expense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gasto actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar gasto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _receiptNumberController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Nuevo Gasto' : 'Editar Gasto'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveExpense,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción *',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La descripción es requerida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Categoría
                    Text("Categoría *", style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory.isEmpty ? null : _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category.name,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse('0xFF${category.color.substring(1)}')),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Seleccione una categoría';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón para añadir nueva categoría
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          tooltip: 'Añadir Nueva Categoría',
                          onPressed: _showAddCategoryDialog,
                          style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Fecha
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_expenseDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Método de pago
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod.isEmpty ? null : _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Método de Pago *',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method.name,
                          child: Text(method.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                          // Limpiar el monto cuando cambie el método de pago
                          _amountController.clear();
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Seleccione un método de pago';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Monto (se ajusta según la moneda del método de pago)
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Monto ${_getCurrencySymbol()} *',
                        prefixIcon: Icon(_getCurrencyIcon()),
                        border: const OutlineInputBorder(),
                        hintText: 'Ingrese el monto en ${_getCurrencyName()}',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El monto es requerido';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Ingrese un monto válido mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Proveedor
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Número de recibo
                    TextFormField(
                      controller: _receiptNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Recibo',
                        prefixIcon: Icon(Icons.receipt),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notas
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expenseColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Guardar Gasto',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _getCurrencySymbol() {
    if (_selectedPaymentMethod.isEmpty) return 'USD';
    
    if (_selectedPaymentMethod.contains('USD') || 
        _selectedPaymentMethod.contains('Dólares') ||
        _selectedPaymentMethod.contains('Dolares')) {
      return 'USD';
    } else if (_selectedPaymentMethod.contains('Bs') || 
               _selectedPaymentMethod.contains('Bolívares') ||
               _selectedPaymentMethod.contains('Bolivares')) {
      return 'Bs';
    } else {
      // Por defecto USD para otros métodos
      return 'USD';
    }
  }

  IconData _getCurrencyIcon() {
    if (_selectedPaymentMethod.isEmpty) return Icons.attach_money;
    
    if (_selectedPaymentMethod.contains('USD') || 
        _selectedPaymentMethod.contains('Dólares') ||
        _selectedPaymentMethod.contains('Dolares')) {
      return Icons.attach_money;
    } else if (_selectedPaymentMethod.contains('Bs') || 
               _selectedPaymentMethod.contains('Bolívares') ||
               _selectedPaymentMethod.contains('Bolivares')) {
      return Icons.currency_exchange;
    } else {
      // Por defecto USD para otros métodos
      return Icons.attach_money;
    }
  }

  String _getCurrencyName() {
    if (_selectedPaymentMethod.isEmpty) return 'USD';
    
    if (_selectedPaymentMethod.contains('USD') || 
        _selectedPaymentMethod.contains('Dólares') ||
        _selectedPaymentMethod.contains('Dolares')) {
      return 'USD';
    } else if (_selectedPaymentMethod.contains('Bs') || 
               _selectedPaymentMethod.contains('Bolívares') ||
               _selectedPaymentMethod.contains('Bolivares')) {
      return 'Bolívares';
    } else {
      // Por defecto USD para otros métodos
      return 'USD';
    }
  }
} 