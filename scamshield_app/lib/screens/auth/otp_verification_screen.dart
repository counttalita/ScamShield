import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'biometric_setup_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final int expiresIn;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.expiresIn,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _canResend = false;
  int _remainingTime = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingTime = widget.expiresIn;
    _canResend = false;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingTime ~/ 60;
    final seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showErrorDialog('Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.verifyOTP(
        widget.phoneNumber,
        _otpController.text,
      );

      if (result.success) {
        if (mounted) {
          // Check if biometric is available and navigate accordingly
          final authService = AuthService();
          final isBiometricAvailable = await authService.isBiometricAvailable();
          
          if (isBiometricAvailable) {
            // Navigate to biometric setup
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BiometricSetupScreen(),
              ),
            );
          } else {
            // Navigate directly to home
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog(result.message ?? 'Invalid verification code');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Network error. Please check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.sendOTP(widget.phoneNumber);

      if (result.success) {
        _startTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          _showErrorDialog(result.message ?? 'Failed to resend code');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Network error. Please check your connection.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Icon
              const Icon(
                Icons.sms_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Verify Phone Number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'We sent a 6-digit verification code to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // OTP Input
              Form(
                key: _formKey,
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 56,
                    fieldWidth: 48,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.grey.shade50,
                    selectedFillColor: Colors.blue.shade50,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey.shade300,
                    selectedColor: Colors.blue,
                  ),
                  enableActiveFill: true,
                  onCompleted: (value) {
                    _verifyOTP();
                  },
                  onChanged: (value) {
                    // Auto-verify when 6 digits are entered
                    if (value.length == 6) {
                      _verifyOTP();
                    }
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Timer and resend
              if (!_canResend)
                Text(
                  'Resend code in $_formattedTime',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                )
              else
                TextButton(
                  onPressed: _isLoading ? null : _resendOTP,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Verify button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const Spacer(),
              
              // Help text
              const Text(
                'Didn\'t receive the code? Check your messages or try resending.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
