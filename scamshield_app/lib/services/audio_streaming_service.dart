import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_sound/flutter_sound.dart';

/// Service for streaming call audio to backend for real-time scam detection
class AudioStreamingService {
  static final AudioStreamingService _instance = AudioStreamingService._internal();
  factory AudioStreamingService() => _instance;
  AudioStreamingService._internal();

  static AudioStreamingService get instance => _instance;

  // WebSocket connection for real-time audio streaming
  WebSocketChannel? _wsChannel;
  
  // Audio recording
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isStreaming = false;
  bool _isRecorderInitialized = false;
  
  // Stream controllers for real-time updates
  final StreamController<ScamAnalysisResult> _analysisController = 
      StreamController<ScamAnalysisResult>.broadcast();
  final StreamController<AudioStreamStatus> _statusController = 
      StreamController<AudioStreamStatus>.broadcast();
  
  // Configuration
  static const String _wsEndpoint = 'wss://your-backend.com/ws/audio-analysis';
  static const int _sampleRate = 16000;
  static const int _bufferSize = 1024;
  
  // Getters for streams
  Stream<ScamAnalysisResult> get analysisStream => _analysisController.stream;
  Stream<AudioStreamStatus> get statusStream => _statusController.stream;
  
  bool get isStreaming => _isStreaming;
  bool get isRecording => _isRecording;

  /// Initialize audio streaming service
  Future<bool> initialize() async {
    try {
      // Check microphone permission
      final micPermission = await Permission.microphone.status;
      if (!micPermission.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          print('🎤 Microphone permission denied');
          _statusController.add(AudioStreamStatus.permissionDenied);
          return false;
        }
      }

      // Initialize the recorder
      if (!_isRecorderInitialized) {
        await _audioRecorder.openRecorder();
        _isRecorderInitialized = true;
      }

      print('🎤 Audio streaming service initialized');
      _statusController.add(AudioStreamStatus.ready);
      return true;
    } catch (e) {
      print('❌ Error initializing audio streaming: $e');
      _statusController.add(AudioStreamStatus.error);
      return false;
    }
  }

  /// Start real-time audio streaming for call analysis
  Future<bool> startStreaming({
    required String callId,
    required String phoneNumber,
    String? sessionId,
  }) async {
    try {
      if (_isStreaming) {
        print('⚠️ Audio streaming already active');
        return true;
      }

      // Initialize if not already done
      if (!await initialize()) {
        return false;
      }

      // Connect to WebSocket
      if (!await _connectWebSocket(callId, phoneNumber, sessionId)) {
        return false;
      }

      // Start audio recording and streaming
      if (!await _startAudioCapture()) {
        await _disconnectWebSocket();
        return false;
      }

      _isStreaming = true;
      _statusController.add(AudioStreamStatus.streaming);
      print('🎵 Started audio streaming for call $callId');
      return true;
    } catch (e) {
      print('❌ Error starting audio streaming: $e');
      _statusController.add(AudioStreamStatus.error);
      return false;
    }
  }

  /// Stop audio streaming
  Future<void> stopStreaming() async {
    try {
      if (!_isStreaming) {
        return;
      }

      await _stopAudioCapture();
      await _disconnectWebSocket();
      
      _isStreaming = false;
      _statusController.add(AudioStreamStatus.stopped);
      print('🛑 Stopped audio streaming');
    } catch (e) {
      print('❌ Error stopping audio streaming: $e');
      _statusController.add(AudioStreamStatus.error);
    }
  }

  /// Connect to WebSocket for real-time analysis
  Future<bool> _connectWebSocket(String callId, String phoneNumber, String? sessionId) async {
    try {
      final uri = Uri.parse('$_wsEndpoint?callId=$callId&phoneNumber=$phoneNumber${sessionId != null ? '&sessionId=$sessionId' : ''}');
      
      _wsChannel = WebSocketChannel.connect(uri);
      
      // Listen for analysis results
      _wsChannel!.stream.listen(
        (data) => _handleAnalysisResult(data),
        onError: (error) {
          print('❌ WebSocket error: $error');
          _statusController.add(AudioStreamStatus.error);
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _statusController.add(AudioStreamStatus.disconnected);
        },
      );

      // Send initial connection message
      final initMessage = {
        'type': 'init',
        'callId': callId,
        'phoneNumber': phoneNumber,
        'sessionId': sessionId,
        'audioConfig': {
          'sampleRate': _sampleRate,
          'encoding': 'PCM16',
          'channels': 1,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _wsChannel!.sink.add(json.encode(initMessage));
      print('🔌 Connected to WebSocket for audio analysis');
      return true;
    } catch (e) {
      print('❌ Error connecting to WebSocket: $e');
      return false;
    }
  }

  /// Disconnect WebSocket
  Future<void> _disconnectWebSocket() async {
    try {
      if (_wsChannel != null) {
        await _wsChannel!.sink.close(status.goingAway);
        _wsChannel = null;
      }
    } catch (e) {
      print('❌ Error disconnecting WebSocket: $e');
    }
  }

  /// Start audio capture and streaming
  Future<bool> _startAudioCapture() async {
    try {
      // Ensure recorder is initialized
      if (!_isRecorderInitialized) {
        await initialize();
      }

      // Start recording to a temporary file
      // In a production app, you would implement real-time streaming
      final tempPath = '/tmp/scamshield_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _audioRecorder.startRecorder(
        toFile: tempPath,
        codec: Codec.pcm16WAV,
        sampleRate: _sampleRate,
        numChannels: 1,
      );
      
      _isRecording = true;

      // Start streaming audio data
      _streamAudioData();
      
      print('🎤 Started audio capture');
      return true;
    } catch (e) {
      print('❌ Error starting audio capture: $e');
      return false;
    }
  }

  /// Stop audio capture
  Future<void> _stopAudioCapture() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stopRecorder();
        _isRecording = false;
        print('🛡️ Stopped audio capture');
      }
    } catch (e) {
      print('❌ Error stopping audio capture: $e');
    }
  }

  /// Stream audio data to WebSocket
  void _streamAudioData() {
    // Note: This is a simplified implementation
    // In a real implementation, you would need to capture audio chunks
    // and stream them to the WebSocket in real-time
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isStreaming || !_isRecording || _wsChannel == null) {
        timer.cancel();
        return;
      }

      // In a real implementation, you would capture actual audio data here
      // For now, we'll send a placeholder message
      final audioMessage = {
        'type': 'audio_chunk',
        'timestamp': DateTime.now().toIso8601String(),
        'sequenceNumber': timer.tick,
        // 'audioData': base64EncodedAudioChunk, // Real audio data would go here
      };

      try {
        _wsChannel!.sink.add(json.encode(audioMessage));
      } catch (e) {
        print('❌ Error sending audio chunk: $e');
        timer.cancel();
      }
    });
  }

  /// Handle analysis results from backend
  void _handleAnalysisResult(dynamic data) {
    try {
      final Map<String, dynamic> result = json.decode(data);
      
      switch (result['type']) {
        case 'analysis_result':
          final analysisResult = ScamAnalysisResult.fromJson(result);
          _analysisController.add(analysisResult);
          break;
          
        case 'warning':
          final warning = ScamAnalysisResult.fromJson(result);
          _analysisController.add(warning);
          break;
          
        case 'status':
          print('📊 Analysis status: ${result['message']}');
          break;
          
        default:
          print('📥 Unknown message type: ${result['type']}');
      }
    } catch (e) {
      print('❌ Error handling analysis result: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    stopStreaming();
    _analysisController.close();
    _statusController.close();
    if (_isRecorderInitialized) {
      _audioRecorder.closeRecorder();
      _isRecorderInitialized = false;
    }
  }
}

/// Audio streaming status
enum AudioStreamStatus {
  ready,
  streaming,
  stopped,
  error,
  permissionDenied,
  notAvailable,
  disconnected,
}

/// Real-time scam analysis result
class ScamAnalysisResult {
  final String type;
  final String callId;
  final double confidence;
  final String riskLevel;
  final String? warning;
  final String? reason;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ScamAnalysisResult({
    required this.type,
    required this.callId,
    required this.confidence,
    required this.riskLevel,
    this.warning,
    this.reason,
    this.metadata,
    required this.timestamp,
  });

  factory ScamAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ScamAnalysisResult(
      type: json['type'] ?? 'analysis_result',
      callId: json['callId'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      riskLevel: json['riskLevel'] ?? 'LOW',
      warning: json['warning'],
      reason: json['reason'],
      metadata: json['metadata'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isHighRisk => riskLevel == 'HIGH' && confidence > 0.8;
  bool get isMediumRisk => riskLevel == 'MEDIUM' && confidence > 0.6;
  bool get hasWarning => warning != null && warning!.isNotEmpty;
}
