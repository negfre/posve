import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart'; // Importar bcrypt
// import 'package:provider/provider.dart'; // Ya no se necesita Provider aquí
import '../../services/database_helper.dart'; // Helper de BD
import '../../models/user.dart'; // Modelo User
// import '../../providers/auth_provider.dart'; // Ya no se necesita AuthProvider aquí
import 'login_page.dart'; // Para navegar a Login
import '../../theme/app_theme.dart'; // Para usar el tema
import '../../screens/auth/auth_wrapper.dart'; // Re-importar AuthWrapper
// import '../../screens/auth/auth_wrapper.dart'; // Ya no se necesita AuthWrapper aquí

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    final dbHelper = DatabaseHelper();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1. Verificar si el email ya existe
      bool exists = await dbHelper.checkEmailExists(email);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este email ya está registrado.')),
          );
        }
        setState(() { _isLoading = false; });
        return;
      }

      // 2. Generar Salt y Hash
      final salt = BCrypt.gensalt();
      final passwordHash = BCrypt.hashpw(password, salt);

      // 3. Crear objeto User
      final newUser = User(
        email: email,
        passwordHash: passwordHash,
        salt: salt,
        createdAt: DateTime.now(),
      );

      // 4. Insertar usuario en la BD
      await dbHelper.insertUser(newUser);

      // 5. Iniciar el período de prueba si es necesario
      await dbHelper.startTrialIfNeeded();

      // 6. Mostrar mensaje y navegar a AuthWrapper
      if (mounted) {
        // YA NO se autentica automáticamente
        // final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // await authProvider.loginUserAfterRegistration(newUser);

        // Mostrar mensaje de éxito original
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Por favor, inicia sesión.')), // Mensaje original
        );

        // Navegar a AuthWrapper limpiando la pila. AuthWrapper mostrará LoginPage.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (Route<dynamic> route) => false, // Elimina todas las rutas anteriores
        );

        // YA NO se usa pushReplacement a LoginPage directamente
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const LoginPage()),
        // );
      }
    } catch (e) {
      // Manejar errores generales (ej: problemas con la BD)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en el registro: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrarse'),
        // Añadir botón para volver a Login si se prefiere
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(builder: (context) => const LoginPage()),
        //   ),
        // ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Por favor ingresa un email válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirma tu contraseña';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8.0),
                           ),
                        ),
                        onPressed: _register,
                        child: const Text('Registrarse'),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text('¿Ya tienes cuenta? Inicia Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 