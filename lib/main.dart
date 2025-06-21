import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importar Provider
import 'src/theme/app_theme.dart'; // Importar el tema
import 'src/providers/auth_provider.dart'; // Importar AuthProvider
import 'src/providers/payment_method_provider.dart'; // <-- Importar PaymentMethodProvider
import 'src/providers/product_provider.dart'; // <-- Importar ProductProvider
import 'src/screens/auth/auth_wrapper.dart'; // Importar AuthWrapper
import 'src/screens/home/home_page.dart'; // Importar HomePage
import 'src/screens/settings/activate_license_page.dart'; // Importar ActivateLicensePage
import 'src/screens/auth/register_page.dart'; // Importar RegisterPage
import 'src/services/database_helper.dart'; // Importar DatabaseHelper
import 'src/services/license_service.dart'; // Importar LicenseService
import 'src/models/category.dart'; // Importar Category
import 'src/models/supplier.dart'; // Importar Supplier
// Importa SplashScreen si aún lo necesitas para alguna lógica inicial
// import 'src/screens/splash_screen.dart'; 

void main() async { // Convertir a async
  // Asegurar la inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar la base de datos
  final dbHelper = DatabaseHelper();
  await dbHelper.database; // Inicializa la base de datos
  
  // Crear categoría y proveedor por defecto si no existen
  await _createDefaultCategoryAndSupplier(dbHelper);
  
  // Inicializar el servicio de licenciamiento
  final licenseService = LicenseService();
  
  // Aquí podrías inicializar servicios como la BD si fuera necesario antes de runApp
  // await DatabaseHelper().database; // Ejemplo de inicialización temprana (opcional)

  runApp(MyApp(licenseService: licenseService));
}

// Función para crear categoría y proveedor por defecto
Future<void> _createDefaultCategoryAndSupplier(DatabaseHelper dbHelper) async {
  try {
    // Verificar si la categoría "Sin categoría" ya existe
    List<Category> categories = await dbHelper.getAllCategories();
    bool hasDefaultCategory = categories.any((category) => category.name == 'Sin categoría');
    
    // Crear la categoría por defecto si no existe
    if (!hasDefaultCategory) {
      final now = DateTime.now();
      await dbHelper.insertCategory(Category(
        id: null,
        name: 'Sin categoría',
        createdAt: now,
        updatedAt: now,
      ));
      print('Categoría "Sin categoría" creada exitosamente');
    }
    
    // Verificar si el proveedor "Sin proveedor" ya existe
    List<Supplier> suppliers = await dbHelper.getAllSuppliers();
    bool hasDefaultSupplier = suppliers.any((supplier) => supplier.name == 'Sin proveedor');
    
    // Crear el proveedor por defecto si no existe
    if (!hasDefaultSupplier) {
      final now = DateTime.now();
      await dbHelper.insertSupplier(Supplier(
        id: null,
        name: 'Sin proveedor',
        taxId: 'J-00000000',
        phone: '',
        observations: 'Proveedor predeterminado del sistema',
        createdAt: now,
        updatedAt: now,
      ));
      print('Proveedor "Sin proveedor" creado exitosamente');
    }
  } catch (e) {
    print('Error al crear categoría y proveedor por defecto: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.licenseService});

  final LicenseService licenseService;

  @override
  Widget build(BuildContext context) {
    // Envolver MaterialApp con MultiProvider para la gestión de estado
    return MultiProvider(
      providers: [
        // Registrar AuthProvider
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Registrar PaymentMethodProvider
        ChangeNotifierProvider(create: (_) => PaymentMethodProvider()),
        // Registrar ProductProvider
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        // Aquí añadirás otros providers (SupplierProvider, CategoryProvider, etc.)
      ],
      child: MaterialApp(
        title: 'Gestión de Inventario', // Título actualizado
        theme: AppTheme.lightTheme, // Aplicar el tema personalizado
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/home': (context) => const HomePage(),
          '/activate-license': (context) => const ActivateLicensePage(),
          '/register': (context) => const RegisterPage(),
        },
        debugShowCheckedModeBanner: false, // Opcional: Ocultar banner de debug
      ),
    );
  }
}

// --- Eliminar o Comentar SplashScreen si ya no se usa directamente ---
/*
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Aquí iría la lógica para determinar si ir a Login o Home,
    // por ahora solo es un placeholder.
    // Future.delayed(const Duration(seconds: 2), () {
    //   // Navegar a AuthWrapper o directamente a Login/Home
    // });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Cargando...'),
          ],
        ),
      ),
    );
  }
}
*/

// --- Comentado o Eliminado: Código original de MyHomePage ---
/*
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
*/
