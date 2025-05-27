import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../models/payment_method.dart';
// Importar el formulario
import 'widgets/payment_method_form.dart'; 

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formas de Pago'),
      ),
      body: Consumer<PaymentMethodProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.paymentMethods.isEmpty) {
            // Mostrar loading solo si no hay datos previos
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.paymentMethods.isEmpty) {
             // Mostrar error solo si no hay datos previos
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${provider.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                       icon: const Icon(Icons.refresh),
                       label: const Text('Reintentar'),
                       onPressed: () => provider.loadPaymentMethods(), 
                    )
                  ],
                ),
              ),
            );
          }

          if (provider.paymentMethods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No hay formas de pago registradas.'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir Forma de Pago'),
                    onPressed: () => _showEditDialog(context),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadPaymentMethods(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Espacio para el FAB
              itemCount: provider.paymentMethods.length,
              itemBuilder: (context, index) {
                final method = provider.paymentMethods[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: const Icon(Icons.payment),
                    title: Text(method.name),
                    subtitle: Text(method.description ?? 'Sin descripción'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Editar',
                          onPressed: () {
                            _showEditDialog(context, existingMethod: method);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar',
                          onPressed: () {
                            _confirmDelete(context, provider, method.id!);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Añadir Forma de Pago'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Métodos privados para diálogos/acciones --- 

  void _showEditDialog(BuildContext context, {PaymentMethod? existingMethod}) {
    showDialog(
      context: context,
      // barrierDismissible: false, // Opcional: Evitar cerrar al tocar fuera
      builder: (BuildContext dialogContext) {
        // El provider ya está disponible a través de context,
        // PaymentMethodForm usará context.read<PaymentMethodProvider>()
        return AlertDialog(
          title: Text(existingMethod == null ? 'Añadir Forma de Pago' : 'Editar Forma de Pago'),
          content: SingleChildScrollView( // Para evitar overflow si el teclado aparece
             child: PaymentMethodForm(paymentMethod: existingMethod), 
          ),
          // Las acciones se manejan ahora dentro del PaymentMethodForm
          // actions: <Widget>[ ... ], 
           // Añadir un botón de cancelar explícito si se desea fuera del form
           actions: <Widget>[
             TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                 Navigator.of(dialogContext).pop();
              },
            ),
           ]
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, PaymentMethodProvider provider, int id) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Está seguro de que desea eliminar esta forma de pago? Esta acción podría fallar si está en uso en alguna venta.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Cerrar diálogo de confirmación
                
                // Usar context.read para acceder al provider fuera del builder
                final prov = context.read<PaymentMethodProvider>();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context); // Si necesitaras navegar después

                bool success = await prov.deletePaymentMethod(id);
                
                // Verificar si el widget sigue montado antes de usar context
                if (!navigator.mounted) return;

                if (!success) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(prov.error ?? 'Error al eliminar. Verifique que no esté en uso.'), backgroundColor: Colors.red),
                  );
                } else {
                   messenger.showSnackBar(
                    const SnackBar(content: Text('Forma de pago eliminada'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
} 