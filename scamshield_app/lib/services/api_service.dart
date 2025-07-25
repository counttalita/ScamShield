import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://localhost:3000'; // Change to your backend URL
  
  /// Check if a phone number should be blocked
  static Future<CallCheckResult> checkCall(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/check-call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CallCheckResult.fromJson(data);
      } else {
        // If API fails, allow call by default for safety
        return CallCheckResult(
          action: 'allow',
          autoReject: false,
          riskLevel: 'LOW',
          confidence: 'UNKNOWN',
          reason: 'API error: ${response.statusCode}',
        );
      }
    } catch (e) {
      // If network fails, allow call by default for safety
      return CallCheckResult(
        action: 'allow',
        autoReject: false,
        riskLevel: 'LOW',
        confidence: 'UNKNOWN',
        error: 'Failed to check call: $e',
      );
    }
  }

  /// Health check for the backend API
  static Future<bool> isBackendHealthy() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class CallCheckResult {
  final String action; // 'block' or 'allow'
  final bool autoReject; // Whether to automatically reject the call
  final String riskLevel; // 'LOW', 'MEDIUM', 'HIGH'
  final String confidence; // Confidence level of the assessment
  final int? score;
  final String? category;
  final String? description;
  final String? reason;
  final String? error;
  final Map<String, dynamic>? warning; // Warning details if any
  final String? sessionId; // Session ID for tracking

  CallCheckResult({
    required this.action,
    required this.autoReject,
    required this.riskLevel,
    required this.confidence,
    this.score,
    this.category,
    this.description,
    this.reason,
    this.error,
    this.warning,
    this.sessionId,
  });

  factory CallCheckResult.fromJson(Map<String, dynamic> json) {
    return CallCheckResult(
      action: json['action'] ?? 'allow',
      autoReject: json['autoReject'] ?? false,
      riskLevel: json['riskLevel'] ?? 'LOW',
      confidence: json['confidence'] ?? 'UNKNOWN',
      score: json['score'],
      category: json['category'],
      description: json['description'],
      reason: json['reason'],
      error: json['error'],
      warning: json['warning'],
      sessionId: json['sessionId'],
    );
  }

  bool get shouldBlock => action == 'block';
  bool get shouldAllow => action == 'allow';
}
