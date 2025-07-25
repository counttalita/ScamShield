import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class CallService {
  static const MethodChannel _channel = MethodChannel('scamshield/call_blocker');
  static bool _isInitialized = false;

  /// Initialize the call service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Set up method channel for native call blocking
      _channel.setMethodCallHandler(_handleMethodCall);
      
      _isInitialized = true;
      print('📞 CallService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize CallService: $e');
    }
  }

  /// Simulate incoming call check (for demo purposes)
  static Future<void> simulateIncomingCall(String phoneNumber) async {
    print('📞 Simulating incoming call from: $phoneNumber');
    await _handleIncomingCall({'handle': phoneNumber});
  }

  /// Handle incoming call and check if it should be blocked
  static Future<void> _handleIncomingCall(dynamic callData) async {
    try {
      final phoneNumber = callData['handle'] ?? callData['number'] ?? '';
      
      if (phoneNumber.isEmpty) {
        print('⚠️ No phone number found in call data');
        return;
      }

      print('📞 Incoming call from: $phoneNumber');
      
      // Check if protection is enabled
      final prefs = await SharedPreferences.getInstance();
      final isProtectionEnabled = prefs.getBool('protection_enabled') ?? true;
      
      if (!isProtectionEnabled) {
        print('🔓 Protection disabled, allowing call');
        return;
      }

      // Check with backend API
      final result = await ApiService.checkCall(phoneNumber);
      
      print('🔍 API result for $phoneNumber: ${result.action} (score: ${result.score})');
      print('🎯 Risk level: ${result.riskLevel}, Auto-reject: ${result.autoReject}');
      
      if (result.shouldBlock || result.autoReject) {
        // Automatically reject high-risk scam calls
        if (result.autoReject) {
          print('🚫 AUTO-REJECTING high-risk scam call from $phoneNumber');
          await _autoRejectCall(phoneNumber, result);
        } else {
          print('🛡️ Blocking suspicious call from $phoneNumber');
          await _blockCall(phoneNumber, result);
        }
      } else {
        print('✅ Call allowed from $phoneNumber');
      }
      
      // Log the call for statistics
      await _logCall(phoneNumber, result);
      
    } catch (e) {
      print('❌ Error handling incoming call: $e');
      // In case of error, allow the call for safety
    }
  }

  /// Automatically reject high-risk scam call (immediate, silent rejection)
  static Future<void> _autoRejectCall(String phoneNumber, CallCheckResult result) async {
    try {
      print('🚫 AUTO-REJECTING high-risk scam call from $phoneNumber');
      
      // Immediately end/reject the call without ringing
      await _channel.invokeMethod('rejectCall', {'phoneNumber': phoneNumber});
      
      // Try multiple rejection methods for better compatibility
      await _channel.invokeMethod('endCall');
      await _channel.invokeMethod('blockCall', {'phoneNumber': phoneNumber});
      
      // Show notification about auto-rejected call
      await _showAutoRejectedCallNotification(phoneNumber, result);
      
      // Update statistics for auto-rejected calls
      await _updateStatistics('auto_rejected');
      
      print('✅ Successfully auto-rejected high-risk scam call from $phoneNumber');
      
    } catch (e) {
      print('❌ Failed to auto-reject call from $phoneNumber: $e');
      // Fallback to regular blocking if auto-reject fails
      await _blockCall(phoneNumber, result);
    }
  }

  /// Block the incoming call (for medium-risk calls)
  static Future<void> _blockCall(String phoneNumber, CallCheckResult result) async {
    try {
      print('🛡️ Blocking suspicious call from $phoneNumber');
      
      // End the call using native method
      await _channel.invokeMethod('endCall');
      
      // Also try native blocking method
      await _channel.invokeMethod('blockCall', {'phoneNumber': phoneNumber});
      
      // Show notification about blocked call
      await _showBlockedCallNotification(phoneNumber, result);
      
      print('✅ Successfully blocked call from $phoneNumber');
      
    } catch (e) {
      print('❌ Failed to block call from $phoneNumber: $e');
    }
  }

  /// Show notification about auto-rejected call
  static Future<void> _showAutoRejectedCallNotification(String phoneNumber, CallCheckResult result) async {
    // This would integrate with a notification service
    // For now, just log it
    print('🔔 AUTO-REJECTED call notification: $phoneNumber - High-risk scam detected and blocked automatically');
  }

  /// Show notification about blocked call
  static Future<void> _showBlockedCallNotification(String phoneNumber, CallCheckResult result) async {
    // This would integrate with a notification service
    // For now, just log it
    print('🔔 Blocked call notification: $phoneNumber (${result.category ?? 'spam'})');
  }

  /// Log call for statistics and history
  static Future<void> _logCall(String phoneNumber, CallCheckResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final callHistory = prefs.getStringList('call_history') ?? [];
      
      final logEntry = {
        'phoneNumber': phoneNumber,
        'action': result.action,
        'timestamp': DateTime.now().toIso8601String(),
        'score': result.score,
        'category': result.category,
      };
      
      callHistory.add(logEntry.toString());
      
      // Keep only last 100 entries
      if (callHistory.length > 100) {
        callHistory.removeAt(0);
      }
      
      await prefs.setStringList('call_history', callHistory);
      
      // Update statistics
      await _updateStatistics(result.action);
      
    } catch (e) {
      print('❌ Failed to log call: $e');
    }
  }

  /// Update call statistics
  static Future<void> _updateStatistics(String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (action == 'block') {
        final blockedCount = prefs.getInt('blocked_calls_count') ?? 0;
        await prefs.setInt('blocked_calls_count', blockedCount + 1);
      } else {
        final allowedCount = prefs.getInt('allowed_calls_count') ?? 0;
        await prefs.setInt('allowed_calls_count', allowedCount + 1);
      }
      
    } catch (e) {
      print('❌ Failed to update statistics: $e');
    }
  }

  /// Handle method calls from native code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onIncomingCall':
        final phoneNumber = call.arguments['phoneNumber'] as String;
        await _handleIncomingCall({'handle': phoneNumber});
        return null;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Get call statistics
  static Future<Map<String, int>> getStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'blocked': prefs.getInt('blocked_calls_count') ?? 0,
      'allowed': prefs.getInt('allowed_calls_count') ?? 0,
    };
  }

  /// Check if protection is enabled
  static Future<bool> isProtectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('protection_enabled') ?? true;
  }

  /// Enable/disable protection
  static Future<void> setProtectionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('protection_enabled', enabled);
    print('🛡️ Protection ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Dispose resources
  static void dispose() {
    _isInitialized = false;
  }
}
