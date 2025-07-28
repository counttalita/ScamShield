import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/call_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/phone_input_screen.dart';
import 'screens/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize call handling
  await _initializeCallHandling();
  
  runApp(const ScamShieldApp());
}

Future<void> _initializeCallHandling() async {
  // Request necessary permissions
  await _requestPermissions();
  
  // Initialize call service
  CallService.initialize();
}

Future<void> _requestPermissions() async {
  await [
    Permission.phone,
    Permission.microphone,
    Permission.notification,
  ].request();
}

class ScamShieldApp extends StatelessWidget {
  const ScamShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamShield',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Start auth check and minimum loading time in parallel
      final authFuture = AuthService.isAuthenticated();
      final minLoadingTime = Future.delayed(const Duration(milliseconds: 3000)); // 3 seconds to see animation
      
      final results = await Future.wait([authFuture, minLoadingTime]);
      final isLoggedIn = results[0] as bool;
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isLoggedIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Still wait minimum time even on error
      await Future.delayed(const Duration(milliseconds: 3000));
      
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen(
        message: 'Initializing ScamShield Protection...',
        duration: Duration(milliseconds: 6000),
      );
    }

    // Route to appropriate screen based on authentication status
    if (_isAuthenticated) {
      return const MainScreen();
    } else {
      return const PhoneInputScreen();
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Protection',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
