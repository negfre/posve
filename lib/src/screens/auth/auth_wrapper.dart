import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import 'login_page.dart';
import '../home/home_page.dart'; // Importa la HomePage (incluso si es temporal)
import '../onboarding/onboarding_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Si no está autenticado, mostrar login
    if (!authProvider.isAuthenticated) {
      return const LoginPage();
    }

    // Si está autenticado, verificar si necesita onboarding
    return FutureBuilder<bool>(
      future: DatabaseHelper().isOnboardingCompleted(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final needsOnboarding = !(snapshot.data ?? false);
        print("--- AuthWrapper: needsOnboarding = $needsOnboarding ---");

        // Si necesita onboarding y está autenticado, mostrar onboarding
        if (needsOnboarding) {
          return const OnboardingScreen();
        }

        // Si no necesita onboarding y está autenticado, mostrar home
        return const HomePage();
      },
    );
  }
} 