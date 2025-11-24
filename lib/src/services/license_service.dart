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
  static const String _deviceIdKey = 'device_id';
  
  // Configuración del sistema de licenciamiento (Modo de Prueba)
  static const int _warningIntervalDays = 7; // Mostrar advertencia cada 7 días
  static const int _maxProductsWithoutLicense = 5; // Máximo de productos sin licencia

  // Generar ID único del dispositivo de forma persistente
  Future<String> _generateDeviceId() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String uniqueId = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        
        // Obtener timestamp de instalación
        final prefs = await SharedPreferences.getInstance();
        String? installTimestamp = prefs.getString('install_timestamp');
        if (installTimestamp == null) {
          installTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
          await prefs.setString('install_timestamp', installTimestamp);
        }
        
        // Combinar múltiples identificadores
        uniqueId = [
          androidInfo.id,                    // ANDROID_ID
          androidInfo.model,                 // Modelo del dispositivo
          androidInfo.manufacturer,          // Fabricante
          androidInfo.version.sdkInt.toString(), // Versión de Android
          androidInfo.fingerprint,           // Fingerprint del sistema
          installTimestamp,                  // Timestamp de instalación
          Platform.operatingSystemVersion,   // Versión del sistema
        ].join('_');
        
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        
        // Obtener timestamp de instalación
        final prefs = await SharedPreferences.getInstance();
        String? installTimestamp = prefs.getString('install_timestamp');
        if (installTimestamp == null) {
          installTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
          await prefs.setString('install_timestamp', installTimestamp);
        }
        
        // Combinar múltiples identificadores
        uniqueId = [
          iosInfo.identifierForVendor,       // ID del vendor
          iosInfo.model,                     // Modelo del dispositivo
          iosInfo.systemVersion,             // Versión de iOS
          iosInfo.utsname.machine,           // Arquitectura
          installTimestamp,                  // Timestamp de instalación
          Platform.operatingSystemVersion,   // Versión del sistema
        ].join('_');
      }
    } catch (e) {
      print('Error al obtener el ID del dispositivo: $e');
      // Fallback robusto
      uniqueId = 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Platform.operatingSystemVersion}_${DateTime.now().microsecondsSinceEpoch}';
    }

    // Asegurar que tenemos un ID válido
    if (uniqueId.isEmpty) {
      uniqueId = 'fallback_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
    }

    // Generar hash y tomar los últimos 20 caracteres
    final bytes = utf8.encode(uniqueId);
    final digest = sha256.convert(bytes);
    final hashString = digest.toString();
    return hashString.substring(hashString.length - 20).toUpperCase();
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
    final hashString = digest.toString();
    return hashString.substring(hashString.length - 20).toUpperCase(); // 20 caracteres en mayúsculas
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

  // Verificar si se puede agregar más productos (límite de 5 sin licencia)
  Future<bool> canAddProduct() async {
    try {
      final isValid = await isLicenseValid();
      if (isValid) return true; // Sin límite con licencia
      
      final products = await _dbHelper.getProducts();
      return products.length < _maxProductsWithoutLicense;
    } catch (e) {
      print('Error verificando límite de productos: $e');
      return false; // En caso de error, no permitir agregar
    }
  }

  // Obtener el número de productos actuales
  Future<int> getCurrentProductCount() async {
    try {
      final products = await _dbHelper.getProducts();
      return products.length;
    } catch (e) {
      print('Error obteniendo cantidad de productos: $e');
      return 0;
    }
  }

  // Verificar si se puede exportar reportes (solo con licencia)
  Future<bool> canExportReports() async {
    return await isLicenseValid();
  }

  // Obtener el límite máximo de productos según el estado de la licencia
  Future<int?> getMaxProductsLimit() async {
    final isValid = await isLicenseValid();
    if (isValid) return null; // Sin límite con licencia
    return _maxProductsWithoutLicense;
  }

  // Mostrar advertencia de licencia (Modo de Prueba)
  void showLicenseWarning(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Modo de Prueba'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estás usando la versión de prueba de POSVE.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Limitaciones del modo de prueba:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '• Máximo $_maxProductsWithoutLicense productos',
                style: const TextStyle(fontSize: 14),
              ),
              const Text(
                '• No se pueden exportar reportes',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Para desbloquear todas las funciones, activa una licencia.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continuar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navegar a la pantalla de activación
                Navigator.of(context).pushNamed('/activate-license');
              },
              child: const Text('Activar Licencia'),
            ),
          ],
        );
      },
    );
  }

  // Verificar estado de licencia al iniciar la app
  Future<void> checkLicenseOnStartup(BuildContext context) async {
    try {
      // Verificar si debe mostrar advertencia (solo información, no eliminación)
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