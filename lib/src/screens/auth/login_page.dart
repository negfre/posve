import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_storage_service.dart';
import '../../providers/auth_provider.dart';
import 'register_page.dart'; // Para navegar a Registro
// Para usar el tema

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  late final BiometricService _biometricService;
  late final SecureStorageService _secureStorage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('*** DEBUG: Inicializando LoginPage ***');
    _biometricService = BiometricService();
    _secureStorage = SecureStorageService();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkBiometricState();
  }

  Future<void> _checkBiometricState() async {
    try {
      debugPrint('*** DEBUG: Verificando estado biométrico ***');
      // Verificar si el dispositivo soporta biometría
      final canCheckBio = await _biometricService.canCheckBiometrics();
      debugPrint('¿Puede verificar biometría?: $canCheckBio');
      
      if (!canCheckBio) {
        debugPrint('El dispositivo no soporta biometría');
        return;
      }

      // Obtener biometrías disponibles
      final availableBiometrics = await _biometricService.getAvailableBiometrics();
      debugPrint('Biometrías disponibles: $availableBiometrics');
      
      if (availableBiometrics.isEmpty) {
        debugPrint('No hay biometrías registradas en el dispositivo');
        return;
      }

      // Verificar último email usado - CAMBIADO para usar BiometricService
      final lastEmail = await _biometricService.getLastEmail();
      debugPrint('Último email usado: $lastEmail');
      
      if (lastEmail == null) {
        debugPrint('No hay último email guardado');
        return;
      }

      // Verificar si la biometría está habilitada para este usuario
      final isBiometricEnabled = await _biometricService.isBiometricEnabled(lastEmail);
      debugPrint('¿Biometría habilitada para $lastEmail?: $isBiometricEnabled');
      
      if (!isBiometricEnabled) {
        debugPrint('Biometría no está habilitada para este usuario');
        return;
      }

      // Si todo está correcto, mostrar el botón de biometría
      if (mounted) {
        setState(() {
          _emailController.text = lastEmail;
          _isBiometricAvailable = true;
        });
        debugPrint('Botón de biometría habilitado');
      }
    } catch (e) {
      debugPrint('*** DEBUG: Error al verificar estado biométrico: $e ***');
    }
  }

  Future<void> _loginWithBiometric() async {
    try {
      setState(() => _isLoading = true);
      
      final isAuthenticated = await _biometricService.authenticate();
      debugPrint('¿Autenticación biométrica exitosa?: $isAuthenticated');
      
      if (!isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticación biométrica fallida')),
          );
        }
        return;
      }

      final credentials = await _biometricService.getStoredCredentials(_emailController.text);
      debugPrint('¿Se obtuvieron credenciales guardadas?: ${credentials != null}');
      
      if (credentials == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron credenciales guardadas')),
          );
        }
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        credentials['email']!,
        credentials['password']!,
      );
      debugPrint('¿Login con biometría exitoso?: $success');

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al iniciar sesión')),
        );
      }
    } catch (e) {
      debugPrint('Error en login biométrico: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      debugPrint('*** DEBUG: Intentando login con email: $email ***');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(email, password);
      
      debugPrint('*** DEBUG: Resultado del login: $success ***');

      if (!mounted) return;

      if (success) {
        debugPrint('*** DEBUG: Login exitoso, guardando último email usado ***');
        await _biometricService.saveLastEmail(email);
        
        debugPrint('*** DEBUG: Verificando estado de biometría ***');
        // Verificar si es el primer login (biometría no habilitada)
        final isBiometricEnabled = await _biometricService.isBiometricEnabled(email);
        debugPrint('*** DEBUG: ¿Biometría ya habilitada?: $isBiometricEnabled ***');
        
        if (!isBiometricEnabled) {
          debugPrint('*** DEBUG: Biometría no habilitada, verificando soporte del dispositivo ***');
          // Verificar soporte de biometría en el dispositivo
          final canCheckBio = await _biometricService.canCheckBiometrics();
          final availableBiometrics = await _biometricService.getAvailableBiometrics();
          
          debugPrint('*** DEBUG: ¿Puede verificar biometría?: $canCheckBio ***');
          debugPrint('*** DEBUG: Biometrías disponibles: $availableBiometrics ***');
          
          if (canCheckBio && availableBiometrics.isNotEmpty) {
            debugPrint('*** DEBUG: Dispositivo soporta biometría, habilitando automáticamente ***');
            // Habilitar biometría automáticamente en el primer login exitoso
            final biometricEnabled = await _biometricService.enableBiometric(email, password);
            debugPrint('*** DEBUG: ¿Biometría habilitada exitosamente?: $biometricEnabled ***');
            
            if (biometricEnabled && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Se ha habilitado el inicio de sesión con huella dactilar. En tu próximo inicio de sesión podrás usar tu huella.'),
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } else {
            debugPrint('*** DEBUG: Dispositivo no soporta biometría o no hay biometrías disponibles ***');
          }
        } else {
          debugPrint('*** DEBUG: Biometría ya estaba habilitada ***');
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = 'Error al iniciar sesión';
        });
      }
    } catch (e) {
      debugPrint('*** DEBUG: Error en _login: $e ***');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese su correo electrónico';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese su contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Iniciar sesión'),
                          ),
                        ),
                      ),
                      if (_isBiometricAvailable && _emailController.text.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.fingerprint),
                          onPressed: _isLoading ? null : _loginWithBiometric,
                          tooltip: 'Iniciar sesión con huella dactilar',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 