import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Script de prueba para verificar el sistema de licenciamiento
/// 
/// Este script simula el proceso completo:
/// 1. Genera un token de activación (como lo haría la app)
/// 2. Genera el código de licencia válido (como lo harías tú)
/// 3. Valida que el código sea correcto (como lo hace la app)

void main() async {
  print('=== GENERADOR DE LICENCIA PARA POSVE ===\n');
  
  // Simular el mismo proceso que usa la app
  final deviceId = await _generateDeviceId();
  print('Device ID: $deviceId');
  
  final activationToken = await _generateActivationToken(deviceId);
  print('Token de Activación: $activationToken');
  
  final licenseKey = _generateLicenseHash(activationToken);
  print('Código de Licencia: $licenseKey');
  
  print('\n=== INSTRUCCIONES ===');
  print('1. Copia el "Token de Activación" de arriba');
  print('2. Ve a la app POSVE > Configuración > Activar Licencia');
  print('3. Genera el token en la app (debe ser igual al de arriba)');
  print('4. Si el token es diferente, usa el código de licencia generado arriba');
  print('5. Si el token es igual, usa el código de licencia generado arriba');
}

/// Simula la generación de token de activación (como en la app)
String generateTestActivationToken() {
  final deviceId = "A1B2C3D4E5F6G7H8"; // Simulado
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final random = (DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
  
  final tokenData = '$deviceId-$timestamp-$random';
  final bytes = utf8.encode(tokenData);
  final digest = sha256.convert(bytes);
  
  return digest.toString().substring(0, 24).toUpperCase();
}

/// Genera el código de licencia válido para un token de activación
String generateLicenseCode(String activationToken, String secretKey) {
  // Combinar el token con la clave secreta
  final data = utf8.encode(activationToken + secretKey);
  
  // Generar hash SHA-256
  final digest = sha256.convert(data);
  
  // Tomar los primeros 16 caracteres y convertir a mayúsculas
  return digest.toString().substring(0, 16).toUpperCase();
}

/// Valida un código de licencia
bool validateLicenseCode(String activationToken, String licenseCode, String secretKey) {
  final expectedCode = generateLicenseCode(activationToken, secretKey);
  return licenseCode.toUpperCase() == expectedCode.toUpperCase();
}

// Simular el mismo proceso que usa la app
Future<String> _generateDeviceId() async {
  try {
    String deviceInfo = '';
    
    if (Platform.isAndroid) {
      deviceInfo = '${Platform.operatingSystemVersion}_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isIOS) {
      deviceInfo = '${Platform.operatingSystemVersion}_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    final bytes = utf8.encode(deviceInfo);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  } catch (e) {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

Future<String> _generateActivationToken(String deviceId) async {
  // Generar token fijo basado solo en el deviceId (igual que la app)
  final tokenData = 'POSVE_ACTIVATION_$deviceId';
  final bytes = utf8.encode(tokenData);
  final digest = sha256.convert(bytes);
  
  return digest.toString().substring(0, 24).toUpperCase();
}

String _generateLicenseHash(String activationToken) {
  const String secretKey = "MI_CLAVE_SUPER_SECRETA_2024";
  final data = utf8.encode(activationToken + secretKey);
  final digest = sha256.convert(data);
  return digest.toString().substring(0, 16).toUpperCase();
} 