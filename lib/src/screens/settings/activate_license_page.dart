import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/license_service.dart';
import '../../constants/app_colors.dart';

class ActivateLicensePage extends StatefulWidget {
  const ActivateLicensePage({super.key});

  @override
  State<ActivateLicensePage> createState() => _ActivateLicensePageState();
}

class _ActivateLicensePageState extends State<ActivateLicensePage> {
  final LicenseService _licenseService = LicenseService();
  final _licenseKeyController = TextEditingController();
  
  String? _activationToken;
  String? _deviceInfo;
  bool _isGeneratingToken = false;
  bool _isActivating = false;
  bool _isLicenseValid = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _checkCurrentLicense();
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = await _licenseService.getDeviceInfo();
    setState(() {
      _deviceInfo = deviceInfo;
    });
  }

  Future<void> _checkCurrentLicense() async {
    final isValid = await _licenseService.isLicenseValid();
    setState(() {
      _isLicenseValid = isValid;
    });
  }

  Future<void> _generateActivationToken() async {
    setState(() {
      _isGeneratingToken = true;
    });

    try {
      final token = await _licenseService.generateActivationToken();
      setState(() {
        _activationToken = token;
        _isGeneratingToken = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingToken = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando token: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateLicense() async {
    if (_licenseKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el código de licencia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isActivating = true;
    });

    try {
      final success = await _licenseService.saveLicense(_licenseKeyController.text.trim());
      
      if (success) {
        setState(() {
          _isLicenseValid = true;
          _isActivating = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Licencia activada exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Regresar a la pantalla anterior
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _isActivating = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al activar la licencia. Verifica el código.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isActivating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activar Licencia'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado de la licencia
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLicenseValid ? Icons.check_circle : Icons.cancel,
                          color: _isLicenseValid ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Estado de la Licencia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLicenseValid 
                          ? 'Licencia activa y válida'
                          : 'Licencia no activada',
                      style: TextStyle(
                        color: _isLicenseValid ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Información del dispositivo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_android, color: AppColors.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Información del Dispositivo',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_deviceInfo != null) ...[
                      Text(
                        _deviceInfo!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ] else ...[
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Generar token de activación
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key, color: AppColors.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Token de Activación',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Genera un token único para tu dispositivo y envíalo al desarrollador para obtener tu código de licencia.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_activationToken != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tu token de activación:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _activationToken!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _copyToClipboard(_activationToken!),
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copiar token',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '📧 Envía este token al desarrollador para obtener tu código de licencia.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _isGeneratingToken ? null : _generateActivationToken,
                        icon: _isGeneratingToken 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isGeneratingToken ? 'Generando...' : 'Generar Token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Activar licencia
            if (_activationToken != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified, color: AppColors.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Activar Licencia',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ingresa el código de licencia que recibiste del desarrollador:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Código de Licencia',
                          hintText: 'Ingresa el código aquí',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-]')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isActivating ? null : _activateLicense,
                          icon: _isActivating 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isActivating ? 'Activando...' : 'Activar Licencia'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Información adicional
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Información Importante',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• La licencia es válida solo para este dispositivo específico.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Si cambias de dispositivo, necesitarás una nueva licencia.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Sin licencia activa, los productos se eliminarán automáticamente cada 10 días.',
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• La licencia es de por vida para este dispositivo.',
                      style: TextStyle(fontSize: 14, color: Colors.green),
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
} 