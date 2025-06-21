import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:excel/excel.dart';

import '../../services/database_helper.dart';
import '../../models/sale.dart';
import '../../models/expense.dart';
import '../../models/product.dart';
import '../../constants/app_colors.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'Ventas';
  
  bool _isLoading = false;
  dynamic _reportData;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2021),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _reportData = null; // Reset data when date changes
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    
    dynamic data;
    try {
      switch (_selectedReportType) {
        case 'Ventas':
          data = await _dbHelper.getSalesByDateRange(_startDate, _endDate);
          break;
        case 'Gastos':
          data = await _dbHelper.getExpensesByDateRange(_startDate, _endDate);
          break;
        case 'Inventario':
          data = await _dbHelper.getProducts();
          break;
      }
    } catch (e) {
      print('Error generando reporte: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el reporte: $e'), backgroundColor: Colors.red)
        );
      }
    }
    
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generador de Reportes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
              children: [
            _buildControls(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_reportData != null)
              Expanded(child: _buildReportDataView())
            else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Selecciona los filtros y genera un reporte.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedReportType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Reporte',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assessment),
                    ),
                    items: ['Ventas', 'Gastos', 'Inventario']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedReportType = value;
                          _reportData = null; // Reset data on type change
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
                children: [
                const Icon(Icons.date_range),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Desde: ${DateFormat('dd/MM/yyyy').format(_startDate)}',
                  ),
                              ),
                              Expanded(
                  child: Text(
                    'Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: () => _selectDateRange(context),
                )
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Generar Reporte'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _generateReport,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_reportData == null || _reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Headers
    List<String> headers = [];
    if (_selectedReportType == 'Ventas') {
      headers = ['Factura', 'Cliente', 'Total', 'Fecha'];
    } else if (_selectedReportType == 'Gastos') {
      headers = ['Descripción', 'Monto', 'Fecha'];
    } else if (_selectedReportType == 'Inventario') {
      headers = ['Producto', 'Stock Actual', 'Precio de Venta (USD)'];
    }
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Data
    for (var item in _reportData) {
      List<dynamic> row = [];
      if (item is Sale) {
        row = [item.invoiceNumber, item.client?.name ?? 'N/A', item.total, item.saleDate.toIso8601String()];
      } else if (item is Expense) {
        row = [item.description, item.amount, item.expenseDate.toIso8601String()];
      } else if (item is Product) {
        row = [item.name, item.currentStock, item.sellingPriceUsd];
      }
      sheet.appendRow(row.map((e) {
        if (e is num) return DoubleCellValue(e.toDouble());
        return TextCellValue(e.toString());
      }).toList());
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/reporte_$_selectedReportType.xlsx';
    final fileBytes = excel.save();
    
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
        
      await Share.shareXFiles([XFile(filePath)], text: 'Reporte de $_selectedReportType');
    }
  }

  Future<void> _exportToCsv() async {
    if (_reportData == null || _reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    List<String> headers = [];
    if (_selectedReportType == 'Ventas') {
      headers = ['Factura', 'Cliente', 'Total', 'Fecha'];
    } else if (_selectedReportType == 'Gastos') {
      headers = ['Descripción', 'Monto', 'Fecha'];
    } else if (_selectedReportType == 'Inventario') {
      headers = ['Producto', 'Stock Actual', 'Precio de Venta (USD)'];
    }
    
    String csvData = headers.join(',') + '\n';

    for (var item in _reportData) {
      List<String> row = [];
      if (item is Sale) {
        row = [item.invoiceNumber, '"${item.client?.name ?? 'N/A'}"', item.total.toString(), item.saleDate.toIso8601String()];
      } else if (item is Expense) {
        row = ['"${item.description}"', item.amount.toString(), item.expenseDate.toIso8601String()];
      } else if (item is Product) {
        row = ['"${item.name}"', item.currentStock.toString(), item.sellingPriceUsd.toString()];
      }
      csvData += row.join(',') + '\n';
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/reporte_$_selectedReportType.csv';
    final file = File(filePath);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(filePath)], text: 'Reporte de $_selectedReportType');
  }

  Widget _buildReportDataView() {
    if (_reportData == null || _reportData.isEmpty) {
      return const Center(child: Text('No hay datos para el período seleccionado.'));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.grid_on),
              label: const Text('Exportar a CSV'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: _exportToCsv,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.table_chart),
              label: const Text('Exportar a Excel'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _exportToExcel,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData.length,
            itemBuilder: (context, index) {
              final item = _reportData[index];
              return Card(
                child: ListTile(
                  title: _buildItemTitle(item),
                  subtitle: _buildItemSubtitle(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemTitle(dynamic item) {
    if (item is Sale) {
      return Text('Venta #${item.invoiceNumber}');
    } else if (item is Expense) {
      return Text(item.description);
    } else if (item is Product) {
      return Text(item.name);
    }
    return const Text('Dato desconocido');
  }

  Widget _buildItemSubtitle(dynamic item) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    if (item is Sale) {
      return Text('Total: ${currencyFormat.format(item.total)} - Fecha: ${DateFormat('dd/MM/yyyy').format(item.saleDate)}');
    } else if (item is Expense) {
      return Text('Monto: ${currencyFormat.format(item.amount)} - Fecha: ${DateFormat('dd/MM/yyyy').format(item.expenseDate)}');
    } else if (item is Product) {
      return Text('Stock: ${item.currentStock} - Precio: ${currencyFormat.format(item.sellingPriceUsd)}');
    }
    return const Text('');
  }
} 