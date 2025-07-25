import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/call_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/phone_input_screen.dart';
import 'screens/auth/biometric_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      home: const MainScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
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
