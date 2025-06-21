import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import 'login_page.dart';
import 'register_page.dart';
import '../home/home_page.dart';
import '../onboarding/onboarding_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      // Hacemos varias comprobaciones asíncronas a la vez
      future: _getInitialState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final data = snapshot.data ?? {};
        final onboardingCompleted = data['onboardingCompleted'] ?? false;
        final hasUsers = data['hasUsers'] ?? false;
        final isAuthenticated = Provider.of<AuthProvider>(context, listen: false).isAuthenticated;

        // 1. Si no ha completado el onboarding, es lo primero que debe hacer.
        if (!onboardingCompleted) {
          return const OnboardingScreen();
        }

        // 2. Si completó onboarding pero no hay usuarios, debe registrar el primero.
        if (!hasUsers) {
          return const RegisterPage();
        }

        // 3. Si hay usuarios y está autenticado, va al Home.
        if (isAuthenticated) {
          return const HomePage();
        }

        // 4. Si hay usuarios pero no está autenticado, va al Login.
        return const LoginPage();
      },
    );
  }

  Future<Map<String, bool>> _getInitialState() async {
    final dbHelper = DatabaseHelper();
    // Verificamos en paralelo si el onboarding se completó y si existen usuarios.
    final results = await Future.wait([
      dbHelper.isOnboardingCompleted(),
      dbHelper.hasUsers(),
    ]);
    return {
      'onboardingCompleted': results[0],
      'hasUsers': results[1],
    };
  }
} 