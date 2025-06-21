import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas y números
import '../../models/sale.dart';
import '../../services/database_helper.dart'; // Importa el helper y los modelos
// Opcional, para colores
import 'sale_details_page.dart'; // Importamos la página de detalles
import 'sales_order_page.dart'; // Importamos la página de registro de ventas

class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Sale>> _salesFuture;
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    setState(() {
      _salesFuture = _dbHelper.getAllSales();
    });
  }
  
  // Añadir método para eliminar ventas
  Future<void> _deleteSale(int id) async {
    // Mostrar diálogo de confirmación
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar borrado'),
          content: const Text('¿Estás seguro de eliminar esta venta?\n\nEsta acción también afectará al stock de los productos.'),
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
        await _dbHelper.deleteSale(id); // Usar la nueva función para borrar una venta específica
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venta eliminada correctamente'), backgroundColor: Colors.green),
          );
          _loadSales(); // Recargar la lista
        }
      } catch (e) {
        if (mounted) {
          // Mostrar mensaje de error
          String errorMessage = 'Error al eliminar venta';
          
          if (e.toString().contains('FOREIGN KEY constraint failed')) {
            errorMessage = 'No se puede eliminar: esta venta está asociada a otros registros';
          } else {
            errorMessage = 'Error al eliminar venta: $e';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Método para navegar a la página de detalles
  void _viewSaleDetails(Sale sale) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => SaleDetailsPage(sale: sale)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Ventas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadSales();
        },
        child: FutureBuilder<List<Sale>>(
          future: _salesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error al cargar ventas: ${snapshot.error}', textAlign: TextAlign.center),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No hay ventas registradas.\nDesliza hacia abajo para refrescar.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final sales = snapshot.data!;

            return ListView.builder(
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                
                return Dismissible(
                  key: Key('sale-${sale.id}'),
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
                          content: const Text('¿Estás seguro de eliminar esta venta?\n\nEsta acción también afectará al stock de los productos.'),
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
                    if (sale.id != null) {
                      _deleteSale(sale.id!);
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        'Factura: ${sale.invoiceNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Cliente: ${sale.client?.name ?? 'Consumidor final'}\n'
                        'Fecha: ${_dateFormatter.format(sale.saleDate)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormatter.format(sale.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _currencyFormatterVes.format(sale.total * sale.exchangeRate),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => _viewSaleDetails(sale),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegar a la página de creación de venta
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SalesOrderPage()),
          ).then((_) => _loadSales());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 