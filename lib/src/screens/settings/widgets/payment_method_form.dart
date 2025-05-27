import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/payment_method.dart';
import '../../../providers/payment_method_provider.dart';

class PaymentMethodForm extends StatefulWidget {
  final PaymentMethod? paymentMethod; // Null if adding, non-null if editing

  const PaymentMethodForm({super.key, this.paymentMethod});

  @override
  State<PaymentMethodForm> createState() => _PaymentMethodFormState();
}

class _PaymentMethodFormState extends State<PaymentMethodForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.paymentMethod?.name ?? '');
    _descriptionController = TextEditingController(text: widget.paymentMethod?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final provider = context.read<PaymentMethodProvider>();
      final navigator = Navigator.of(context); // Get navigator before async gap
      final messenger = ScaffoldMessenger.of(context); // Get messenger before async gap

      final methodToSave = PaymentMethod(
        id: widget.paymentMethod?.id, // Keep ID if editing
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
                       ? null 
                       : _descriptionController.text.trim(),
        // is_active no se maneja aquí directamente, podría ser un switch aparte
      );

      bool success;
      if (widget.paymentMethod == null) {
        // Adding new method
        success = await provider.addPaymentMethod(methodToSave);
      } else {
        // Editing existing method
        success = await provider.updatePaymentMethod(methodToSave);
      }
      
      // Check if the widget is still mounted before using context
      if (!mounted) return; 

      setState(() => _isSaving = false);

      if (success) {
        navigator.pop(); // Close the dialog/form screen
        messenger.showSnackBar(
           SnackBar(
            content: Text('Forma de pago ${widget.paymentMethod == null ? 'añadida' : 'actualizada'} correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
         messenger.showSnackBar(
           SnackBar(
            content: Text(provider.error ?? 'Error al guardar la forma de pago.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Important for Dialogs
        children: <Widget>[
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Efectivo, Zelle, Transferencia Bs.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, ingrese un nombre.';
              }
              return null;
            },
            textInputAction: TextInputAction.next, // Move focus to next field
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción (Opcional)',
              hintText: 'Ej: Solo billetes bajos, Cuenta Corriente XYZ',
            ),
            // No validator needed for optional field
            textInputAction: TextInputAction.done, // Indicate form completion
            onFieldSubmitted: (_) => _saveForm(), // Allow saving via keyboard action
          ),
           const SizedBox(height: 24),
          // Mostrar indicador de carga si se está guardando
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: CircularProgressIndicator(),
            )
          else
           // Botón de Guardar (se puede colocar fuera si el form no está en Dialog)
            ElevatedButton(
              onPressed: _saveForm, 
              child: Text(widget.paymentMethod == null ? 'Añadir' : 'Guardar Cambios'),
            ),
        ],
      ),
    );
  }
} 