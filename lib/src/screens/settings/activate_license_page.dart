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
          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false, // User must tap button to close
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('¡Licencia Activada!'),
                content: const Text(
                  'La licencia se ha activado exitosamente. '
                  'Para que todos los cambios surtan efecto, se recomienda cerrar sesión y volver a ingresar.'
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Aceptar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close the dialog
                      Navigator.of(context).pop(); // Go back to the previous screen
                    },
                  ),
                ],
              );
            },
          );
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

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
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
                          '¿Cómo Funciona el Sistema de Licencias?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Proceso paso a paso
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📋 Proceso de Activación:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildStep('1', 'Genera tu token único (botón arriba)'),
                          _buildStep('2', 'Envía el token al desarrollador'),
                          _buildStep('3', 'Recibe el código de licencia'),
                          _buildStep('4', 'Ingresa el código aquí'),
                          _buildStep('5', '¡Listo! Licencia activada de por vida'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Características
                    const Text(
                      '🔒 Características de Seguridad:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'La licencia está vinculada a este dispositivo específico usando identificadores únicos del hardware',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'El sistema usa criptografía SHA-256 para garantizar la seguridad',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'No requiere conexión a internet ni servidor externo',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Limitaciones sin licencia
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Modo de Prueba (Sin Licencia):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Máximo 5 productos',
                            style: TextStyle(fontSize: 13),
                          ),
                          const Text(
                            '• No se pueden exportar reportes a Excel/CSV',
                            style: TextStyle(fontSize: 13),
                          ),
                          const Text(
                            '• Todas las demás funciones están disponibles',
                            style: TextStyle(fontSize: 13, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Con licencia
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Con Licencia Activada:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '✅ Productos ilimitados',
                            style: TextStyle(fontSize: 13),
                          ),
                          const Text(
                            '✅ Exportación de reportes habilitada',
                            style: TextStyle(fontSize: 13),
                          ),
                          const Text(
                            '✅ Licencia de por vida para este dispositivo',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Información importante
                    const Text(
                      '⚠️ Información Importante:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'La licencia es válida solo para este dispositivo específico',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'Si cambias de dispositivo, necesitarás una nueva licencia',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'Los backups NO incluyen licencias por seguridad',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
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