import 'package:flutter/material.dart';
import '../../services/database_helper.dart';
import '../../models/user.dart';
// Importaciones futuras para crear y editar
import 'create_user_page.dart'; // Importar CreateUserPage
import 'change_password_page.dart'; // Importar ChangePasswordPage
// import 'change_password_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() {
      _usersFuture = _dbHelper.getAllUsers();
    });
  }

  // Navega a la pantalla de creación y recarga la lista al volver
  void _navigateToCreateUser() {
    Navigator.push(
      context,
       MaterialPageRoute(builder: (_) => const CreateUserPage())
    ).then((_) {
      // Esto se ejecuta cuando se vuelve de CreateUserPage
      _loadUsers(); // Recargar la lista de usuarios
    });
    // Se elimina el SnackBar placeholder
    /*
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad Crear Usuario no implementada.')),
    );
    */
  }

  // Navega a la pantalla de cambio de contraseña
  void _navigateToChangePassword(User user) {
     Navigator.push(
      context,
       MaterialPageRoute(builder: (_) => ChangePasswordPage(user: user))
       // No necesitamos recargar la lista aquí, ya que no cambia
    );
     // Se elimina el SnackBar placeholder
    /*
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cambiar contraseña para ${user.email} no implementado.')),
    );
    */
  }

  // TODO: Implementar lógica de eliminación con confirmación
  Future<void> _deleteUser(User user) async {
    // Mostrar diálogo de confirmación
     bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar al usuario ${user.email}? Esta acción no se puede deshacer.'),
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
    ) ?? false; // Si el diálogo se cierra sin selección, asumir false

    if (confirm) {
      try {
        await _dbHelper.deleteUser(user.id!); // Asumiendo que id no es null
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario ${user.email} eliminado.')),
        );
        _loadUsers(); // Recargar la lista
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar usuario: ${e.toString()}')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al cargar usuarios: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.email),
                // Podríamos añadir más info como fecha de creación si quisiéramos
                // subtitle: Text('ID: ${user.id}'), 
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.password),
                      tooltip: 'Cambiar Contraseña',
                      onPressed: () => _navigateToChangePassword(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar Usuario',
                      onPressed: () => _deleteUser(user),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateUser,
        tooltip: 'Crear Usuario',
        child: const Icon(Icons.add),
      ),
    );
  }
} 