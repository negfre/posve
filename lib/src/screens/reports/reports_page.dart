import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_helper.dart';
import '../../models/sale.dart';
import '../../models/expense.dart';
import '../../models/product.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_colors.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Estado para el reporte personalizado
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Estado para los datos
  List<Sale>? _sales;
  List<Expense>? _expenses;
  List<Product>? _products;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _expensesSummary;
  Map<String, dynamic>? _profitabilityData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _sales = null;
      _expenses = null;
      _products = null;
      _summary = null;
      _expensesSummary = null;
      _profitabilityData = null;
    });

    try {
      // Determinar fechas según el período seleccionado
      final DateTime startDate, endDate;
      switch (_tabController.index) {
        case 0: // Dashboard Ejecutivo
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 1: // Ventas
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 2: // Rentabilidad
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 3: // Productos
          startDate = DateTime(2021);
          endDate = DateTime.now();
          break;
        case 4: // Personalizado
          startDate = _startDate;
          endDate = _endDate;
          break;
        default:
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      }

      // Cargar datos en paralelo
      final futures = await Future.wait([
        _dbHelper.getSalesByDateRange(startDate, endDate),
        _dbHelper.getExpensesByDateRange(startDate, endDate),
        _dbHelper.getProducts(),
        _dbHelper.getSalesSummary(startDate, endDate),
        _dbHelper.getExpensesSummary(startDate, endDate),
      ]);

      final sales = futures[0] as List<Sale>;
      final expenses = futures[1] as List<Expense>;
      final products = futures[2] as List<Product>;
      final salesSummary = futures[3] as Map<String, dynamic>;
      final expensesSummary = futures[4] as Map<String, dynamic>;

      // Calcular métricas de rentabilidad
      final totalRevenue = salesSummary['total_amount'] ?? 0.0;
      final totalExpenses = expensesSummary['total_amount'] ?? 0.0;
      final grossProfit = totalRevenue - totalExpenses;
      final profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

      // Calcular métricas de productos
      final lowStockProducts = products.where((p) => p.currentStock <= p.minStock).length;
      final outOfStockProducts = products.where((p) => p.currentStock == 0).length;

      final profitabilityData = {
        'total_revenue': totalRevenue,
        'total_expenses': totalExpenses,
        'gross_profit': grossProfit,
        'profit_margin': profitMargin,
        'total_sales_count': sales.length,
        'total_expenses_count': expenses.length,
        'low_stock_products': lowStockProducts,
        'out_of_stock_products': outOfStockProducts,
        'total_products': products.length,
      };

      setState(() {
        _sales = sales;
        _expenses = expenses;
        _products = products;
        _summary = salesSummary;
        _expensesSummary = expensesSummary;
        _profitabilityData = profitabilityData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar datos del reporte: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2021),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  Widget _buildExecutiveDashboard() {
    if (_profitabilityData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con período
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.analytics, color: AppColors.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Ejecutivo',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          'Período: ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadReportData,
                    tooltip: 'Actualizar datos',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Métricas principales
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildMetricCard(
                'Ingresos Totales',
                currencyFormat.format(_profitabilityData!['total_revenue']),
                Icons.trending_up,
                AppColors.saleColor,
                'Ventas del mes',
              ),
              _buildMetricCard(
                'Gastos Totales',
                currencyFormat.format(_profitabilityData!['total_expenses']),
                Icons.trending_down,
                AppColors.expenseColor,
                'Gastos del mes',
              ),
              _buildMetricCard(
                'Utilidad Bruta',
                currencyFormat.format(_profitabilityData!['gross_profit']),
                Icons.account_balance_wallet,
                _profitabilityData!['gross_profit'] >= 0 ? Colors.green : Colors.red,
                'Ingresos - Gastos',
              ),
              _buildMetricCard(
                'Margen de Utilidad',
                percentFormat.format(_profitabilityData!['profit_margin'] / 100),
                Icons.percent,
                _profitabilityData!['profit_margin'] >= 0 ? Colors.green : Colors.red,
                'Porcentaje de utilidad',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Métricas secundarias
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Ventas Realizadas',
                  '${_profitabilityData!['total_sales_count']}',
                  Icons.receipt_long,
                  AppColors.secondaryColor,
                  'Transacciones',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Productos con Stock Bajo',
                  '${_profitabilityData!['low_stock_products']}',
                  Icons.warning,
                  Colors.orange,
                  'Necesitan reposición',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfico de tendencia de utilidad
          if (_sales != null && _sales!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendencia de Ventas del Mes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: _buildSalesTrendChart(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Alertas y recomendaciones
          _buildAlertsAndRecommendations(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsAndRecommendations() {
    final alerts = <Widget>[];
    
    if (_profitabilityData != null) {
      // Alerta de utilidad negativa
      if (_profitabilityData!['gross_profit'] < 0) {
        alerts.add(_buildAlertCard(
          '⚠️ Utilidad Negativa',
          'Tu negocio está operando con pérdidas este mes. Revisa tus gastos y estrategia de precios.',
          Colors.red,
          Icons.warning,
        ));
      }

      // Alerta de stock bajo
      if (_profitabilityData!['low_stock_products'] > 0) {
        alerts.add(_buildAlertCard(
          '📦 Stock Bajo',
          '${_profitabilityData!['low_stock_products']} productos necesitan reposición urgente.',
          Colors.orange,
          Icons.inventory_2,
        ));
      }

      // Alerta de margen bajo
      if (_profitabilityData!['profit_margin'] < 10) {
        alerts.add(_buildAlertCard(
          '📊 Margen Bajo',
          'Tu margen de utilidad está por debajo del 10%. Considera ajustar precios o reducir costos.',
          Colors.amber,
          Icons.trending_down,
        ));
      }

      // Recomendación positiva
      if (_profitabilityData!['gross_profit'] > 0 && _profitabilityData!['profit_margin'] > 15) {
        alerts.add(_buildAlertCard(
          '🎉 Excelente Rendimiento',
          'Tu negocio está generando buenas utilidades. ¡Mantén esta tendencia!',
          Colors.green,
          Icons.thumb_up,
        ));
      }
    }

    if (alerts.isEmpty) {
      alerts.add(_buildAlertCard(
        '📈 Sin Alertas',
        'Tu negocio está funcionando bien. Continúa monitoreando las métricas.',
        Colors.blue,
        Icons.check_circle,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alertas y Recomendaciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...alerts,
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(String title, String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendChart() {
    if (_sales == null || _sales!.isEmpty) {
      return const Center(child: Text('No hay datos de ventas'));
    }

    // Agrupar ventas por día
    final Map<String, double> salesByDay = {};
    final dateFormat = DateFormat('dd/MM');
    
    for (final sale in _sales!) {
      final dayKey = dateFormat.format(sale.saleDate);
      salesByDay[dayKey] = (salesByDay[dayKey] ?? 0) + sale.total;
    }

    // Ordenar por fecha
    final sortedDays = salesByDay.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    for (int i = 0; i < sortedDays.length; i++) {
      spots.add(FlSpot(i.toDouble(), salesByDay[sortedDays[i]]!));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedDays.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedDays[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primaryColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryColor.withOpacity(0.2),
            ),
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Ventas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard Ejecutivo'),
            Tab(text: 'Ventas'),
            Tab(text: 'Rentabilidad'),
            Tab(text: 'Productos'),
            Tab(text: 'Personalizado'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildExecutiveDashboard(),
                _buildReportTab('Reporte Ventas', null),
                _buildReportTab('Reporte Rentabilidad', null),
                _buildReportTab('Reporte Productos', null),
                _buildReportTab(
                  'Reporte Personalizado',
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Desde: ${DateFormat('dd/MM/yyyy').format(_startDate)} - Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () => _selectDateRange(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción para exportar reporte si se desea
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exportación de reportes en desarrollo')),
          );
        },
        tooltip: 'Exportar Reporte',
        child: const Icon(Icons.share),
      ),
    );
  }

  Widget _buildReportTab(String title, Widget? additionalHeader) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (additionalHeader != null) ...[
              const SizedBox(height: 8),
              additionalHeader,
            ],
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            if (_sales != null && _sales!.isNotEmpty) ...[
              _buildChart(),
              const SizedBox(height: 16),
              const Text(
                'Detalle de Ventas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
            ],
            _buildSalesTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_summary == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No hay datos disponibles'),
          ),
        ),
      );
    }

    // Formateador para números y moneda
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Ventas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryRow('Total de ventas:', '${_summary!['total_sales']}'),
            _buildSummaryRow('Monto total (USD):', currencyFormat.format(_summary!['total_amount'])),
            _buildSummaryRow('Monto promedio (USD):', currencyFormat.format(_summary!['avg_amount'])),
            _buildSummaryRow('Total IVA (USD):', currencyFormat.format(_summary!['total_tax'])),
            const SizedBox(height: 16),
            if (_summary!['payment_methods'] is Map && (_summary!['payment_methods'] as Map).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Métodos de Pago',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text('Método', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Monto', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ..._buildPaymentMethodsList(
                          _summary!['payment_methods'] as Map<String, dynamic>,
                          _summary!['payment_methods_amounts'] as Map<String, dynamic>,
                          currencyFormat,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentMethodsList(
    Map<String, dynamic> paymentMethods,
    Map<String, dynamic> paymentMethodsAmounts,
    NumberFormat currencyFormat,
  ) {
    final List<Widget> widgets = [];
    
    // Crear una lista de entradas para ordenar por monto
    final entries = <MapEntry<String, dynamic>>[];
    paymentMethods.forEach((method, count) {
      final amount = paymentMethodsAmounts[method] ?? 0.0;
      entries.add(MapEntry(method, {'count': count, 'amount': amount}));
    });
    
    // Ordenar por monto, de mayor a menor
    entries.sort((a, b) => (b.value['amount'] as double).compareTo(a.value['amount'] as double));
    
    // Crear los widgets con datos ordenados
    for (var entry in entries) {
      final method = entry.key;
      final count = entry.value['count'];
      final amount = entry.value['amount'] as double;
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(method),
              ),
              Expanded(
                flex: 2,
                child: Text('$count', textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  currencyFormat.format(amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildSalesTable() {
    if (_sales == null || _sales!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No hay ventas en este período'),
        ),
      );
    }

    // Formateador para fechas y moneda
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Factura')),
          DataColumn(label: Text('Cliente')),
          DataColumn(label: Text('Método de Pago')),
          DataColumn(label: Text('Total')),
        ],
        rows: _sales!.map((sale) {
          final clientName = sale.client?.name ?? 'Consumidor Final';
          final paymentMethod = sale.paymentMethod?.name ?? 'Desconocido';
          
          return DataRow(cells: [
            DataCell(Text(dateFormat.format(sale.saleDate))),
            DataCell(Text(sale.invoiceNumber)),
            DataCell(Text(clientName)),
            DataCell(Text(paymentMethod)),
            DataCell(Text(currencyFormat.format(sale.total))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    if (_sales == null || _sales!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Agrupar ventas por fecha
    final Map<String, double> salesByDate = {};
    final dateOnlyFormat = DateFormat('dd/MM');
    
    // Determinar formato según el período
    String dateFormatPattern;
    switch (_tabController.index) {
      case 1: // Ventas
        dateFormatPattern = 'dd/MM';
        break;
      case 2: // Rentabilidad
        dateFormatPattern = 'dd/MM';
        break;
      case 3: // Productos
        dateFormatPattern = 'MM/yy';
        break;
      case 4: // Personalizado
        // Si el rango es más de 60 días, mostrar por mes
        final difference = _endDate.difference(_startDate).inDays;
        dateFormatPattern = difference > 60 ? 'MM/yy' : (difference > 14 ? 'dd/MM' : 'EEE dd/MM');
        break;
      default:
        dateFormatPattern = 'dd/MM';
    }
    
    final dateFormat = DateFormat(dateFormatPattern);
    
    for (final sale in _sales!) {
      final dateKey = dateFormat.format(sale.saleDate);
      salesByDate[dateKey] = (salesByDate[dateKey] ?? 0) + sale.total;
    }

    // Crear puntos para el gráfico
    final List<FlSpot> spots = [];
    
    // Ordenar fechas basado en la fecha real, no alfabéticamente
    final sortedDates = salesByDate.keys.toList();
    sortedDates.sort();
    
    // Generar spots para el gráfico
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      spots.add(FlSpot(i.toDouble(), salesByDate[date]!));
    }

    // Preparar título según tipo de reporte
    String chartTitle;
    switch (_tabController.index) {
      case 1:
        chartTitle = 'Ventas por día del mes';
        break;
      case 2:
        chartTitle = 'Tendencia de rentabilidad';
        break;
      case 3:
        chartTitle = 'Ventas por mes';
        break;
      case 4:
        chartTitle = 'Ventas del período seleccionado';
        break;
      default:
        chartTitle = 'Tendencia de ventas';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            chartTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Container(
          height: 240,
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            sortedDates[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 