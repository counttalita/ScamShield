import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'phone_input_screen.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final AuthService _authService = AuthService();
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final biometrics = await _authService.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _availableBiometrics = biometrics;
          _isLoading = false;
        });
        
        // Auto-trigger biometric authentication
        _authenticateWithBiometric();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String get _biometricTypeText {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  IconData get _biometricIcon {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return Icons.visibility;
    } else {
      return Icons.security;
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final result = await _authService.authenticateWithBiometric();
      
      if (result.success) {
        if (mounted) {
          // Navigate to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          // Show specific error message from the result
          final errorMessage = result.error ?? 'Biometric authentication failed. Please try again or use phone number login.';
          _showErrorDialog(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred during biometric authentication.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _usePhoneLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PhoneInputScreen()),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/ScamShield.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'ScamShield',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Biometric icon
              if (!_isLoading)
                Icon(
                  _biometricIcon,
                  size: 100,
                  color: _isAuthenticating ? Colors.blue : Colors.grey.shade400,
                )
              else
                const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              
              const SizedBox(height: 40),
              
              // Title
              Text(
                _isLoading 
                    ? 'Loading...' 
                    : _isAuthenticating 
                        ? 'Authenticating...' 
                        : 'Welcome Back!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              if (!_isLoading)
                Text(
                  _isAuthenticating 
                      ? 'Please verify your $_biometricTypeText'
                      : 'Use $_biometricTypeText to access your account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              
              const Spacer(),
              
              // Try again button
              if (!_isLoading && !_isAuthenticating)
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _authenticateWithBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_biometricIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Use $_biometricTypeText',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Use phone number button
              if (!_isLoading)
                TextButton(
                  onPressed: _usePhoneLogin,
                  child: const Text(
                    'Use Phone Number Instead',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
