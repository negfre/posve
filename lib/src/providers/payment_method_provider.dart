import 'package:flutter/material.dart';
import '../models/payment_method.dart';
import '../services/database_helper.dart';

class PaymentMethodProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Usar el singleton

  List<PaymentMethod> _paymentMethods = [];
  List<PaymentMethod> get paymentMethods => _paymentMethods;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  PaymentMethodProvider() {
    // Cargar métodos de pago al inicializar el provider (opcional)
    loadPaymentMethods();
  }

  Future<void> loadPaymentMethods({bool includeInactive = true}) async {
    _isLoading = true;
    _error = null;
    // Notificar el inicio de la carga *antes* del trabajo async
    notifyListeners(); 

    try {
      if (includeInactive) {
        _paymentMethods = await _dbHelper.getAllPaymentMethods();
      } else {
        _paymentMethods = await _dbHelper.getActivePaymentMethods();
      }
      _error = null; // Limpiar error en caso de éxito
    } catch (e) {
      _error = 'Error al cargar formas de pago: ${e.toString()}';
      print('Error en loadPaymentMethods: $e');
      _paymentMethods = []; // Limpiar datos en caso de error
    } finally {
      _isLoading = false;
      // Notificar el final de la carga *después* de actualizar estado
      notifyListeners();
    }
  }

  Future<bool> addPaymentMethod(PaymentMethod paymentMethod) async {
    // No notificamos inicio/fin aquí, loadPaymentMethods lo hará
    _isLoading = true; 
    _error = null;
    notifyListeners(); // Notificar que empieza operación

    bool success = false;
    try {
      final newMethod = paymentMethod.copyWith(id: null); 
      await _dbHelper.insertPaymentMethod(newMethod);
      success = true;
      // Recargar la lista (esto notificará al final)
      await loadPaymentMethods(); 
    } on Exception catch (e) {
       _error = 'Error al añadir forma de pago: ${e.toString()}';
       print('Error en addPaymentMethod: $e');
       success = false;
       _isLoading = false; // Asegurar que isLoading se desactive en error
       notifyListeners(); // Notificar el error
    } 
    // El finally de loadPaymentMethods ya notificará si fue exitoso
    return success;
  }

  Future<bool> updatePaymentMethod(PaymentMethod paymentMethod) async {
    _isLoading = true; 
    _error = null;
    notifyListeners(); // Notificar que empieza operación

    bool success = false;
    try {
      await _dbHelper.updatePaymentMethod(paymentMethod);
      success = true;
      await loadPaymentMethods(); 
    } on Exception catch (e) {
       _error = 'Error al actualizar forma de pago: ${e.toString()}';
       print('Error en updatePaymentMethod: $e');
       success = false;
        _isLoading = false;
        notifyListeners(); // Notificar el error
    } 
    return success;
  }

  Future<bool> deletePaymentMethod(int id) async {
    _isLoading = true; 
    _error = null;
    notifyListeners(); // Notificar que empieza operación

    bool success = false;
    try {
      await _dbHelper.deletePaymentMethod(id);
      success = true;
      await loadPaymentMethods();
    } on Exception catch (e) {
      _error = 'Error al eliminar forma de pago: ${e.toString()}';
      print('Error en deletePaymentMethod: $e');
      success = false;
      _isLoading = false;
      notifyListeners(); // Notificar el error
    } 
    return success;
  }
} 