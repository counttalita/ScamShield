import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// Service for reporting scam calls and managing call reports
class CallReportingService {
  static final CallReportingService _instance = CallReportingService._internal();
  factory CallReportingService() => _instance;
  CallReportingService._internal();

  static CallReportingService get instance => _instance;

  static const String _baseUrl = 'https://your-backend.com/api';

  /// Report a call as scam/spam
  Future<bool> reportCall({
    required String phoneNumber,
    required String reportType, // 'scam', 'spam', 'robocall', 'telemarketing'
    required String reason,
    String? callId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get user authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        print('❌ No auth token found for reporting');
        return false;
      }

      // Prepare report data
      final reportData = {
        'phoneNumber': phoneNumber,
        'reportType': reportType,
        'reason': reason,
        'callId': callId,
        'sessionId': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      };

      // Send report to backend
      final response = await http.post(
        Uri.parse('$_baseUrl/reports/call'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(reportData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Store report locally for offline access
        await _storeReportLocally(reportData);
        
        // Add to local database cache
        await _updateLocalCache(phoneNumber, reportType, reason);
        
        print('✅ Call report submitted successfully');
        return true;
      } else {
        print('❌ Failed to submit report: ${response.statusCode}');
        // Store for retry later
        await _storeFailedReport(reportData);
        return false;
      }
    } catch (e) {
      print('❌ Error reporting call: $e');
      // Store for retry later
      await _storeFailedReport({
        'phoneNumber': phoneNumber,
        'reportType': reportType,
        'reason': reason,
        'callId': callId,
        'sessionId': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      });
      return false;
    }
  }

  /// Get user's call reports
  Future<List<CallReport>> getUserReports({int limit = 50}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return await _getLocalReports(limit);
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/reports/user?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reports = (data['reports'] as List)
            .map((report) => CallReport.fromJson(report))
            .toList();
        
        // Cache reports locally
        await _cacheReports(reports);
        return reports;
      } else {
        print('❌ Failed to fetch reports: ${response.statusCode}');
        return await _getLocalReports(limit);
      }
    } catch (e) {
      print('❌ Error fetching reports: $e');
      return await _getLocalReports(limit);
    }
  }

  /// Get reports for a specific phone number
  Future<List<CallReport>> getReportsForNumber(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return await _getLocalReportsForNumber(phoneNumber);
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/reports/number/${Uri.encodeComponent(phoneNumber)}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['reports'] as List)
            .map((report) => CallReport.fromJson(report))
            .toList();
      } else {
        return await _getLocalReportsForNumber(phoneNumber);
      }
    } catch (e) {
      print('❌ Error fetching reports for number: $e');
      return await _getLocalReportsForNumber(phoneNumber);
    }
  }

  /// Retry failed reports
  Future<void> retryFailedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedReportsJson = prefs.getStringList('failed_reports') ?? [];
      
      if (failedReportsJson.isEmpty) return;

      final List<Map<String, dynamic>> successfulReports = [];
      
      for (final reportJson in failedReportsJson) {
        final reportData = json.decode(reportJson);
        
        final success = await reportCall(
          phoneNumber: reportData['phoneNumber'],
          reportType: reportData['reportType'],
          reason: reportData['reason'],
          callId: reportData['callId'],
          sessionId: reportData['sessionId'],
          metadata: reportData['metadata'],
        );
        
        if (success) {
          successfulReports.add(reportData);
        }
      }

      // Remove successful reports from failed list
      if (successfulReports.isNotEmpty) {
        final remainingFailed = failedReportsJson.where((reportJson) {
          final reportData = json.decode(reportJson);
          return !successfulReports.any((successful) => 
              successful['phoneNumber'] == reportData['phoneNumber'] &&
              successful['timestamp'] == reportData['timestamp']);
        }).toList();
        
        await prefs.setStringList('failed_reports', remainingFailed);
        print('✅ Retried ${successfulReports.length} failed reports');
      }
    } catch (e) {
      print('❌ Error retrying failed reports: $e');
    }
  }

  /// Store report locally
  Future<void> _storeReportLocally(Map<String, dynamic> reportData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList('local_reports') ?? [];
      
      reportsJson.add(json.encode(reportData));
      
      // Keep only last 100 reports
      if (reportsJson.length > 100) {
        reportsJson.removeRange(0, reportsJson.length - 100);
      }
      
      await prefs.setStringList('local_reports', reportsJson);
    } catch (e) {
      print('❌ Error storing report locally: $e');
    }
  }

  /// Store failed report for retry
  Future<void> _storeFailedReport(Map<String, dynamic> reportData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedReportsJson = prefs.getStringList('failed_reports') ?? [];
      
      failedReportsJson.add(json.encode(reportData));
      
      // Keep only last 50 failed reports
      if (failedReportsJson.length > 50) {
        failedReportsJson.removeRange(0, failedReportsJson.length - 50);
      }
      
      await prefs.setStringList('failed_reports', failedReportsJson);
    } catch (e) {
      print('❌ Error storing failed report: $e');
    }
  }

  /// Update local database cache with report
  Future<void> _updateLocalCache(String phoneNumber, String reportType, String reason) async {
    try {
      final dbService = DatabaseService.instance;
      
      if (reportType == 'scam') {
        await dbService.addScamNumber(
          phoneNumber,
          riskLevel: 'high',
          confidence: 0.9,
          source: 'user_report',
          metadata: {
            'reportType': reportType,
            'reason': reason,
            'reportedAt': DateTime.now().toIso8601String(),
          },
        );
      } else if (reportType == 'spam' || reportType == 'robocall' || reportType == 'telemarketing') {
        await dbService.addSpamNumber(
          phoneNumber,
          source: 'user_report',
          metadata: {
            'reportType': reportType,
            'reason': reason,
            'reportedAt': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      print('❌ Error updating local cache: $e');
    }
  }

  /// Get local reports
  Future<List<CallReport>> _getLocalReports(int limit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList('local_reports') ?? [];
      
      return reportsJson
          .take(limit)
          .map((reportJson) {
            final data = json.decode(reportJson);
            return CallReport.fromJson(data);
          })
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('❌ Error getting local reports: $e');
      return [];
    }
  }

  /// Get local reports for specific number
  Future<List<CallReport>> _getLocalReportsForNumber(String phoneNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList('local_reports') ?? [];
      
      return reportsJson
          .map((reportJson) {
            final data = json.decode(reportJson);
            return CallReport.fromJson(data);
          })
          .where((report) => report.phoneNumber == phoneNumber)
          .toList();
    } catch (e) {
      print('❌ Error getting local reports for number: $e');
      return [];
    }
  }

  /// Cache reports locally
  Future<void> _cacheReports(List<CallReport> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = reports
          .map((report) => json.encode(report.toJson()))
          .toList();
      
      await prefs.setStringList('cached_reports', reportsJson);
    } catch (e) {
      print('❌ Error caching reports: $e');
    }
  }
}

/// Call report data model
class CallReport {
  final String id;
  final String phoneNumber;
  final String reportType;
  final String reason;
  final String? callId;
  final String? sessionId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  CallReport({
    required this.id,
    required this.phoneNumber,
    required this.reportType,
    required this.reason,
    this.callId,
    this.sessionId,
    required this.timestamp,
    this.metadata = const {},
  });

  factory CallReport.fromJson(Map<String, dynamic> json) {
    return CallReport(
      id: json['id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      reportType: json['reportType'] ?? '',
      reason: json['reason'] ?? '',
      callId: json['callId'],
      sessionId: json['sessionId'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'reportType': reportType,
      'reason': reason,
      'callId': callId,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}
