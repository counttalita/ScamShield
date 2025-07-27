import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'contacts_service.dart';

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
      final silenceUnknownNumbers = prefs.getBool('silence_unknown_numbers') ?? false;
      
      if (!isProtectionEnabled) {
        print('🔓 Protection disabled, allowing call');
        return;
      }

      // STEP 1: Check local database cache first (fastest)
      print('🔍 Checking local database cache for $phoneNumber');
      final cacheResult = await DatabaseService.instance.checkScamNumber(phoneNumber);
      
      CallCheckResult? finalResult;
      
      if (cacheResult.source != 'cache_miss' && cacheResult.source != 'error') {
        // Found in cache - use cached result
        print('💾 Cache HIT for $phoneNumber: ${cacheResult.riskLevel} (confidence: ${cacheResult.confidence})');
        finalResult = _convertScamResultToCallResult(cacheResult);
      } else {
        // STEP 2: Check if number is in contacts (whitelist)
        print('📱 Checking contacts for $phoneNumber');
        final isContact = await _isInContacts(phoneNumber);
        
        if (isContact) {
          print('👤 Number is in contacts - allowing call');
          await DatabaseService.instance.addToWhitelist(phoneNumber, 'contacts');
          finalResult = CallCheckResult(
            action: 'allow',
            autoReject: false,
            riskLevel: 'LOW',
            confidence: 'HIGH',
            score: 0,
          );
        } else {
          // STEP 3: Check with backend API (slowest but most comprehensive)
          print('🌐 Checking with backend API for $phoneNumber');
          finalResult = await ApiService.checkCall(phoneNumber);
          
          // Cache the API result for future use
          await _cacheApiResult(phoneNumber, finalResult);
        }
      }
      
      print('🔍 Final result for $phoneNumber: ${finalResult.action} (score: ${finalResult.score})');
      print('🎯 Risk level: ${finalResult.riskLevel}, Auto-reject: ${finalResult.autoReject}');
      
      // STEP 4: Take action based on risk assessment
      await _takeCallAction(phoneNumber, finalResult, silenceUnknownNumbers);
      
      // Log the call for statistics
      await _logCall(phoneNumber, finalResult);
      
    } catch (e) {
      print('❌ Error handling incoming call: $e');
      // In case of error, allow the call for safety
    }
  }

  /// Convert ScamCheckResult to CallCheckResult
  static CallCheckResult _convertScamResultToCallResult(ScamCheckResult scamResult) {
    return CallCheckResult(
      action: scamResult.shouldAutoReject ? 'auto_reject' : 
              scamResult.shouldBlock ? 'block' : 'allow',
      autoReject: scamResult.shouldAutoReject,
      riskLevel: scamResult.riskLevel.toUpperCase(),
      confidence: scamResult.confidence > 0.8 ? 'HIGH' : 
                  scamResult.confidence > 0.5 ? 'MEDIUM' : 'LOW',
      score: (scamResult.confidence * 100).round(),
      category: scamResult.isScam ? 'SCAM' : scamResult.isSpam ? 'SPAM' : 'UNKNOWN',
      description: 'Cached result from ${scamResult.source}',
    );
  }

  /// Check if phone number is in user's contacts
  static Future<bool> _isInContacts(String phoneNumber) async {
    try {
      final contactsService = ContactsService.instance;
      final hasPermission = await contactsService.hasContactsPermission();
      
      if (!hasPermission) {
        print('📱 No contacts permission - cannot check contacts');
        return false;
      }
      
      return await contactsService.isNumberInContacts(phoneNumber);
    } catch (e) {
      print('❌ Error checking contacts: $e');
      return false;
    }
  }

  /// Cache API result in local database
  static Future<void> _cacheApiResult(String phoneNumber, CallCheckResult result) async {
    try {
      final dbService = DatabaseService.instance;
      
      // Convert confidence string to double for database storage
      double confidenceValue = result.confidence == 'HIGH' ? 0.9 : 
                              result.confidence == 'MEDIUM' ? 0.6 : 0.3;
      
      if (result.shouldBlock || result.autoReject) {
        await dbService.addScamNumber(
          phoneNumber,
          riskLevel: result.riskLevel.toLowerCase(),
          confidence: confidenceValue,
          source: 'api_backend',
          metadata: {
            'action': result.action,
            'score': result.score ?? 0,
            'category': result.category ?? 'unknown',
            'description': result.description ?? '',
            'cached_at': DateTime.now().toIso8601String(),
          },
        );
      } else if (result.category == 'SPAM' || result.action.contains('spam')) {
        await dbService.addSpamNumber(
          phoneNumber,
          source: 'api_backend',
          metadata: {
            'score': result.score ?? 0,
            'confidence_level': result.confidence,
            'category': result.category ?? 'spam',
            'cached_at': DateTime.now().toIso8601String(),
          },
        );
      }
      
      print('💾 Cached API result for $phoneNumber');
    } catch (e) {
      print('❌ Error caching API result: $e');
    }
  }

  /// Take appropriate action based on call risk assessment
  static Future<void> _takeCallAction(String phoneNumber, CallCheckResult result, bool silenceUnknownNumbers) async {
    try {
      if (result.shouldBlock || result.autoReject) {
        // Handle confirmed spam/scam calls - BLOCK them
        if (result.autoReject) {
          print('🚫 AUTO-REJECTING high-risk scam call from $phoneNumber');
          await _autoRejectCall(phoneNumber, result);
        } else {
          print('🛡️ BLOCKING confirmed spam call from $phoneNumber');
          await _blockCall(phoneNumber, result);
        }
      } else if (result.action == 'unknown' && silenceUnknownNumbers) {
        // Handle unknown callers - SILENCE them (don't block)
        print('🔇 SILENCING unknown caller from $phoneNumber');
        await _silenceCall(phoneNumber, result);
      } else {
        print('✅ Call allowed from $phoneNumber');
      }
    } catch (e) {
      print('❌ Error taking call action: $e');
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

  /// Block the incoming call (for confirmed spam/scam calls)
  static Future<void> _blockCall(String phoneNumber, CallCheckResult result) async {
    try {
      print('🛡️ Blocking confirmed spam/scam call from $phoneNumber');
      
      // End the call using native method
      await _channel.invokeMethod('endCall');
      
      // Also try native blocking method
      await _channel.invokeMethod('blockCall', {'phoneNumber': phoneNumber});
      
      // Show notification about blocked call
      await _showBlockedCallNotification(phoneNumber, result);
      
      // Update statistics for blocked calls
      await _updateStatistics('blocked');
      
      print('✅ Successfully blocked spam/scam call from $phoneNumber');
      
    } catch (e) {
      print('❌ Failed to block call from $phoneNumber: $e');
    }
  }

  /// Silence the incoming call (for unknown callers - they can still leave voicemail)
  static Future<void> _silenceCall(String phoneNumber, CallCheckResult result) async {
    try {
      print('🔇 Silencing unknown caller from $phoneNumber');
      
      // Silence the call (mute ringer) but don't reject it completely
      // This allows the call to go to voicemail if it's legitimate
      await _channel.invokeMethod('silenceCall', {'phoneNumber': phoneNumber});
      
      // Show notification about silenced call
      await _showSilencedCallNotification(phoneNumber, result);
      
      // Update statistics for silenced calls
      await _updateStatistics('silenced');
      
      print('✅ Successfully silenced unknown caller from $phoneNumber');
      
    } catch (e) {
      print('❌ Failed to silence call from $phoneNumber: $e');
      // Fallback: if silencing fails, just log it but don't block
      print('ℹ️ Call from $phoneNumber will ring normally');
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
    print('🔔 BLOCKED call notification: $phoneNumber (${result.category ?? 'spam'}) - Call was blocked and rejected');
  }

  /// Show notification about silenced call
  static Future<void> _showSilencedCallNotification(String phoneNumber, CallCheckResult result) async {
    // This would integrate with a notification service
    // For now, just log it
    print('🔔 SILENCED call notification: $phoneNumber (unknown caller) - Call was silenced, can leave voicemail');
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
