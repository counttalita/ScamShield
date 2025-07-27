import 'package:flutter/material.dart';
import '../widgets/animated_shield_loader.dart';

class LoadingScreen extends StatefulWidget {
  final String? message;
  final VoidCallback? onComplete;
  final Duration duration;
  
  const LoadingScreen({
    super.key,
    this.message,
    this.onComplete,
    this.duration = const Duration(milliseconds: 6000),
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    
    // Auto-complete after animation duration
    Future.delayed(widget.duration, () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark blue background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Epic shield animation
              const AnimatedShieldLoader(
                size: 250,
                primaryColor: Color(0xFF2196F3),
                accentColor: Color(0xFF4CAF50),
              ),
              
              const SizedBox(height: 40),
              
              // Loading message
              if (widget.message != null)
                Text(
                  widget.message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 20),
              
              // Subtle loading indicator
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper class to show loading screen as overlay or navigation
class LoadingScreenHelper {
  /// Show loading screen as full-screen overlay
  static void showOverlay(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 6000),
    VoidCallback? onComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => LoadingScreen(
        message: message,
        duration: duration,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete?.call();
        },
      ),
    );
  }
  
  /// Navigate to loading screen and then to next screen
  static void navigateWithLoading(
    BuildContext context, {
    required Widget nextScreen,
    String? message,
    Duration duration = const Duration(milliseconds: 6000),
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoadingScreen(
          message: message,
          duration: duration,
          onComplete: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => nextScreen),
            );
          },
        ),
      ),
    );
  }
  
  /// Show loading for app launch (with fade transition)
  static void showAppLaunchLoading(
    BuildContext context, {
    required Widget homeScreen,
    String message = 'Initializing ScamShield Protection...',
  }) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoadingScreen(
          message: message,
          onComplete: () {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => homeScreen,
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
