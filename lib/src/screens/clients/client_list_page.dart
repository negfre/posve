import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/database_helper.dart';
import 'client_form_page.dart';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key});

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Client>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  void _loadClients() {
    setState(() {
      _clientsFuture = _dbHelper.getClients();
    });
  }

  void _navigateAndRefresh(BuildContext context, {Client? client}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientFormPage(client: client),
      ),
    );

    if (result == true && mounted) {
      _loadClients();
    }
  }

  Future<void> _deleteClient(int id) async {
     bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmar Borrado'),
            content: const Text('¿Estás seguro de que deseas eliminar este cliente?'),
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
          await _dbHelper.deleteClient(id);
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.green),
              );
              _loadClients();
           }
        } catch (e) {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Error al eliminar cliente: $e'), backgroundColor: Colors.red),
               );
            }
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Clientes'),
      ),
      body: FutureBuilder<List<Client>>(
        future: _clientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar clientes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay clientes registrados.'));
          }

          final clients = snapshot.data!;

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                title: Text(client.name),
                subtitle: Text('ID: ${client.taxId} | Tel: ${client.phone ?? 'N/A'}'),
                 trailing: IconButton(
                   icon: const Icon(Icons.delete, color: Colors.redAccent),
                   tooltip: 'Eliminar Cliente',
                   onPressed: () => _deleteClient(client.id!),
                 ),
                onTap: () => _navigateAndRefresh(context, client: client), // Navega para editar
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndRefresh(context), // Navega para añadir (client es null)
        tooltip: 'Añadir Cliente',
        child: const Icon(Icons.add),
      ),
    );
  }
} 