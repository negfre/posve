import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../services/database_helper.dart';

class SaleDetailsPage extends StatefulWidget {
  final Sale sale;

  const SaleDetailsPage({super.key, required this.sale});

  @override
  State<SaleDetailsPage> createState() => _SaleDetailsPageState();
}

class _SaleDetailsPageState extends State<SaleDetailsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<SaleItem>> _saleItemsFuture;
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _currencyFormatterVes = NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ');

  @override
  void initState() {
    super.initState();
    _loadSaleItems();
  }

  void _loadSaleItems() {
    setState(() {
      if (widget.sale.id != null) {
        _saleItemsFuture = _dbHelper.getSaleItems(widget.sale.id!);
      } else {
        _saleItemsFuture = Future.value([]);
      }
    });
  }

  // Método para calcular los totales y subtotales de productos exentos y no exentos
  Future<Map<String, double>> _calculateTaxBreakdown() async {
    final items = await _saleItemsFuture;
    double exemptSubtotal = 0.0;
    double taxableSubtotal = 0.0;

    for (final item in items) {
      if (item.product?.isVatExempt ?? false) {
        exemptSubtotal += item.subtotalUsd;
      } else {
        taxableSubtotal += item.subtotalUsd;
      }
    }

    return {
      'exemptSubtotal': exemptSubtotal,
      'taxableSubtotal': taxableSubtotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Venta'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const Divider(height: 32, thickness: 1),
            _buildItemsSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Factura: ${widget.sale.invoiceNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.sale.paymentMethod?.name ?? 'N/A',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Cliente:',
                widget.sale.client?.name ?? 'Consumidor final'
              ),
              _buildInfoRow(
                'Fecha:',
                _dateFormatter.format(widget.sale.saleDate)
              ),
              
              // Construir FutureBuilder para mostrar desglose de impuestos
              FutureBuilder<Map<String, double>>(
                future: _calculateTaxBreakdown(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LinearProgressIndicator());
                  }
                  
                  final breakdown = snapshot.data ?? {'exemptSubtotal': 0.0, 'taxableSubtotal': 0.0};
                  final exemptSubtotal = breakdown['exemptSubtotal'] ?? 0.0;
                  final taxableSubtotal = breakdown['taxableSubtotal'] ?? 0.0;
                  
                  return Column(
                    children: [
                      _buildInfoRow(
                        'Subtotal general:',
                        _currencyFormatter.format(widget.sale.subtotal)
                      ),
                      if (exemptSubtotal > 0)
                        _buildInfoRow(
                          'Productos exentos:',
                          _currencyFormatter.format(exemptSubtotal),
                          textColor: Colors.red,
                        ),
                      if (taxableSubtotal > 0)
                        _buildInfoRow(
                          'Productos gravables:',
                          _currencyFormatter.format(taxableSubtotal),
                          textColor: Colors.green,
                        ),
                      _buildInfoRow(
                        'Impuesto (${(widget.sale.taxRate * 100).toStringAsFixed(0)}%):',
                        _currencyFormatter.format(widget.sale.taxAmount)
                      ),
                    ],
                  );
                }
              ),
              
              const Divider(height: 24),
              _buildInfoRow(
                'Total USD:',
                _currencyFormatter.format(widget.sale.total),
                isTotal: true
              ),
              _buildInfoRow(
                'Total Bs:',
                _currencyFormatterVes.format(widget.sale.total * widget.sale.exchangeRate),
                isTotal: true
              ),
              _buildInfoRow(
                'Tasa de cambio:',
                '${widget.sale.exchangeRate} Bs/\$'
              ),
              if (widget.sale.paymentDetails != null && widget.sale.paymentDetails!.isNotEmpty)
                _buildPaymentDetails(widget.sale.paymentDetails!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: textColor ?? Colors.grey[700],
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(String details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Detalles de pago:',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            details,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Productos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<SaleItem>>(
            future: _saleItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('Error al cargar los productos: ${snapshot.error}'),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text('No hay productos en esta venta'),
                );
              }

              final items = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product?.name ?? 'Producto #${item.productId} (Eliminado)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontStyle: item.product == null ? FontStyle.italic : FontStyle.normal,
                              color: item.product == null ? Colors.grey : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cantidad: ${item.quantity}'),
                                    Text('Precio USD: ${_currencyFormatter.format(item.unitPriceUsd)}'),
                                    Text('Precio Bs: ${_currencyFormatterVes.format(item.unitPriceVes)}'),
                                    Row(
                                      children: [
                                        Icon(
                                          item.product?.isVatExempt ?? false 
                                            ? Icons.cancel 
                                            : Icons.check_circle,
                                          color: item.product?.isVatExempt ?? false 
                                            ? Colors.red 
                                            : Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.product?.isVatExempt ?? false 
                                            ? 'Exento de IVA' 
                                            : 'IVA incluido',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: item.product?.isVatExempt ?? false 
                                              ? Colors.red 
                                              : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currencyFormatter.format(item.subtotalUsd),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _currencyFormatterVes.format(item.subtotalVes),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
