import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'screens/login_screen.dart';
import 'screens/esp_setup_screen.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: const NoiseApp(),
    ),
  );
}

class NoiseApp extends StatelessWidget {
  const NoiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Classroom Noise Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f1419),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38bdf8),
          secondary: Color(0xFF8b9cb3),
          surface: Color(0xFF1a2332),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a2332),
          foregroundColor: Color(0xFFe8edf4),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1a2332),
          selectedItemColor: Color(0xFF38bdf8),
          unselectedItemColor: Color(0xFF8b9cb3),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1a2332),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1a2332),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF243044),
          contentTextStyle: TextStyle(color: Color(0xFFe8edf4)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkSetupAndNavigate();
  }

  Future<void> _checkSetupAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Brief splash
    if (!mounted) return;

    // Always go to login; ESP setup is accessible from login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f1419),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF38bdf8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF38bdf8), width: 2),
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                size: 48,
                color: Color(0xFF38bdf8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Noise Monitor',
              style: TextStyle(
                color: Color(0xFFe8edf4),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Traffic-light IoT system',
              style: TextStyle(
                color: Color(0xFF8b9cb3),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF38bdf8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}