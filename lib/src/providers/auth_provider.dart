import 'package:flutter/foundation.dart';
import 'package:bcrypt/bcrypt.dart';
import '../services/database_helper.dart'; // Importar DatabaseHelper
import '../models/user.dart'; // Importar User

class AuthProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isAuthenticated = false;
  String? _loggedInUserEmail;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  String? get loggedInUserEmail => _loggedInUserEmail;
  User? get currentUser => _currentUser;

  // Método para intentar cargar el estado de autenticación al inicio (opcional)
  // Podrías guardar el email del último usuario logueado en SharedPreferences
  // y verificarlo aquí.
  // Future<void> tryAutoLogin() async { ... }

  Future<bool> login(String email, String password) async {
    try {
      final user = await _dbHelper.getUserByEmail(email);
      
      if (user == null) {
        print('*** DEBUG: Usuario no encontrado: $email ***');
        return false; // Usuario no encontrado
      }

      // Verificar contraseña
      final passwordCorrect = BCrypt.checkpw(password, user.passwordHash);
      print('*** DEBUG: Verificación de contraseña para $email correcta: $passwordCorrect ***');

      if (passwordCorrect) {
        _isAuthenticated = true;
        _loggedInUserEmail = user.email;
        _currentUser = user;
        notifyListeners(); // Notificar a los listeners del cambio de estado
        print('*** DEBUG: Login exitoso para $email ***');
        return true;
      } else {
        print('*** DEBUG: Contraseña incorrecta para $email ***');
        return false; // Contraseña incorrecta
      }
    } catch (e) {
      print('*** DEBUG: Error durante el login para $email: $e ***');
      return false; // Error durante el proceso
    }
  }

  Future<void> logout() async {
    print('*** DEBUG: Cerrando sesión para usuario: $_loggedInUserEmail ***');
    final lastEmail = _loggedInUserEmail;  // Guardamos el email antes de limpiarlo
    
    _isAuthenticated = false;
    _loggedInUserEmail = null;
    _currentUser = null;
    
    // No limpiamos la información biométrica ni el último email usado
    notifyListeners();
  }

  // Podrías añadir un método para actualizar el usuario si cambia (ej: perfil)
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
} 