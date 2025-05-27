import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/foundation.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _lastEmailKey = 'last_email_used';

  // Verificar si el dispositivo soporta biometría
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Verificar si hay biometrías registradas
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Verificar si la biometría está habilitada para un usuario
  Future<bool> isBiometricEnabled(String userEmail) async {
    try {
      final value = await _secureStorage.read(
        key: 'biometric_enabled_for_$userEmail'
      );
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  // Guardar credenciales de forma segura
  Future<bool> saveCredentials(String userEmail, String password) async {
    try {
      final credentials = {
        'email': userEmail,
        'password': password,
      };
      
      await _secureStorage.write(
        key: 'credentials_$userEmail',
        value: json.encode(credentials),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Recuperar credenciales almacenadas
  Future<Map<String, String>?> getStoredCredentials(String userEmail) async {
    try {
      final storedCredentials = await _secureStorage.read(
        key: 'credentials_$userEmail'
      );
      
      if (storedCredentials != null) {
        final Map<String, dynamic> decoded = json.decode(storedCredentials);
        return {
          'email': decoded['email'] as String,
          'password': decoded['password'] as String,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Eliminar credenciales almacenadas
  Future<bool> deleteStoredCredentials(String userEmail) async {
    try {
      await _secureStorage.delete(key: 'credentials_$userEmail');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Guardar el último email usado
  Future<void> saveLastEmail(String email) async {
    try {
      await _secureStorage.write(
        key: _lastEmailKey,
        value: email,
      );
    } catch (e) {
      // Ignorar errores al guardar el último email
    }
  }

  // Obtener el último email usado
  Future<String?> getLastEmail() async {
    try {
      return await _secureStorage.read(key: _lastEmailKey);
    } catch (e) {
      return null;
    }
  }

  // Método modificado para habilitar biometría y guardar credenciales
  Future<bool> enableBiometric(String userEmail, String password) async {
    try {
      print('*** DEBUG: Iniciando habilitación de biometría para $userEmail ***');
      
      final canCheck = await canCheckBiometrics();
      print('*** DEBUG: ¿Puede verificar biometría?: $canCheck ***');
      if (!canCheck) {
        print('*** DEBUG: El dispositivo no puede verificar biometría ***');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      print('*** DEBUG: Biometrías disponibles: $availableBiometrics ***');
      if (availableBiometrics.isEmpty) {
        print('*** DEBUG: No hay biometrías disponibles ***');
        return false;
      }

      // Primero guardamos el último email usado
      print('*** DEBUG: Guardando último email usado ***');
      await _secureStorage.write(
        key: _lastEmailKey,
        value: userEmail,
      );

      // Luego guardamos las credenciales
      print('*** DEBUG: Intentando guardar credenciales ***');
      final credentialsSaved = await saveCredentials(userEmail, password);
      if (!credentialsSaved) {
        print('*** DEBUG: Error al guardar credenciales ***');
        return false;
      }
      
      print('*** DEBUG: Marcando biometría como habilitada ***');
      await _secureStorage.write(
        key: 'biometric_enabled_for_$userEmail',
        value: 'true'
      );
      
      print('*** DEBUG: Biometría habilitada exitosamente ***');
      return true;
    } catch (e) {
      print('*** DEBUG: Error al habilitar biometría: $e ***');
      return false;
    }
  }

  // Método modificado para deshabilitar biometría y eliminar credenciales
  Future<bool> disableBiometric(String userEmail) async {
    try {
      await deleteStoredCredentials(userEmail);
      await _secureStorage.delete(
        key: 'biometric_enabled_for_$userEmail'
      );
      await _secureStorage.delete(key: _lastEmailKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Autenticar con biometría
  Future<bool> authenticate() async {
    try {
      debugPrint('*** DEBUG: Iniciando autenticación biométrica ***');
      
      final canCheck = await canCheckBiometrics();
      debugPrint('*** DEBUG: ¿Puede verificar biometría?: $canCheck ***');
      if (!canCheck) {
        debugPrint('*** DEBUG: El dispositivo no puede verificar biometría ***');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      debugPrint('*** DEBUG: Biometrías disponibles: $availableBiometrics ***');
      if (availableBiometrics.isEmpty) {
        debugPrint('*** DEBUG: No hay biometrías disponibles ***');
        return false;
      }

      debugPrint('*** DEBUG: Solicitando autenticación biométrica ***');
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a la aplicación',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      debugPrint('*** DEBUG: Resultado de autenticación: $authenticated ***');
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('*** DEBUG: Error PlatformException en autenticación: ${e.code} - ${e.message} ***');
      if (e.code == auth_error.notAvailable) {
        debugPrint('*** DEBUG: Autenticación biométrica no disponible ***');
        return false;
      }
      if (e.code == auth_error.notEnrolled) {
        debugPrint('*** DEBUG: No hay huellas registradas ***');
        return false;
      }
      if (e.code == auth_error.lockedOut || e.code == auth_error.permanentlyLockedOut) {
        debugPrint('*** DEBUG: Autenticación bloqueada ***');
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('*** DEBUG: Error general en autenticación: $e ***');
      return false;
    }
  }
} 