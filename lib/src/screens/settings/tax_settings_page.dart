import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_helper.dart';

class TaxSettingsPage extends StatefulWidget {
  const TaxSettingsPage({super.key});

  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _taxRateController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isIvaEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // Cargar tasa de impuesto
      final rate = await _dbHelper.getDefaultTaxRate();
      // Convertir de decimal a porcentaje para mostrar
      final percentage = (rate * 100).toStringAsFixed(0);
      _taxRateController.text = percentage;
      
      // Cargar si el IVA está habilitado
      _isIvaEnabled = await _dbHelper.getVatEnabled();
    } catch (e) {
      _showError('Error al cargar la configuración de impuestos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaxSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Convertir de porcentaje a decimal para guardar
      final text = _taxRateController.text.trim();
      final percentage = double.parse(text);
      final rate = percentage / 100;

      // Actualizar tasa de impuesto
      await _dbHelper.updateDefaultTaxRate(rate);
      
      // Actualizar si el IVA está habilitado
      await _dbHelper.setVatEnabled(_isIvaEnabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración de impuestos actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Error al actualizar la configuración de impuestos: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Impuesto'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configuración de IVA/Impuesto',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Habilitar IVA en ventas'),
                              subtitle: const Text('Activa/desactiva el cobro de impuestos'),
                              value: _isIvaEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _isIvaEnabled = value;
                                });
                              },
                              secondary: Icon(
                                _isIvaEnabled ? Icons.check_circle : Icons.cancel,
                                color: _isIvaEnabled ? Colors.green : Colors.red,
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _taxRateController,
                              decoration: const InputDecoration(
                                labelText: 'Porcentaje de IVA',
                                hintText: 'Ej: 16',
                                border: OutlineInputBorder(),
                                suffixText: '%',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingrese el porcentaje de IVA';
                                }
                                final number = double.tryParse(value);
                                if (number == null) {
                                  return 'Ingrese un valor numérico válido';
                                }
                                if (number < 0 || number > 100) {
                                  return 'El porcentaje debe estar entre 0 y 100';
                                }
                                return null;
                              },
                              enabled: _isIvaEnabled,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Este valor se utilizará para calcular el impuesto en todas las ventas.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'Información sobre IVA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '• El impuesto se aplicará automáticamente a todas las ventas si está habilitado.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• En los tickets y facturas, se mostrará el subtotal, el monto del impuesto y el total.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Al deshabilitar el IVA, las ventas se realizarán sin impuesto añadido.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Tasa actual: ${_isIvaEnabled ? "${_taxRateController.text}%" : "Desactivado"}',
                              style: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.bold,
                                color: _isIvaEnabled ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _updateTaxSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Guardar Configuración'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 