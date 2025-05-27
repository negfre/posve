import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveCredentials(String email, String password) async {
    final credentials = {
      'email': email,
      'password': password,
    };
    await _storage.write(
      key: 'credentials_$email',
      value: json.encode(credentials),
    );
    await _storage.write(key: 'last_email', value: email);
  }

  Future<Map<String, String>?> getCredentials(String email) async {
    final credentialsJson = await _storage.read(key: 'credentials_$email');
    if (credentialsJson == null) return null;
    
    final credentials = json.decode(credentialsJson) as Map<String, dynamic>;
    return {
      'email': credentials['email'] as String,
      'password': credentials['password'] as String,
    };
  }

  Future<String?> getLastEmail() async {
    return await _storage.read(key: 'last_email');
  }

  Future<void> deleteCredentials(String email) async {
    await _storage.delete(key: 'credentials_$email');
    final lastEmail = await getLastEmail();
    if (lastEmail == email) {
      await _storage.delete(key: 'last_email');
    }
  }
} 