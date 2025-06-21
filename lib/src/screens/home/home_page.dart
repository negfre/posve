import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import '../../widgets/modern_widgets.dart';
import '../../constants/app_colors.dart';
import 'package:intl/intl.dart';

// Importaciones de páginas
import '../sales/sales_order_page.dart';
import '../purchases/purchase_order_page.dart';
import '../sales/sales_list_page.dart';
import '../reports/reports_page.dart';
import '../products/product_list_page.dart';
import '../suppliers/supplier_list_page.dart';
import '../clients/client_list_page.dart';
import '../categories/category_list_page.dart';
import '../movements/movement_list_page.dart';
import '../settings/exchange_rate_page.dart';
import '../settings/payment_methods_screen.dart';
import '../settings/tax_settings_page.dart';
import '../admin/user_management_page.dart';
import '../admin/database_settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthProvider authProvider = AuthProvider();
  
  // Estado para métricas
  Map<String, dynamic> _metrics = {};
  bool _isLoadingMetrics = true;
  
  // Formateadores
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    
    try {
      // Cargar métricas en paralelo
      final futures = await Future.wait([
        _dbHelper.getSalesToday(),
        _dbHelper.getProducts(),
        _dbHelper.getSalesThisMonth(),
        _dbHelper.getExchangeRate(),
      ]);

      final todaySales = futures[0] as List;
      final products = futures[1] as List;
      final monthSales = futures[2] as List;
      final exchangeRate = futures[3] as double;

      // Calcular métricas
      double todayTotal = 0;
      double monthTotal = 0;
      int lowStockCount = 0;

      for (var sale in todaySales) {
        todayTotal += sale.total;
      }

      for (var sale in monthSales) {
        monthTotal += sale.total;
      }

      for (var product in products) {
        if (product.currentStock <= product.minStock) {
          lowStockCount++;
        }
      }

      setState(() {
        _metrics = {
          'todaySales': todaySales.length,
          'todayTotal': todayTotal,
          'monthTotal': monthTotal,
          'totalProducts': products.length,
          'lowStockCount': lowStockCount,
          'exchangeRate': exchangeRate,
        };
        _isLoadingMetrics = false;
      });
    } catch (e) {
      print('Error cargando métricas: $e');
      setState(() => _isLoadingMetrics = false);
    }
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POSVE - Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Actualizar métricas',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con saludo
              _buildWelcomeHeader(),
              const SizedBox(height: 24),
              
              // Métricas principales
              _buildMetricsSection(),
              const SizedBox(height: 32),
              
              // Accesos rápidos
              _buildQuickActionsSection(),
              const SizedBox(height: 32),
              
              // Acciones principales
              _buildMainActionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    
    if (hour < 12) {
      greeting = '¡Buenos días!';
    } else if (hour < 18) {
      greeting = '¡Buenas tardes!';
    } else {
      greeting = '¡Buenas noches!';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.store,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bienvenido a tu sistema de gestión',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Métricas del Día',
          icon: Icons.analytics,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            MetricCard(
              title: 'Ventas Hoy',
              value: _isLoadingMetrics ? '...' : '${_metrics['todaySales'] ?? 0}',
              icon: Icons.point_of_sale,
              color: AppColors.saleColor,
              subtitle: _currencyFormatter.format(_metrics['todayTotal'] ?? 0),
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const SalesListPage()),
            ),
            MetricCard(
              title: 'Productos',
              value: _isLoadingMetrics ? '...' : '${_metrics['totalProducts'] ?? 0}',
              icon: Icons.inventory_2,
              color: AppColors.primaryColor,
              subtitle: '${_metrics['lowStockCount'] ?? 0} con stock bajo',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ProductListPage()),
            ),
            MetricCard(
              title: 'Ventas del Mes',
              value: _isLoadingMetrics ? '...' : _currencyFormatter.format(_metrics['monthTotal'] ?? 0),
              icon: Icons.trending_up,
              color: AppColors.secondaryColor,
              subtitle: 'Total acumulado',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ReportsPage()),
            ),
            MetricCard(
              title: 'Tasa de Cambio',
              value: _isLoadingMetrics ? '...' : '${_metrics['exchangeRate']?.toStringAsFixed(2) ?? '0.00'}',
              icon: Icons.currency_exchange,
              color: AppColors.accentColor,
              subtitle: 'USD → VES',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ExchangeRatePage()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Accesos Rápidos',
          icon: Icons.flash_on,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionCard(
                title: 'Nueva Venta',
                icon: Icons.point_of_sale,
                color: AppColors.saleColor,
                onTap: () => _navigateTo(context, const SalesOrderPage()),
              ),
              ActionCard(
                title: 'Registrar Compra',
                icon: Icons.shopping_cart_checkout,
                color: AppColors.purchaseColor,
                onTap: () => _navigateTo(context, const PurchaseOrderPage()),
              ),
              ActionCard(
                title: 'Ver Ventas',
                icon: Icons.receipt_long,
                color: AppColors.secondaryColor,
                onTap: () => _navigateTo(context, const SalesListPage()),
              ),
              ActionCard(
                title: 'Reportes',
                icon: Icons.bar_chart,
                color: AppColors.accentColor,
                onTap: () => _navigateTo(context, const ReportsPage()),
              ),
              ActionCard(
                title: 'Productos',
                icon: Icons.inventory_2,
                color: AppColors.primaryColor,
                onTap: () => _navigateTo(context, const ProductListPage()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Gestión del Negocio',
          icon: Icons.business,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Productos',
                subtitle: 'Gestionar inventario',
                onTap: () => _navigateTo(context, const ProductListPage()),
              ),
              _buildActionTile(
                icon: Icons.people_outline,
                title: 'Proveedores',
                subtitle: 'Gestionar proveedores',
                onTap: () => _navigateTo(context, const SupplierListPage()),
              ),
              _buildActionTile(
                icon: Icons.person_outline,
                title: 'Clientes',
                subtitle: 'Gestionar clientes',
                onTap: () => _navigateTo(context, const ClientListPage()),
              ),
              _buildActionTile(
                icon: Icons.category_outlined,
                title: 'Categorías',
                subtitle: 'Organizar productos',
                onTap: () => _navigateTo(context, const CategoryListPage()),
              ),
              _buildActionTile(
                icon: Icons.sync_alt_outlined,
                title: 'Movimientos',
                subtitle: 'Historial de stock',
                onTap: () => _navigateTo(context, const MovementListPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const SectionHeader(
          title: 'Configuración',
          icon: Icons.settings,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.currency_exchange_outlined,
                title: 'Tasa de Cambio',
                subtitle: 'Configurar USD/VES',
                onTap: () => _navigateTo(context, const ExchangeRatePage()),
              ),
              _buildActionTile(
                icon: Icons.payment_outlined,
                title: 'Formas de Pago',
                subtitle: 'Gestionar métodos',
                onTap: () => _navigateTo(context, const PaymentMethodsScreen()),
              ),
              _buildActionTile(
                icon: Icons.percent_outlined,
                title: 'Configuración IVA',
                subtitle: 'Ajustar impuestos',
                onTap: () => _navigateTo(context, const TaxSettingsPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const SectionHeader(
          title: 'Administración',
          icon: Icons.admin_panel_settings,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Gestión de Usuarios',
                subtitle: 'Administrar acceso',
                onTap: () => _navigateTo(context, const UserManagementPage()),
              ),
              _buildActionTile(
                icon: Icons.storage_outlined,
                title: 'Base de Datos',
                subtitle: 'Backup y configuración',
                onTap: () => _navigateTo(context, const DatabaseSettingsPage()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'POSVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sistema de Gestión',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Reportes'),
            onTap: null,
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
          const Divider(),
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
          const Divider(),
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
    );
  }
}
