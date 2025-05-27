import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_helper.dart';

class ProductProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Product> _products = [];
  List<Product> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  ProductProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      print("ProductProvider: Iniciando loadProducts()");
      _isLoading = true;
      _error = null;
      notifyListeners();

      final newProducts = await _dbHelper.getProducts();
      _products = newProducts;
      _error = null;
      
      print("ProductProvider: ${_products.length} productos cargados");
    } catch (e) {
      print("ProductProvider: Error en loadProducts: $e");
      _error = 'Error al cargar productos: ${e.toString()}';
      _products = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct(Product product) async {
    try {
      print("ProductProvider: Iniciando addProduct");
      _isLoading = true;
      _error = null;
      notifyListeners();

      final id = await _dbHelper.insertProduct(product.copyWith(id: null));
      if (id > 0) {
        // Obtener el producto recién insertado con su ID
        final newProduct = product.copyWith(id: id);
        // Agregar a la lista local
        _products.add(newProduct);
        print("ProductProvider: Producto agregado exitosamente");
        return true;
      }
      return false;
    } catch (e) {
      print("ProductProvider: Error en addProduct: $e");
      _error = 'Error al añadir producto: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      print("ProductProvider: Iniciando updateProduct");
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _dbHelper.updateProduct(product);
      if (success > 0) {
        // Actualizar en la lista local
        final index = _products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _products[index] = product;
        }
        print("ProductProvider: Producto actualizado exitosamente");
        return true;
      }
      return false;
    } catch (e) {
      print("ProductProvider: Error en updateProduct: $e");
      _error = 'Error al actualizar producto: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      print("ProductProvider: Iniciando deleteProduct");
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _dbHelper.deleteProduct(id);
      if (success > 0) {
        // Eliminar de la lista local
        _products.removeWhere((p) => p.id == id);
        print("ProductProvider: Producto eliminado exitosamente");
        return true;
      }
      return false;
    } catch (e) {
      print("ProductProvider: Error en deleteProduct: $e");
      _error = 'Error al eliminar producto: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> getProductStock(int productId) async {
    try {
      return await _dbHelper.getProductStock(productId);
    } catch (e) {
      print("ProductProvider: Error obteniendo stock para producto $productId: $e");
      return 0;
    }
  }

  // Método para forzar una recarga de productos
  Future<void> refreshProducts() async {
    print("ProductProvider: Forzando recarga de productos");
    await loadProducts();
  }
} 