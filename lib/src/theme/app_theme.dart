import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      surface: AppColors.backgroundColor,
      error: AppColors.errorColor,
      onPrimary: Colors.white, // Color de texto sobre primario
      onSecondary: Colors.black, // Color de texto sobre secundario
      onSurface: AppColors.textColor, // Color de texto sobre superficie
      onError: Colors.white, // Color de texto sobre error
    ),
    appBarTheme: const AppBarTheme(
      color: AppColors.primaryColor,
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textColor),
      bodyMedium: TextStyle(color: AppColors.textColor),
      // Define otros estilos de texto si es necesario
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: AppColors.primaryColor,
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
    ),
    // Puedes añadir más personalizaciones de tema aquí
  );

  // Podrías definir un darkTheme aquí si fuera necesario
  // static final ThemeData darkTheme = ThemeData(...);

  AppTheme._(); // Constructor privado
} 