import 'package:flutter/material.dart';

class AppColors {
  // Colores principales más modernos y atractivos
  static const Color primaryColor = Color(0xFF2196F3); // Azul moderno
  static const Color primaryLightColor = Color(0xFF64B5F6); // Azul claro
  static const Color primaryDarkColor = Color(0xFF1976D2); // Azul oscuro
  
  static const Color secondaryColor = Color(0xFF4CAF50); // Verde éxito
  static const Color secondaryLightColor = Color(0xFF81C784); // Verde claro
  static const Color secondaryDarkColor = Color(0xFF388E3C); // Verde oscuro
  
  static const Color accentColor = Color(0xFFFF9800); // Naranja acción
  static const Color accentLightColor = Color(0xFFFFB74D); // Naranja claro
  
  // Colores de fondo
  static const Color backgroundColor = Color(0xFFF5F5F5); // Gris muy claro
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  
  // Colores de texto
  static const Color textColor = Color(0xFF212121); // Gris oscuro
  static const Color textLightColor = Color(0xFF757575); // Gris medio
  static const Color textMutedColor = Color(0xFF9E9E9E); // Gris claro
  
  // Colores de estado
  static const Color errorColor = Color(0xFFF44336); // Rojo error
  static const Color successColor = Color(0xFF4CAF50); // Verde éxito
  static const Color warningColor = Color(0xFFFF9800); // Naranja advertencia
  static const Color infoColor = Color(0xFF2196F3); // Azul información
  
  // Colores para ventas y compras
  static const Color saleColor = Color(0xFF4CAF50); // Verde para ventas
  static const Color purchaseColor = Color(0xFF2196F3); // Azul para compras
  static const Color stockLowColor = Color(0xFFFF5722); // Rojo para stock bajo
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLightColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [successColor, secondaryLightColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    colors: [warningColor, accentLightColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Privado constructor para prevenir instanciación
  AppColors._();
} 