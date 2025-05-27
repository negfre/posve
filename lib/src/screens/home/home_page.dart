import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/trial_service.dart';
import '../../constants/app_colors.dart';
import '../products/product_list_page.dart';
import '../suppliers/supplier_list_page.dart';
import '../movements/movement_list_page.dart';
import '../settings/exchange_rate_page.dart';
import '../categories/category_list_page.dart';
import '../clients/client_list_page.dart';
import '../purchases/purchase_order_page.dart';
import '../sales/sales_order_page.dart';
import '../sales/sales_list_page.dart';
import '../admin/user_management_page.dart';
import '../admin/database_settings_page.dart';
import '../settings/payment_methods_screen.dart';
import '../settings/tax_settings_page.dart';
import '../reports/reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TrialService _trialService = TrialService();
  late Future<TrialStatus> _trialStatusFuture;

  @override
  void initState() {
    super.initState();
    _trialStatusFuture = _trialService.checkTrialStatus();
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: color ?? Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: color ?? Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = authProvider.loggedInUserEmail ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS VE - Inicio'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: const Text("Gestión de Inventario"),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Inicio'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_checkout),
              title: const Text('Registrar Compra'),
              onTap: () => _navigateTo(context, const PurchaseOrderPage()),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.green),
              title: const Text('Registrar Venta'),
              tileColor: Colors.green.withOpacity(0.1),
              onTap: () {
                Navigator.pop(context);
                _navigateTo(context, const SalesOrderPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Listado de Ventas'),
              onTap: () => _navigateTo(context, const SalesListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reportes'),
              onTap: () => _navigateTo(context, const ReportsPage()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Productos'),
              onTap: () => _navigateTo(context, const ProductListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Proveedores'),
              onTap: () => _navigateTo(context, const SupplierListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Clientes'),
              onTap: () => _navigateTo(context, const ClientListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categorías'),
              onTap: () => _navigateTo(context, const CategoryListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.sync_alt_outlined),
              title: const Text('Movimientos'),
              onTap: () => _navigateTo(context, const MovementListPage()),
            ),
            const Divider(indent: 16, endIndent: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange_outlined),
              title: const Text('Tasa de Cambio'),
              onTap: () => _navigateTo(context, const ExchangeRatePage()),
            ),
            ListTile(
              leading: const Icon(Icons.payment_outlined),
              title: const Text('Formas de Pago'),
              onTap: () => _navigateTo(context, const PaymentMethodsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.percent_outlined),
              title: const Text('Configuración IVA'),
              onTap: () => _navigateTo(context, const TaxSettingsPage()),
            ),
            const Divider(indent: 16, endIndent: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Administración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Gestión de Usuarios'),
              onTap: () => _navigateTo(context, const UserManagementPage()),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Base de Datos'),
              onTap: () => _navigateTo(context, const DatabaseSettingsPage()),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Cerrar Sesión', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, $userEmail',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            FutureBuilder<TrialStatus>(
              future: _trialStatusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Text('Error al verificar estado del trial.', style: TextStyle(color: Colors.red));
                } else if (snapshot.hasData) {
                  final trialStatus = snapshot.data!;
                  String statusText;
                  Color statusColor;
                  IconData statusIcon;
                  switch (trialStatus.state) {
                    case TrialState.active:
                      final days = trialStatus.daysRemaining ?? 0;
                      statusText = ' $days día(s) restante(s).';
                      statusColor = AppColors.successColor;
                      statusIcon = Icons.check_circle_outline;
                      break;
                    case TrialState.expired:
                      statusText = ' Período Finalizado.';
                      statusColor = AppColors.errorColor;
                      statusIcon = Icons.error_outline;
                      break;
                    case TrialState.notStarted:
                      statusText = ' Período no iniciado.';
                      statusColor = Colors.grey;
                      statusIcon = Icons.help_outline;
                      break;
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 18),
                        const SizedBox(width: 6),
                        Text('Prueba:$statusText',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Accesos Rápidos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: ListView(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                children: [
                  _buildScrollableActionCard(
                    title: 'Registrar Compra',
                    icon: Icons.shopping_cart_checkout,
                    onTap: () => _navigateTo(context, const PurchaseOrderPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Registrar Venta',
                    icon: Icons.point_of_sale,
                    onTap: () => _navigateTo(context, const SalesOrderPage()),
                    color: Colors.green,
                  ),
                  _buildScrollableActionCard(
                    title: 'Ventas Realizadas',
                    icon: Icons.receipt_long,
                    onTap: () => _navigateTo(context, const SalesListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Reportes',
                    icon: Icons.bar_chart,
                    onTap: () => _navigateTo(context, const ReportsPage()),
                    color: Colors.blue,
                  ),
                  _buildScrollableActionCard(
                    title: 'Productos',
                    icon: Icons.inventory_2,
                    onTap: () => _navigateTo(context, const ProductListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Proveedores',
                    icon: Icons.people,
                    onTap: () => _navigateTo(context, const SupplierListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Clientes',
                    icon: Icons.person,
                    onTap: () => _navigateTo(context, const ClientListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Categorías',
                    icon: Icons.category,
                    onTap: () => _navigateTo(context, const CategoryListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Movimientos',
                    icon: Icons.sync_alt,
                    onTap: () => _navigateTo(context, const MovementListPage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Tasa Cambio',
                    icon: Icons.currency_exchange,
                    onTap: () => _navigateTo(context, const ExchangeRatePage()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Formas Pago',
                    icon: Icons.payment,
                    onTap: () => _navigateTo(context, const PaymentMethodsScreen()),
                  ),
                  _buildScrollableActionCard(
                    title: 'Configurar IVA',
                    icon: Icons.percent,
                    onTap: () => _navigateTo(context, const TaxSettingsPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
