import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> {
  final _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  late Future<double> _currentRateFuture;
  late Future<List<Map<String, dynamic>>> _historyFuture;
  bool _isLoading = false;

  // Formateador para la tasa
  late NumberFormat _rateFormatter;
  // Formateador para la fecha
  late DateFormat _dateFormatter;

  @override
  void initState() {
    super.initState();
    _initializeFormatters();
    _loadCurrentRate();
    _loadHistory();
  }

  Future<void> _initializeFormatters() async {
    await initializeDateFormatting('es_VE', null);
    _rateFormatter = NumberFormat('#,##0.00', 'es_VE');
    _dateFormatter = DateFormat('dd/MM/yyyy HH:mm', 'es_VE');
  }

  void _loadCurrentRate() {
    _currentRateFuture = _dbHelper.getExchangeRate();
    _currentRateFuture.then((rate) {
       if (mounted) {
          _rateController.text = _rateFormatter.format(rate).replaceAll('.', '').replaceAll(',', '.');
       }
    });
  }

  void _loadHistory() {
    _historyFuture = _dbHelper.getExchangeRateHistory();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _updateRate() async {
    if (_formKey.currentState!.validate()) {
      final newRateString = _rateController.text.replaceAll(',', '.');
      final newRate = double.tryParse(newRateString);

      if (newRate == null || newRate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa una tasa válida mayor a 0.'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        await _dbHelper.updateExchangeRate(newRate);
        await _dbHelper.updateAllProductSellingPrices(newRate);

        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tasa de cambio actualizada exitosamente.'), backgroundColor: Colors.green),
            );
            setState(() {
              _loadCurrentRate();
              _loadHistory(); // Recargar el historial
              _isLoading = false;
            });
          }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al actualizar la tasa: $e'), backgroundColor: Colors.red),
            );
             setState(() { _isLoading = false; });
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasa de Cambio USD -> VES'),
      ),
      body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FutureBuilder<double>(
                future: _currentRateFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Tasa Actual: Cargando...');
                  }
                  if (snapshot.hasError) {
                    return const Text('Tasa Actual: Error', style: TextStyle(color: Colors.red));
                  }
                  final rate = snapshot.data ?? 1.0;
                  return Text(
                    'Tasa Actual: 1 USD = ${_rateFormatter.format(rate)} VES',
                    style: Theme.of(context).textTheme.titleLarge,
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: 'Nueva Tasa (Ej: 36.50)',
                  hintText: 'Ingrese el valor de 1 USD en VES',
                  border: OutlineInputBorder(),
                  prefixText: 'Bs. ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la nueva tasa';
                  }
                  final rate = double.tryParse(value.replaceAll(',', '.'));
                   if (rate == null || rate <= 0) {
                    return 'Ingresa un número válido mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Center(
                child: _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar y Actualizar Precios'),
                    onPressed: _updateRate,
                    style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                        ),
                    ),
                  ],
                  ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Nota: Al guardar, se actualizará el precio de venta en Bolívares (VES) de TODOS los productos existentes en base a esta nueva tasa.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Historial de Tasas de Cambio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Text('Error al cargar el historial');
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return const Text('No hay registros en el historial');
                  }
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final record = history[index];
                        final rate = record['rate'] as double;
                        final date = DateTime.parse(record['date']);
                        return ListTile(
                          title: Text('1 USD = ${_rateFormatter.format(rate)} VES'),
                          subtitle: Text(_dateFormatter.format(date)),
                          leading: const Icon(Icons.history),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 