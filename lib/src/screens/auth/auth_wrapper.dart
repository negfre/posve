import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import '../../services/license_service.dart';
import 'login_page.dart';
import '../home/home_page.dart'; // Importa la HomePage (incluso si es temporal)
import '../onboarding/onboarding_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final LicenseService _licenseService = LicenseService();

  @override
  void initState() {
    super.initState();
    // Verificar licencia después de un breve delay para asegurar que el contexto esté listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLicense();
    });
  }

  Future<void> _checkLicense() async {
    try {
      await _licenseService.checkLicenseOnStartup(context);
    } catch (e) {
      print('Error verificando licencia: $e');
    }
  }

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