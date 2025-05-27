import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_helper.dart';
import '../../models/sale.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Estado para el reporte personalizado
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  // Estado para los datos
  List<Sale>? _sales;
  Map<String, dynamic>? _summary;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      _summary = null;
    });

    try {
      List<Sale> sales;
      switch (_tabController.index) {
        case 0: // Diario
          sales = await _dbHelper.getSalesToday();
          break;
        case 1: // Semanal
          sales = await _dbHelper.getSalesThisWeek();
          break;
        case 2: // Mensual
          sales = await _dbHelper.getSalesThisMonth();
          break;
        case 3: // Personalizado
          sales = await _dbHelper.getSalesByDateRange(_startDate, _endDate);
          break;
        default:
          sales = await _dbHelper.getSalesToday();
      }

      // Obtener el resumen de ventas
      final DateTime startDate, endDate;
      switch (_tabController.index) {
        case 0: // Diario
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 1: // Semanal
          final now = DateTime.now();
          final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 2: // Mensual
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 3: // Personalizado
          startDate = _startDate;
          endDate = _endDate;
          break;
        default:
          final now = DateTime.now();
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      }

      final summary = await _dbHelper.getSalesSummary(startDate, endDate);

      setState(() {
        _sales = sales;
        _summary = summary;
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
      case 0: // Diario - por hora
        dateFormatPattern = 'HH:mm';
        break;
      case 1: // Semanal - por día de la semana
        dateFormatPattern = 'EEE';
        break;
      case 2: // Mensual - por día del mes
        dateFormatPattern = 'dd/MM';
        break;
      case 3: // Personalizado
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
    if (_tabController.index == 1) {
      // Para el semanal, ordenar por día de la semana
      final daysOrder = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      sortedDates.sort((a, b) => 
        daysOrder.indexOf(a) > -1 && daysOrder.indexOf(b) > -1 
          ? daysOrder.indexOf(a).compareTo(daysOrder.indexOf(b))
          : a.compareTo(b)
      );
    } else {
      sortedDates.sort();
    }
    
    // Generar spots para el gráfico
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      spots.add(FlSpot(i.toDouble(), salesByDate[date]!));
    }

    // Preparar título según tipo de reporte
    String chartTitle;
    switch (_tabController.index) {
      case 0:
        chartTitle = 'Ventas del día por hora';
        break;
      case 1:
        chartTitle = 'Ventas por día de la semana';
        break;
      case 2:
        chartTitle = 'Ventas por día del mes';
        break;
      case 3:
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Ventas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Diario'),
            Tab(text: 'Semanal'),
            Tab(text: 'Mensual'),
            Tab(text: 'Personalizado'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReportTab('Reporte Diario', null),
                _buildReportTab('Reporte Semanal', null),
                _buildReportTab('Reporte Mensual', null),
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
} 