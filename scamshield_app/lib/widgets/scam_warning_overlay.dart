import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_streaming_service.dart';

/// Real-time scam warning overlay that appears during calls
class ScamWarningOverlay extends StatefulWidget {
  final String callId;
  final String phoneNumber;
  final VoidCallback? onDismiss;
  final VoidCallback? onReportScam;
  final VoidCallback? onEndCall;

  const ScamWarningOverlay({
    Key? key,
    required this.callId,
    required this.phoneNumber,
    this.onDismiss,
    this.onReportScam,
    this.onEndCall,
  }) : super(key: key);

  @override
  State<ScamWarningOverlay> createState() => _ScamWarningOverlayState();
}

class _ScamWarningOverlayState extends State<ScamWarningOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  StreamSubscription<ScamAnalysisResult>? _analysisSubscription;
  ScamAnalysisResult? _latestResult;
  bool _isVisible = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _listenToAnalysis();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  void _listenToAnalysis() {
    _analysisSubscription = AudioStreamingService.instance.analysisStream.listen(
      (result) {
        if (result.callId == widget.callId && !_isDismissed) {
          setState(() {
            _latestResult = result;
          });
          
          if (result.isHighRisk || result.hasWarning) {
            _showWarning();
          }
        }
      },
    );
  }

  void _showWarning() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _slideController.forward();
      
      // Haptic feedback for urgent warning
      HapticFeedback.heavyImpact();
      
      // Auto-hide after 10 seconds if not dismissed
      Timer(const Duration(seconds: 10), () {
        if (_isVisible && !_isDismissed) {
          _hideWarning();
        }
      });
    }
  }

  void _hideWarning() {
    if (_isVisible) {
      _slideController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  void _dismiss() {
    setState(() {
      _isDismissed = true;
    });
    _hideWarning();
    widget.onDismiss?.call();
  }

  Color _getWarningColor() {
    if (_latestResult == null) return Colors.orange;
    
    switch (_latestResult!.riskLevel) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.yellow;
    }
  }

  IconData _getWarningIcon() {
    if (_latestResult == null) return Icons.warning;
    
    switch (_latestResult!.riskLevel) {
      case 'HIGH':
        return Icons.dangerous;
      case 'MEDIUM':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  String _getWarningTitle() {
    if (_latestResult == null) return 'Potential Scam';
    
    switch (_latestResult!.riskLevel) {
      case 'HIGH':
        return 'SCAM ALERT!';
      case 'MEDIUM':
        return 'Suspicious Call';
      default:
        return 'Information';
    }
  }

  String _getWarningMessage() {
    if (_latestResult?.warning != null) {
      return _latestResult!.warning!;
    }
    
    if (_latestResult?.reason != null) {
      return _latestResult!.reason!;
    }
    
    return 'This call may be a scam. Be cautious about sharing personal information.';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _latestResult == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getWarningColor().withOpacity(0.9),
                    _getWarningColor().withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getWarningColor(),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getWarningIcon(),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getWarningTitle(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'From: ${widget.phoneNumber}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _dismiss,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getWarningMessage(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onEndCall,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.call_end),
                            label: const Text('End Call'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onReportScam,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.white),
                              ),
                            ),
                            icon: const Icon(Icons.report),
                            label: const Text('Report'),
                          ),
                        ),
                      ],
                    ),
                    if (_latestResult!.confidence > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.analytics,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Confidence: ${(_latestResult!.confidence * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _analysisSubscription?.cancel();
    super.dispose();
  }
}

/// Helper widget to show the overlay as a system overlay
class ScamWarningOverlayManager {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void showOverlay(
    BuildContext context, {
    required String callId,
    required String phoneNumber,
    VoidCallback? onDismiss,
    VoidCallback? onReportScam,
    VoidCallback? onEndCall,
  }) {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => ScamWarningOverlay(
        callId: callId,
        phoneNumber: phoneNumber,
        onDismiss: () {
          hideOverlay();
          onDismiss?.call();
        },
        onReportScam: onReportScam,
        onEndCall: onEndCall,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  static void hideOverlay() {
    if (_isShowing && _overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}
