import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedShieldLoader extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color accentColor;
  
  const AnimatedShieldLoader({
    super.key,
    this.size = 200,
    this.primaryColor = const Color(0xFF2196F3),
    this.accentColor = const Color(0xFF4CAF50),
  });

  @override
  State<AnimatedShieldLoader> createState() => _AnimatedShieldLoaderState();
}

class _AnimatedShieldLoaderState extends State<AnimatedShieldLoader>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  
  // Animation phases
  late Animation<double> _approachAnimation;
  late Animation<double> _impactAnimation;
  late Animation<double> _crackAnimation;
  late Animation<double> _healingAnimation;
  late Animation<double> _brandRevealAnimation;
  late Animation<double> _shieldScaleAnimation;
  late Animation<double> _shieldRotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // Master controller for the entire sequence (6 seconds)
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );
    
    // Phase 1: Shield approaches (0-1.5s)
    _approachAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInCubic),
      ),
    );
    
    // Phase 2: Impact effect (1.5-2s)
    _impactAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.25, 0.33, curve: Curves.elasticOut),
      ),
    );
    
    // Phase 3: Screen cracks (2-3s)
    _crackAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.33, 0.5, curve: Curves.easeOut),
      ),
    );
    
    // Phase 4: Healing effect (3-4.5s)
    _healingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeInOut),
      ),
    );
    
    // Phase 5: Brand reveal (4.5-6s)
    _brandRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
    
    // Shield scale during approach
    _shieldScaleAnimation = Tween<double>(begin: 0.3, end: 1.2).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInCubic),
      ),
    );
    
    // Shield rotation during approach
    _shieldRotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInOut),
      ),
    );
    
    // Start the epic animation sequence
    _startEpicSequence();
  }
  
  void _startEpicSequence() async {
    // Start the master animation
    _masterController.forward();
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _masterController,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background with crack effect
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: ScreenCrackPainter(
                  crackProgress: _crackAnimation.value,
                  healingProgress: _healingAnimation.value,
                ),
              ),
              
              // Shield approaching and impacting
              if (_approachAnimation.value > 0 || _impactAnimation.value > 0)
                Transform.scale(
                  scale: _shieldScaleAnimation.value + (_impactAnimation.value * 0.3),
                  child: Transform.rotate(
                    angle: _shieldRotationAnimation.value * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size * 0.6, widget.size * 0.6),
                      painter: EpicShieldPainter(
                        approachProgress: _approachAnimation.value,
                        impactProgress: _impactAnimation.value,
                        primaryColor: widget.primaryColor,
                        accentColor: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              
              // Brand reveal
              if (_brandRevealAnimation.value > 0)
                Opacity(
                  opacity: _brandRevealAnimation.value,
                  child: Transform.scale(
                    scale: 0.5 + (_brandRevealAnimation.value * 0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ScamShield logo
                        Container(
                          width: widget.size * 0.4,
                          height: widget.size * 0.4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/ScamShield.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Brand text
                        Text(
                          'ScamShield',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),
                        Text(
                          'Protection Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter for the epic shield
class EpicShieldPainter extends CustomPainter {
  final double approachProgress;
  final double impactProgress;
  final Color primaryColor;
  final Color accentColor;
  
  EpicShieldPainter({
    required this.approachProgress,
    required this.impactProgress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Create shield path
    final shieldPath = _createShieldPath(size);
    
    // Shield glow effect during approach
    if (approachProgress > 0.5) {
      final glowPaint = Paint()
        ..color = primaryColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawPath(shieldPath, glowPaint);
    }
    
    // Shield outline with energy effect
    final outlinePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 + (impactProgress * 6.0);
    canvas.drawPath(shieldPath, outlinePaint);
    
    // Shield fill with energy
    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.2 + (impactProgress * 0.3))
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, fillPaint);
    
    // Impact energy waves
    if (impactProgress > 0) {
      _drawEnergyWaves(canvas, center, size, impactProgress);
    }
  }
  
  Path _createShieldPath(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width * 0.8;
    final height = size.height * 0.9;
    
    // Epic shield shape
    path.moveTo(center.dx, center.dy - height / 2);
    path.lineTo(center.dx - width / 2, center.dy - height / 4);
    path.lineTo(center.dx - width / 2, center.dy + height / 6);
    path.quadraticBezierTo(
      center.dx - width / 3, center.dy + height / 2,
      center.dx, center.dy + height / 2,
    );
    path.quadraticBezierTo(
      center.dx + width / 3, center.dy + height / 2,
      center.dx + width / 2, center.dy + height / 6,
    );
    path.lineTo(center.dx + width / 2, center.dy - height / 4);
    path.close();
    
    return path;
  }
  
  void _drawEnergyWaves(Canvas canvas, Offset center, Size size, double progress) {
    // Clamp progress to valid range and calculate safe opacity
    final clampedProgress = progress.clamp(0.0, 1.0);
    final opacity = (0.6 * (1 - clampedProgress)).clamp(0.0, 1.0);
    
    final paint = Paint()
      ..color = accentColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    for (int i = 0; i < 3; i++) {
      final radius = (size.width / 2) * clampedProgress * (1 + i * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter for screen crack effect
class ScreenCrackPainter extends CustomPainter {
  final double crackProgress;
  final double healingProgress;
  
  ScreenCrackPainter({
    required this.crackProgress,
    required this.healingProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (crackProgress <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final effectiveProgress = crackProgress * (1 - healingProgress);
    
    if (effectiveProgress <= 0) return;
    
    final crackPaint = Paint()
      ..color = Colors.white.withOpacity(0.8 * effectiveProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Draw radiating cracks from center
    final numCracks = 8;
    for (int i = 0; i < numCracks; i++) {
      final angle = (i * 2 * math.pi) / numCracks;
      final length = (size.width / 2) * effectiveProgress;
      
      final endX = center.dx + math.cos(angle) * length;
      final endY = center.dy + math.sin(angle) * length;
      
      // Main crack line
      canvas.drawLine(center, Offset(endX, endY), crackPaint);
      
      // Secondary crack branches
      if (effectiveProgress > 0.5) {
        final branchLength = length * 0.3;
        final branchAngle1 = angle + 0.3;
        final branchAngle2 = angle - 0.3;
        
        final midPoint = Offset(
          center.dx + math.cos(angle) * length * 0.6,
          center.dy + math.sin(angle) * length * 0.6,
        );
        
        final branch1End = Offset(
          midPoint.dx + math.cos(branchAngle1) * branchLength,
          midPoint.dy + math.sin(branchAngle1) * branchLength,
        );
        
        final branch2End = Offset(
          midPoint.dx + math.cos(branchAngle2) * branchLength,
          midPoint.dy + math.sin(branchAngle2) * branchLength,
        );
        
        canvas.drawLine(midPoint, branch1End, crackPaint);
        canvas.drawLine(midPoint, branch2End, crackPaint);
      }
    }
    
    // Healing glow effect
    if (healingProgress > 0) {
      final healPaint = Paint()
        ..color = const Color(0xFF4CAF50).withOpacity(0.3 * healingProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      
      canvas.drawCircle(center, size.width / 2 * healingProgress, healPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
