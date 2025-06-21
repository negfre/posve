import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Generador de Licencias para POSVE
/// 
/// Uso:
/// 1. El cliente te envía su token de activación
/// 2. Ejecutas: dart run license_generator.dart
/// 3. Ingresas el token cuando te lo pida
/// 4. El script te genera el código de licencia válido
/// 5. Envías ese código al cliente

void main() async {
  print('🔐 GENERADOR DE LICENCIAS POSVE 🔐');
  print('=====================================\n');
  
  // Clave secreta (la misma que está en la app)
  const String secretKey = "MI_CLAVE_SUPER_SECRETA_2024";
  
  print('📋 Instrucciones:');
  print('1. El cliente debe generar su token de activación en la app');
  print('2. Te envía ese token por WhatsApp, email, etc.');
  print('3. Ingresa el token aquí cuando te lo pida');
  print('4. Te generaré el código de licencia válido');
  print('5. Envías ese código al cliente para que lo active\n');
  
  while (true) {
    stdout.write('🔑 Ingresa el token de activación del cliente (o "salir" para terminar): ');
    final input = stdin.readLineSync()?.trim();
    
    if (input == null || input.toLowerCase() == 'salir') {
      print('\n👋 ¡Hasta luego!');
      break;
    }
    
    if (input.isEmpty) {
      print('❌ El token no puede estar vacío\n');
      continue;
    }
    
    // Validar formato del token (debe ser de 24 caracteres hexadecimal)
    if (input.length != 24 || !RegExp(r'^[A-F0-9]+$').hasMatch(input.toUpperCase())) {
      print('❌ Formato de token inválido. Debe ser de 24 caracteres hexadecimales (A-F, 0-9)\n');
      continue;
    }
    
    try {
      // Generar el código de licencia
      final licenseCode = generateLicenseCode(input, secretKey);
      
      print('\n✅ CÓDIGO DE LICENCIA GENERADO:');
      print('================================');
      print('🔑 Token del cliente: $input');
      print('🎫 Código de licencia: $licenseCode');
      print('📱 Envía este código al cliente para que lo active en la app');
      print('⏰ Fecha de generación: ${DateTime.now().toString().substring(0, 19)}');
      print('================================\n');
      
      // Preguntar si quiere generar otro
      stdout.write('¿Generar otro código? (s/n): ');
      final continueGenerating = stdin.readLineSync()?.toLowerCase();
      if (continueGenerating != 's' && continueGenerating != 'si' && continueGenerating != 'y' && continueGenerating != 'yes') {
        print('\n👋 ¡Hasta luego!');
        break;
      }
      print('');
      
    } catch (e) {
      print('❌ Error generando código de licencia: $e\n');
    }
  }
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

/// Función auxiliar para validar un código de licencia (para pruebas)
bool validateLicenseCode(String activationToken, String licenseCode, String secretKey) {
  final expectedCode = generateLicenseCode(activationToken, secretKey);
  return licenseCode.toUpperCase() == expectedCode.toUpperCase();
} 