import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Single base URL for iOS Simulator and Docker deployment
  static const String _baseUrl =
      'http://127.0.0.1:3000'; // iOS Simulator compatible

  /// Get authentication headers
  static Future<Map<String, String>> get _authHeaders async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Enhanced multi-API call checking with aggregated results
  static Future<CallCheckResult> checkCall(
    String phoneNumber, {
    String? sessionId,
  }) async {
    try {
      final headers = await _authHeaders;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/calls/analyze'),
            headers: headers,
            body: jsonEncode({
              'phoneNumber': phoneNumber,
              'sessionId': sessionId,
              'requestedApis': [
                'hiya',
                'truecaller',
                'telesign',
              ], // Multi-API request
              'aggregationStrategy': 'weighted_consensus',
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15)); // Longer timeout for multi-API

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CallCheckResult.fromJson(data);
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return _createFallbackResult('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network error: $e');
      return _createFallbackResult('Network error: $e');
    }
  }

  /// Create fallback result when API fails
  static CallCheckResult _createFallbackResult(String error) {
    return CallCheckResult(
      action: 'allow',
      autoReject: false,
      riskLevel: 'LOW',
      confidence: 'UNKNOWN',
      error: error,
      reason: 'API unavailable - allowing call for safety',
    );
  }

  /// Start real-time audio analysis session
  static Future<String?> startAnalysisSession({
    required String phoneNumber,
    required String callId,
  }) async {
    try {
      final baseUrl = _baseUrl;
      final headers = await _authHeaders;

      final response = await http
          .post(
            Uri.parse('$baseUrl/analysis/start'),
            headers: headers,
            body: jsonEncode({
              'phoneNumber': phoneNumber,
              'callId': callId,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sessionId'];
      }
      return null;
    } catch (e) {
      print('❌ Error starting analysis session: $e');
      return null;
    }
  }

  /// End real-time audio analysis session
  static Future<bool> endAnalysisSession(String sessionId) async {
    try {
      final baseUrl = _baseUrl;
      final headers = await _authHeaders;

      final response = await http
          .post(
            Uri.parse('$baseUrl/analysis/end'),
            headers: headers,
            body: jsonEncode({
              'sessionId': sessionId,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error ending analysis session: $e');
      return false;
    }
  }

  /// Submit call report to backend
  static Future<bool> submitCallReport({
    required String phoneNumber,
    required String reportType,
    required String reason,
    String? callId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final baseUrl = _baseUrl;
      final headers = await _authHeaders;

      final response = await http
          .post(
            Uri.parse('$baseUrl/reports/submit'),
            headers: headers,
            body: jsonEncode({
              'phoneNumber': phoneNumber,
              'reportType': reportType,
              'reason': reason,
              'callId': callId,
              'sessionId': sessionId,
              'metadata': metadata ?? {},
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error submitting report: $e');
      return false;
    }
  }

  /// Get backend statistics and health info
  static Future<Map<String, dynamic>?> getBackendStats() async {
    try {
      final baseUrl = _baseUrl;
      final headers = await _authHeaders;

      final response = await http
          .get(Uri.parse('$baseUrl/stats'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting backend stats: $e');
      return null;
    }
  }

  /// Sync local database with backend
  static Future<Map<String, dynamic>?> syncDatabase({
    required DateTime lastSyncTime,
    int limit = 1000,
  }) async {
    try {
      final baseUrl = _baseUrl;
      final headers = await _authHeaders;

      final response = await http
          .post(
            Uri.parse('$baseUrl/sync'),
            headers: headers,
            body: jsonEncode({
              'lastSyncTime': lastSyncTime.toIso8601String(),
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error syncing database: $e');
      return null;
    }
  }

  /// Health check for the backend API
  static Future<bool> isBackendHealthy() async {
    try {
      final baseUrl = _baseUrl;
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Verify it's actually our ScamShield API
        final data = json.decode(response.body);
        return data['message']?.toString().contains('ScamShield') == true;
      }
      return false;
    } catch (e) {
      // Don't log health check failures - they're expected during development
      return false;
    }
  }

  /// Get recent call history from PostgreSQL (last 5 entries)
  static Future<List<Map<String, dynamic>>> getRecentCallHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/call-history/recent'),
        headers: await _authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      print('Failed to fetch recent call history: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error fetching recent call history: $e');
      return [];
    }
  }

  /// Get weekly call history from PostgreSQL (paginated)
  static Future<Map<String, dynamic>> getWeeklyCallHistory({int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/call-history/weekly?page=$page&limit=$limit'),
        headers: await _authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'data': List<Map<String, dynamic>>.from(data['data']),
            'pagination': data['pagination'],
            'statistics': data['statistics'],
          };
        }
      }
      print('Failed to fetch weekly call history: ${response.statusCode}');
      return {'data': [], 'pagination': {}, 'statistics': {}};
    } catch (e) {
      print('Error fetching weekly call history: $e');
      return {'data': [], 'pagination': {}, 'statistics': {}};
    }
  }

  /// Get call history statistics from PostgreSQL
  static Future<Map<String, dynamic>> getCallHistoryStats({int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/call-history/stats?days=$days'),
        headers: await _authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      print('Failed to fetch call history stats: ${response.statusCode}');
      return {'totalCalls': 0, 'blockedCalls': 0, 'silencedCalls': 0};
    } catch (e) {
      print('Error fetching call history stats: $e');
      return {'totalCalls': 0, 'blockedCalls': 0, 'silencedCalls': 0};
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
