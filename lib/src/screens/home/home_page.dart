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
import '../settings/activate_license_page.dart';
import '../admin/user_management_page.dart';
import '../admin/database_settings_page.dart';
import '../expenses/expense_list_page.dart';
import '../expenses/expense_form_page.dart';
import '../expenses/expense_month_list_page.dart';
import 'package:posve/src/screens/settings/terms_of_service_page.dart';

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
        _dbHelper.getExpensesToday(),
        _dbHelper.getExpensesThisMonth(),
      ]);

      final todaySales = futures[0] as List;
      final products = futures[1] as List;
      final monthSales = futures[2] as List;
      final exchangeRate = futures[3] as double;
      final todayExpenses = futures[4] as List;
      final monthExpenses = futures[5] as List;

      // Calcular métricas
      double todayTotal = 0;
      double monthTotal = 0;
      double todayExpensesTotal = 0;
      double monthExpensesTotal = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;
      double totalInventoryValueUsd = 0;
      double totalInventoryValueVes = 0;

      for (var sale in todaySales) {
        todayTotal += sale.total;
      }

      for (var sale in monthSales) {
        monthTotal += sale.total;
      }

      for (var expense in todayExpenses) {
        todayExpensesTotal += expense.amount;
      }

      for (var expense in monthExpenses) {
        monthExpensesTotal += expense.amount;
      }

      // Calcular métricas de inventario
      for (var product in products) {
        // Contar productos con stock bajo
        if (product.currentStock <= product.minStock && product.currentStock > 0) {
          lowStockCount++;
        }
        // Contar productos sin stock
        if (product.currentStock == 0) {
          outOfStockCount++;
        }
        // Calcular valor total del inventario (usando precio de costo)
        totalInventoryValueUsd += product.costPriceUsd * product.currentStock;
        totalInventoryValueVes += (product.costPriceUsd * exchangeRate) * product.currentStock;
      }

      setState(() {
        _metrics = {
          'todaySales': todaySales.length,
          'todayTotal': todayTotal,
          'monthTotal': monthTotal,
          'totalProducts': products.length,
          'lowStockCount': lowStockCount,
          'outOfStockCount': outOfStockCount,
          'totalInventoryValueUsd': totalInventoryValueUsd,
          'totalInventoryValueVes': totalInventoryValueVes,
          'exchangeRate': exchangeRate,
          'todayExpenses': todayExpenses.length,
          'todayExpensesTotal': todayExpensesTotal,
          'monthExpensesTotal': monthExpensesTotal,
        };
        _isLoadingMetrics = false;
      });
    } catch (e) {
      print('Error cargando métricas: $e');
      setState(() => _isLoadingMetrics = false);
    }
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((result) {
      // Recargar métricas cuando se regrese de páginas que pueden haber modificado ventas o compras
      final pageType = page.runtimeType.toString();
      if (pageType.contains('Sales') || pageType.contains('Purchase')) {
        _loadMetrics();
      }
      // Si es PurchaseOrderPage y el resultado es true, refrescar métricas
      if (pageType == 'PurchaseOrderPage' && result == true) {
        _loadMetrics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POSVE - Gestión de Inventario'),
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Controla tu inventario de forma eficiente',
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
          title: 'Métricas de Inventario',
          icon: Icons.inventory_2,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            MetricCard(
              title: 'Total Productos',
              value: _isLoadingMetrics ? '...' : '${_metrics['totalProducts'] ?? 0}',
              icon: Icons.inventory_2,
              color: AppColors.primaryColor,
              subtitle: 'En inventario',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ProductListPage()),
            ),
            MetricCard(
              title: 'Stock Bajo',
              value: _isLoadingMetrics ? '...' : '${_metrics['lowStockCount'] ?? 0}',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warningColor,
              subtitle: 'Requieren atención',
              isLoading: _isLoadingMetrics,
              onTap: () {
                // Navegar a productos con filtro de stock bajo
                _navigateTo(context, const ProductListPage());
              },
            ),
            MetricCard(
              title: 'Sin Stock',
              value: _isLoadingMetrics ? '...' : '${_metrics['outOfStockCount'] ?? 0}',
              icon: Icons.error_outline,
              color: AppColors.errorColor,
              subtitle: 'Agotados',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ProductListPage()),
            ),
            MetricCard(
              title: 'Valor Inventario',
              value: _isLoadingMetrics ? '...' : _currencyFormatter.format(_metrics['totalInventoryValueUsd'] ?? 0),
              icon: Icons.attach_money,
              color: AppColors.accentColor,
              subtitle: _currencyFormatterVes.format(_metrics['totalInventoryValueVes'] ?? 0),
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ProductListPage()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Métricas de Operaciones',
          icon: Icons.analytics,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            MetricCard(
              title: 'Ventas del Mes',
              value: _isLoadingMetrics ? '...' : _currencyFormatter.format(_metrics['monthTotal'] ?? 0),
              icon: Icons.trending_up,
              color: AppColors.saleColor,
              subtitle: '${_metrics['todaySales'] ?? 0} hoy',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const SalesListPage(filterPeriod: 'month')),
            ),
            MetricCard(
              title: 'Gastos del Mes',
              value: _isLoadingMetrics ? '...' : _currencyFormatter.format(_metrics['monthExpensesTotal'] ?? 0),
              icon: Icons.trending_down,
              color: AppColors.expenseColor,
              subtitle: '${_metrics['todayExpenses'] ?? 0} hoy',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ExpenseMonthListPage()),
            ),
            MetricCard(
              title: 'Tasa de Cambio',
              value: _isLoadingMetrics ? '...' : '${_metrics['exchangeRate']?.toStringAsFixed(2) ?? '0.00'}',
              icon: Icons.currency_exchange,
              color: AppColors.secondaryColor,
              subtitle: 'USD → VES',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const ExchangeRatePage()),
            ),
            MetricCard(
              title: 'Movimientos',
              value: _isLoadingMetrics ? '...' : 'Ver',
              icon: Icons.sync_alt,
              color: AppColors.accentColor,
              subtitle: 'Historial completo',
              isLoading: _isLoadingMetrics,
              onTap: () => _navigateTo(context, const MovementListPage()),
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
                title: 'Gestionar Inventario',
                icon: Icons.inventory_2,
                color: AppColors.primaryColor,
                onTap: () => _navigateTo(context, const ProductListPage()),
              ),
              ActionCard(
                title: 'Agregar Producto',
                icon: Icons.add_box,
                color: AppColors.primaryColor,
                onTap: () => _navigateTo(context, const ProductListPage()),
              ),
              ActionCard(
                title: 'Ver Movimientos',
                icon: Icons.sync_alt,
                color: AppColors.accentColor,
                onTap: () => _navigateTo(context, const MovementListPage()),
              ),
              ActionCard(
                title: 'Compras - Entradas',
                icon: Icons.shopping_cart_checkout,
                color: AppColors.purchaseColor,
                onTap: () => _navigateTo(context, const PurchaseOrderPage()),
              ),
              ActionCard(
                title: 'Nueva Venta',
                icon: Icons.point_of_sale,
                color: AppColors.saleColor,
                onTap: () => _navigateTo(context, const SalesOrderPage()),
              ),
              ActionCard(
                title: 'Nuevo Gasto',
                icon: Icons.receipt_long,
                color: AppColors.expenseColor,
                onTap: () => _navigateTo(context, const ExpenseFormPage()),
              ),
              ActionCard(
                title: 'Reportes',
                icon: Icons.bar_chart,
                color: AppColors.secondaryColor,
                onTap: () => _navigateTo(context, const ReportsPage()),
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
          title: 'Inventario',
          icon: Icons.inventory_2,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Productos',
                subtitle: 'Gestionar inventario completo',
                onTap: () => _navigateTo(context, const ProductListPage()),
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
                subtitle: 'Historial de entradas y salidas',
                onTap: () => _navigateTo(context, const MovementListPage()),
              ),
              _buildActionTile(
                icon: Icons.people_outline,
                title: 'Proveedores',
                subtitle: 'Gestionar proveedores',
                onTap: () => _navigateTo(context, const SupplierListPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const SectionHeader(
          title: 'Operaciones',
          icon: Icons.point_of_sale,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.point_of_sale_outlined,
                title: 'Ventas',
                subtitle: 'Registrar y consultar ventas',
                iconColor: AppColors.saleColor,
                onTap: () => _navigateTo(context, const SalesListPage()),
              ),
              _buildActionTile(
                icon: Icons.shopping_cart_outlined,
                title: 'Compras - Entradas',
                subtitle: 'Registrar compras y entradas de inventario',
                iconColor: AppColors.purchaseColor,
                onTap: () => _navigateTo(context, const PurchaseOrderPage()),
              ),
              _buildActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'Gastos',
                subtitle: 'Gestionar gastos operativos',
                onTap: () => _navigateTo(context, const ExpenseListPage()),
              ),
              _buildActionTile(
                icon: Icons.person_outline,
                title: 'Clientes',
                subtitle: 'Gestionar clientes',
                onTap: () => _navigateTo(context, const ClientListPage()),
              ),
              _buildActionTile(
                icon: Icons.bar_chart_outlined,
                title: 'Reportes',
                subtitle: 'Generar y exportar reportes',
                onTap: () => _navigateTo(context, const ReportsPage()),
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
              _buildActionTile(
                icon: Icons.vpn_key_outlined,
                title: 'Activar Licencia',
                subtitle: 'Gestionar licencia',
                onTap: () => _navigateTo(context, const ActivateLicensePage()),
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
    Color? iconColor,
  }) {
    final color = iconColor ?? AppColors.primaryColor;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
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
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    width: 40,
                  )
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Inventario', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Productos'),
            onTap: () => _navigateTo(context, const ProductListPage()),
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
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Proveedores'),
            onTap: () => _navigateTo(context, const SupplierListPage()),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Operaciones', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale_outlined),
            title: const Text('Ventas'),
            onTap: () => _navigateTo(context, const SalesListPage()),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Compras - Entradas'),
            onTap: () => _navigateTo(context, const PurchaseOrderPage()),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Gastos'),
            onTap: () => _navigateTo(context, const ExpenseListPage()),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Clientes'),
            onTap: () => _navigateTo(context, const ClientListPage()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reportes'),
            onTap: () => _navigateTo(context, const ReportsPage()),
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
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Activar Licencia'),
            onTap: () => _navigateTo(context, const ActivateLicensePage()),
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
            leading: const Icon(Icons.description_outlined),
            title: const Text('Acuerdo de Servicio'),
            onTap: () => _navigateTo(context, const TermsOfServicePage()),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Cerrar Sesión', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
