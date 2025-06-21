import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:posve/src/screens/settings/terms_of_service_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final List<Widget> onboardingPages = [
      _buildPage(
        icon: Icons.store,
        title: 'Bienvenido a POSVE',
        description: 'La solución completa para gestionar tu punto de venta. Controla tu inventario, ventas, clientes y más, todo en un solo lugar.',
      ),
      _buildPage(
        icon: Icons.inventory_2,
        title: 'Gestión de Inventario Fácil',
        description: 'Añade productos, gestiona el stock y recibe alertas cuando tus productos estén por agotarse. Nunca pierdas una venta por falta de inventario.',
      ),
      _buildPage(
        icon: Icons.point_of_sale,
        title: 'Proceso de Venta Rápido',
        description: 'Realiza ventas de forma rápida y eficiente. Registra múltiples métodos de pago y genera recibos para tus clientes al instante.',
      ),
      _buildTermsPage(), // Página de términos y condiciones
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: onboardingPages,
              ),
            ),
            _buildControls(onboardingPages.length),
          ],
                        ),
                      ),
                    );
  }

  Widget _buildPage({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTermsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
          Text('Acuerdo de Servicio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SingleChildScrollView(
                child: Text(
                  // Resumen del acuerdo
                  'Antes de continuar, es importante que entiendas que POSVE es una herramienta para control interno y no es un sistema de facturación homologado por el SENIAT. El uso de esta app para fines fiscales es tu responsabilidad. Te recomendamos leer el acuerdo completo.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
            child: Text(
              'Leer Acuerdo de Servicio Completo',
              style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 16),
          Row(
      children: [
              Checkbox(
                value: _termsAccepted,
            onChanged: (value) {
                  setState(() {
                    _termsAccepted = value ?? false;
                  });
                },
              ),
              const Expanded(child: Text('He leído y acepto el Acuerdo de Servicio.')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(int pageCount) {
    bool isLastPage = _currentPage == pageCount - 1;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          Row(
            children: List.generate(pageCount, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              );
            }),
          ),
          ElevatedButton(
            onPressed: () {
              if (isLastPage) {
                if (_termsAccepted) {
                  _finishOnboarding();
                }
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastPage && !_termsAccepted ? Colors.grey : Theme.of(context).primaryColor,
            ),
            child: Text(isLastPage ? 'Comenzar a Usar' : 'Siguiente'),
          ),
        ],
      ),
    );
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/register');
    }
  }
} 