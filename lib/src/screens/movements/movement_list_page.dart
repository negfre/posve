import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas y números
import '../../services/database_helper.dart'; // Importa el helper y el modelo auxiliar
// Opcional, para colores

class MovementListPage extends StatefulWidget {
  const MovementListPage({super.key});

  @override
  State<MovementListPage> createState() => _MovementListPageState();
}

class _MovementListPageState extends State<MovementListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // Cambiar el tipo del Future
  late Future<List<MovementWithProductInfo>> _movementsFuture;
  final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  void _loadMovements() {
    setState(() {
      _movementsFuture = _dbHelper.getAllMovements();
    });
  }
  
  // Añadir método para eliminar movimientos
  Future<void> _deleteMovement(int id) async {
    // Mostrar diálogo de confirmación
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar borrado'),
          content: const Text('¿Estás seguro de eliminar este movimiento?\n\nEsta acción también afectará al stock del producto.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (confirmDelete) {
      try {
        await _dbHelper.deleteMovement(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movimiento eliminado correctamente'), backgroundColor: Colors.green),
          );
          _loadMovements(); // Recargar la lista
        }
      } catch (e) {
        if (mounted) {
          // Mostrar mensaje de error
          String errorMessage = 'Error al eliminar movimiento';
          
          if (e.toString().contains('FOREIGN KEY constraint failed')) {
            errorMessage = 'No se puede eliminar: movimiento asociado a otros registros';
          } else {
            errorMessage = 'Error al eliminar movimiento: $e';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadMovements();
        },
        // Cambiar el tipo del FutureBuilder
        child: FutureBuilder<List<MovementWithProductInfo>>(
          future: _movementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error al cargar movimientos: ${snapshot.error}', textAlign: TextAlign.center),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No hay movimientos registrados.\nDesliza hacia abajo para refrescar.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final movementsWithInfo = snapshot.data!;

            return ListView.builder(
              itemCount: movementsWithInfo.length,
              itemBuilder: (context, index) {
                // Acceder al movimiento y al nombre del producto
                final movementInfo = movementsWithInfo[index];
                final movement = movementInfo.movement;
                final productName = movementInfo.productName;
                bool isPurchase = movement.type == 'purchase';

                return Dismissible(
                  key: Key('movement-${movement.id}'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirmar borrado'),
                          content: const Text('¿Estás seguro de eliminar este movimiento?\n\nEsta acción también afectará al stock del producto.'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancelar'),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Eliminar'),
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    if (movement.id != null) {
                      _deleteMovement(movement.id!);
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      leading: Icon(
                        isPurchase ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPurchase ? Colors.green : Colors.red,
                        size: 30,
                      ),
                      title: Text(
                        productName, // Mostrar nombre del producto
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${isPurchase ? 'Entrada' : 'Venta'} | ${_dateTimeFormatter.format(movement.movementDate)}\n'
                        'Cant: ${movement.quantity} | Precio U: ${_currencyFormatter.format(movement.unitPriceUsd)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isPurchase ? '+${movement.quantity}' : '-${movement.quantity}',
                            style: TextStyle(
                              color: isPurchase ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          // Agregar botón de eliminar
                          if (movement.id != null)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteMovement(movement.id!),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 