import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final AuthService _authService = AuthService();
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final biometrics = await _authService.getAvailableBiometrics();
      setState(() {
        _availableBiometrics = biometrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _enableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.enableBiometric();
      
      if (success) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          _showErrorDialog('Failed to enable biometric authentication. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred while setting up biometric authentication.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _skipBiometric() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: Text('$_biometricTypeText authentication has been enabled successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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
              const SizedBox(height: 60),
              
              // Icon
              if (!_isLoading)
                Icon(
                  _biometricIcon,
                  size: 100,
                  color: Colors.blue,
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
                _isLoading ? 'Setting up...' : 'Enable $_biometricTypeText',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              if (!_isLoading)
                Text(
                  'Use $_biometricTypeText to quickly and securely access ScamShield without entering your phone number each time.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              
              const SizedBox(height: 60),
              
              // Benefits list
              if (!_isLoading) ...[
                _buildBenefitItem(
                  Icons.speed,
                  'Quick Access',
                  'Open the app instantly with your $_biometricTypeText',
                ),
                const SizedBox(height: 24),
                _buildBenefitItem(
                  Icons.security,
                  'Enhanced Security',
                  'Your biometric data stays on your device',
                ),
                const SizedBox(height: 24),
                _buildBenefitItem(
                  Icons.privacy_tip,
                  'Privacy First',
                  'No biometric data is sent to our servers',
                ),
              ],
              
              const Spacer(),
              
              // Enable button
              if (!_isLoading)
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _enableBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Enable $_biometricTypeText',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Skip button
              if (!_isLoading)
                TextButton(
                  onPressed: _skipBiometric,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
