import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/license.dart';
import 'database_helper.dart';

class LicenseService {
  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Claves para SharedPreferences
  static const String _licenseKey = 'app_license';
  static const String _lastWarningDateKey = 'last_warning_date';
  static const String _lastCleanupDateKey = 'last_cleanup_date';
  static const String _deviceIdKey = 'device_id';
  
  // Configuración del sistema de licenciamiento
  static const int _warningIntervalDays = 1; // Mostrar advertencia cada día
  static const int _cleanupIntervalDays = 10; // Borrar productos cada 10 días

  // Generar ID único del dispositivo de forma persistente
  Future<String> _generateDeviceId() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String? uniqueId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        uniqueId = androidInfo.id; // Usa el ANDROID_ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        uniqueId = iosInfo.identifierForVendor; // Persistente para el vendor
      }
    } catch (e) {
      print('Error al obtener el ID del dispositivo: $e');
      // Fallback a un ID no persistente si todo falla
      uniqueId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Si por alguna razón el ID es nulo, creamos un fallback
    if (uniqueId == null || uniqueId.isEmpty) {
        uniqueId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Se usa un hash para normalizar el ID y evitar exponer el ID real
    final bytes = utf8.encode(uniqueId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16).toUpperCase();
  }

  // Obtener o generar ID del dispositivo
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }

  // Generar token de activación
  Future<String> generateActivationToken() async {
    final deviceId = await getDeviceId();
    
    // Generar token fijo basado solo en el deviceId
    final tokenData = 'POSVE_ACTIVATION_$deviceId';
    final bytes = utf8.encode(tokenData);
    final digest = sha256.convert(bytes);
    
    return digest.toString().substring(0, 24).toUpperCase(); // Token de 24 caracteres
  }

  // Guardar licencia
  Future<bool> saveLicense(String licenseKey) async {
    try {
      final deviceId = await getDeviceId();
      final activationToken = await generateActivationToken(); // Token fijo
      
      // Validar que el código de licencia sea correcto
      if (!_validateLicenseKey(activationToken, licenseKey)) {
        print('Código de licencia inválido');
        return false;
      }
      
      final license = License(
        deviceId: deviceId,
        activationToken: activationToken,
        licenseKey: licenseKey,
        activatedAt: DateTime.now(),
        isActive: true,
        deviceInfo: Platform.operatingSystemVersion,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, json.encode(license.toMap()));
      
      return true;
    } catch (e) {
      print('Error guardando licencia: $e');
      return false;
    }
  }

  // Validar que el código de licencia sea correcto
  bool _validateLicenseKey(String activationToken, String licenseKey) {
    try {
      // Clave secreta que solo tú conoces
      const String secretKey = "MI_CLAVE_SUPER_SECRETA_2024";
      
      // Generar el hash esperado del token de activación
      final expectedHash = _generateLicenseHash(activationToken, secretKey);
      
      // Comparar con el código proporcionado
      return licenseKey.toUpperCase() == expectedHash.toUpperCase();
    } catch (e) {
      print('Error validando licencia: $e');
      return false;
    }
  }

  // Generar hash de licencia (mismo algoritmo que el generador)
  String _generateLicenseHash(String activationToken, String secretKey) {
    final data = utf8.encode(activationToken + secretKey);
    final digest = sha256.convert(data);
    return digest.toString().substring(0, 16).toUpperCase(); // 16 caracteres en mayúsculas
  }

  // Obtener licencia actual
  Future<License?> getCurrentLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final licenseData = prefs.getString(_licenseKey);
      
      if (licenseData != null) {
        final map = json.decode(licenseData) as Map<String, dynamic>;
        return License.fromMap(map);
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo licencia: $e');
      return null;
    }
  }

  // Verificar si la licencia es válida
  Future<bool> isLicenseValid() async {
    try {
      final license = await getCurrentLicense();
      if (license == null) return false;
      
      // Verificar que la licencia esté activa
      if (!license.isActive) return false;
      
      // Verificar que el deviceId coincida
      final currentDeviceId = await getDeviceId();
      if (license.deviceId != currentDeviceId) return false;
      
      // Verificar que la licencia tenga fecha de activación
      if (license.activatedAt == null) return false;
      
      return true;
    } catch (e) {
      print('Error verificando licencia: $e');
      return false;
    }
  }

  // Verificar si debe mostrar advertencia
  Future<bool> shouldShowWarning() async {
    try {
      final isValid = await isLicenseValid();
      if (isValid) return false; // No mostrar advertencia si la licencia es válida
      
      final prefs = await SharedPreferences.getInstance();
      final lastWarningDate = prefs.getString(_lastWarningDateKey);
      
      if (lastWarningDate == null) {
        // Primera vez, mostrar advertencia
        await prefs.setString(_lastWarningDateKey, DateTime.now().toIso8601String());
        return true;
      }
      
      final lastWarning = DateTime.parse(lastWarningDate);
      final daysSinceLastWarning = DateTime.now().difference(lastWarning).inDays;
      
      if (daysSinceLastWarning >= _warningIntervalDays) {
        // Actualizar fecha de última advertencia
        await prefs.setString(_lastWarningDateKey, DateTime.now().toIso8601String());
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error verificando advertencia: $e');
      return false;
    }
  }

  // Verificar si debe hacer limpieza de productos
  Future<bool> shouldCleanupProducts() async {
    try {
      final isValid = await isLicenseValid();
      if (isValid) return false; // No hacer limpieza si la licencia es válida
      
      final prefs = await SharedPreferences.getInstance();
      final lastCleanupDate = prefs.getString(_lastCleanupDateKey);
      
      if (lastCleanupDate == null) {
        // Primera vez, hacer limpieza
        await prefs.setString(_lastCleanupDateKey, DateTime.now().toIso8601String());
        return true;
      }
      
      final lastCleanup = DateTime.parse(lastCleanupDate);
      final daysSinceLastCleanup = DateTime.now().difference(lastCleanup).inDays;
      
      if (daysSinceLastCleanup >= _cleanupIntervalDays) {
        // Actualizar fecha de última limpieza
        await prefs.setString(_lastCleanupDateKey, DateTime.now().toIso8601String());
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error verificando limpieza: $e');
      return false;
    }
  }

  // Calcular días restantes antes de la limpieza
  Future<int> getDaysUntilCleanup() async {
    final isValid = await isLicenseValid();
    if (isValid) return _cleanupIntervalDays + 1; // Un número alto para indicar que no hay riesgo

    final prefs = await SharedPreferences.getInstance();
    final lastCleanupDate = prefs.getString(_lastCleanupDateKey);

    if (lastCleanupDate == null) {
      // Si nunca se ha hecho limpieza (o no se ha registrado), se considera que el período de gracia empieza ahora.
      // Guardamos la fecha actual como si fuera la de la "última limpieza" para empezar a contar.
      await prefs.setString(_lastCleanupDateKey, DateTime.now().toIso8601String());
      return _cleanupIntervalDays;
    }

    final lastCleanup = DateTime.parse(lastCleanupDate);
    final daysSinceLastCleanup = DateTime.now().difference(lastCleanup).inDays;
    final daysRemaining = _cleanupIntervalDays - daysSinceLastCleanup;

    return daysRemaining < 0 ? 0 : daysRemaining;
  }

  // Ejecutar limpieza de productos
  Future<void> cleanupProducts() async {
    try {
      print('Ejecutando limpieza de productos por falta de licencia...');
      
      // Borrar todos los productos
      await _dbHelper.deleteAllProducts();
      
      print('Limpieza de productos completada');
    } catch (e) {
      print('Error durante limpieza de productos: $e');
    }
  }

  // Mostrar advertencia de licencia
  void showLicenseWarning(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Licencia Requerida'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para continuar usando todas las funciones de la aplicación, necesitas activar una licencia.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '⚠️ ADVERTENCIA:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SizedBox(height: 8),
              Text(
                'Si no activas la licencia, todos los productos serán eliminados automáticamente cada 10 días.',
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
              Text(
                'Ve a Configuración > Activar Licencia para obtener tu código de activación.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a la pantalla de activación
                Navigator.of(context).pushNamed('/activate-license');
              },
              child: const Text('Activar Ahora'),
            ),
          ],
        );
      },
    );
  }

  // Verificar estado de licencia al iniciar la app
  Future<void> checkLicenseOnStartup(BuildContext context) async {
    try {
      // Verificar si debe hacer limpieza
      if (await shouldCleanupProducts()) {
        await cleanupProducts();
      }
      
      // Verificar si debe mostrar advertencia
      if (await shouldShowWarning()) {
        showLicenseWarning(context);
      }
    } catch (e) {
      print('Error verificando licencia al inicio: $e');
    }
  }

  // Obtener información del dispositivo para el token
  Future<String> getDeviceInfo() async {
    try {
      final deviceId = await getDeviceId();
      final platform = Platform.operatingSystem;
      final version = Platform.operatingSystemVersion;
      
      return 'Device: $deviceId | Platform: $platform | Version: $version';
    } catch (e) {
      return 'Device info unavailable';
    }
  }
} 