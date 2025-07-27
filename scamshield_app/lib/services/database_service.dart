import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local database service for caching scam/spam numbers and call data
class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  
  DatabaseService._();

  // Cache keys
  static const String _scamNumbersKey = 'scam_numbers_cache';
  static const String _spamNumbersKey = 'spam_numbers_cache';
  static const String _whitelistKey = 'whitelist_numbers';
  static const String _callHistoryKey = 'call_history_cache';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _cacheVersionKey = 'cache_version';
  
  // Cache settings
  static const int maxCacheSize = 10000; // Maximum numbers to cache
  static const int cacheExpiryHours = 24; // Cache expiry in hours
  static const String currentCacheVersion = '1.0.0';

  /// Initialize the database service
  Future<void> initialize() async {
    try {
      await _cleanupExpiredCache();
      await _migrateCacheIfNeeded();
      print('📊 DatabaseService initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize DatabaseService: $e');
    }
  }

  /// Check if a number is in the scam database (high-risk)
  Future<ScamCheckResult> checkScamNumber(String phoneNumber) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      
      // Check whitelist first (trusted numbers)
      if (await _isWhitelisted(normalizedNumber)) {
        return ScamCheckResult(
          phoneNumber: phoneNumber,
          isScam: false,
          isSpam: false,
          riskLevel: 'safe',
          confidence: 1.0,
          source: 'whitelist',
          lastUpdated: DateTime.now(),
        );
      }
      
      // Check scam cache (high-risk numbers)
      final scamResult = await _checkScamCache(normalizedNumber);
      if (scamResult != null) {
        return scamResult;
      }
      
      // Check spam cache (moderate-risk numbers)
      final spamResult = await _checkSpamCache(normalizedNumber);
      if (spamResult != null) {
        return spamResult;
      }
      
      // Number not found in cache
      return ScamCheckResult(
        phoneNumber: phoneNumber,
        isScam: false,
        isSpam: false,
        riskLevel: 'unknown',
        confidence: 0.0,
        source: 'cache_miss',
        lastUpdated: DateTime.now(),
      );
      
    } catch (e) {
      print('❌ Error checking scam number: $e');
      return ScamCheckResult(
        phoneNumber: phoneNumber,
        isScam: false,
        isSpam: false,
        riskLevel: 'unknown',
        confidence: 0.0,
        source: 'error',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Add a number to the scam database
  Future<void> addScamNumber(String phoneNumber, {
    required String riskLevel,
    required double confidence,
    required String source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      final prefs = await SharedPreferences.getInstance();
      
      final scamData = ScamNumberData(
        phoneNumber: normalizedNumber,
        riskLevel: riskLevel,
        confidence: confidence,
        source: source,
        reportCount: 1,
        lastReported: DateTime.now(),
        metadata: metadata ?? {},
      );
      
      // Get existing scam numbers
      final scamNumbers = await _getScamNumbers();
      scamNumbers[normalizedNumber] = scamData;
      
      // Cleanup if cache is too large
      if (scamNumbers.length > maxCacheSize) {
        await _cleanupOldestEntries(scamNumbers);
      }
      
      // Save updated cache
      await prefs.setString(_scamNumbersKey, jsonEncode(
        scamNumbers.map((key, value) => MapEntry(key, value.toJson()))
      ));
      
      print('📊 Added scam number to cache: $normalizedNumber ($riskLevel)');
      
    } catch (e) {
      print('❌ Error adding scam number: $e');
    }
  }

  /// Add a number to the spam database
  Future<void> addSpamNumber(String phoneNumber, {
    required String source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      final prefs = await SharedPreferences.getInstance();
      
      final spamData = SpamNumberData(
        phoneNumber: normalizedNumber,
        source: source,
        reportCount: 1,
        lastReported: DateTime.now(),
        metadata: metadata ?? {},
      );
      
      // Get existing spam numbers
      final spamNumbers = await _getSpamNumbers();
      spamNumbers[normalizedNumber] = spamData;
      
      // Save updated cache
      await prefs.setString(_spamNumbersKey, jsonEncode(
        spamNumbers.map((key, value) => MapEntry(key, value.toJson()))
      ));
      
      print('📊 Added spam number to cache: $normalizedNumber');
      
    } catch (e) {
      print('❌ Error adding spam number: $e');
    }
  }

  /// Add a number to the whitelist (trusted numbers)
  Future<void> addToWhitelist(String phoneNumber, String source) async {
    try {
      final normalizedNumber = _normalizePhoneNumber(phoneNumber);
      final prefs = await SharedPreferences.getInstance();
      
      final whitelist = await _getWhitelist();
      whitelist[normalizedNumber] = {
        'source': source,
        'added_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_whitelistKey, jsonEncode(whitelist));
      print('📊 Added number to whitelist: $normalizedNumber');
      
    } catch (e) {
      print('❌ Error adding to whitelist: $e');
    }
  }

  /// Sync cache with backend data
  Future<void> syncWithBackend(Map<String, dynamic> backendData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update scam numbers from backend
      if (backendData.containsKey('scam_numbers')) {
        final scamNumbers = <String, ScamNumberData>{};
        for (final entry in backendData['scam_numbers']) {
          final data = ScamNumberData.fromJson(entry);
          scamNumbers[data.phoneNumber] = data;
        }
        
        await prefs.setString(_scamNumbersKey, jsonEncode(
          scamNumbers.map((key, value) => MapEntry(key, value.toJson()))
        ));
      }
      
      // Update spam numbers from backend
      if (backendData.containsKey('spam_numbers')) {
        final spamNumbers = <String, SpamNumberData>{};
        for (final entry in backendData['spam_numbers']) {
          final data = SpamNumberData.fromJson(entry);
          spamNumbers[data.phoneNumber] = data;
        }
        
        await prefs.setString(_spamNumbersKey, jsonEncode(
          spamNumbers.map((key, value) => MapEntry(key, value.toJson()))
        ));
      }
      
      // Update last sync timestamp
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      print('📊 Successfully synced cache with backend');
      
    } catch (e) {
      print('❌ Error syncing with backend: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scamNumbers = await _getScamNumbers();
      final spamNumbers = await _getSpamNumbers();
      final whitelist = await _getWhitelist();
      final lastSync = prefs.getString(_lastSyncKey);
      
      return {
        'scam_numbers_count': scamNumbers.length,
        'spam_numbers_count': spamNumbers.length,
        'whitelist_count': whitelist.length,
        'total_cached_numbers': scamNumbers.length + spamNumbers.length,
        'last_sync': lastSync,
        'cache_version': currentCacheVersion,
        'cache_size_mb': await _calculateCacheSize(),
      };
      
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {};
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scamNumbersKey);
      await prefs.remove(_spamNumbersKey);
      await prefs.remove(_callHistoryKey);
      await prefs.remove(_lastSyncKey);
      
      print('📊 Cache cleared successfully');
      
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // Private helper methods

  Future<Map<String, ScamNumberData>> _getScamNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_scamNumbersKey);
      if (data == null) return {};
      
      final Map<String, dynamic> json = jsonDecode(data);
      return json.map((key, value) => MapEntry(key, ScamNumberData.fromJson(value)));
    } catch (e) {
      print('❌ Error getting scam numbers: $e');
      return {};
    }
  }

  Future<Map<String, SpamNumberData>> _getSpamNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_spamNumbersKey);
      if (data == null) return {};
      
      final Map<String, dynamic> json = jsonDecode(data);
      return json.map((key, value) => MapEntry(key, SpamNumberData.fromJson(value)));
    } catch (e) {
      print('❌ Error getting spam numbers: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getWhitelist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_whitelistKey);
      if (data == null) return {};
      
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      print('❌ Error getting whitelist: $e');
      return {};
    }
  }

  Future<ScamCheckResult?> _checkScamCache(String phoneNumber) async {
    final scamNumbers = await _getScamNumbers();
    final scamData = scamNumbers[phoneNumber];
    
    if (scamData != null) {
      return ScamCheckResult(
        phoneNumber: phoneNumber,
        isScam: true,
        isSpam: false,
        riskLevel: scamData.riskLevel,
        confidence: scamData.confidence,
        source: 'local_cache',
        lastUpdated: scamData.lastReported,
      );
    }
    
    return null;
  }

  Future<ScamCheckResult?> _checkSpamCache(String phoneNumber) async {
    final spamNumbers = await _getSpamNumbers();
    final spamData = spamNumbers[phoneNumber];
    
    if (spamData != null) {
      return ScamCheckResult(
        phoneNumber: phoneNumber,
        isScam: false,
        isSpam: true,
        riskLevel: 'moderate',
        confidence: 0.7,
        source: 'local_cache',
        lastUpdated: spamData.lastReported,
      );
    }
    
    return null;
  }

  Future<bool> _isWhitelisted(String phoneNumber) async {
    final whitelist = await _getWhitelist();
    return whitelist.containsKey(phoneNumber);
  }

  String _normalizePhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Handle different formats and convert to E.164 format
    if (normalized.startsWith('0')) {
      // Remove leading 0 and add country code (assuming South Africa +27)
      normalized = '+27${normalized.substring(1)}';
    } else if (!normalized.startsWith('+')) {
      // Add + if missing
      normalized = '+$normalized';
    }
    
    return normalized;
  }

  Future<void> _cleanupExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);
      
      if (lastSync != null) {
        final lastSyncTime = DateTime.parse(lastSync);
        final hoursSinceSync = DateTime.now().difference(lastSyncTime).inHours;
        
        if (hoursSinceSync > cacheExpiryHours) {
          await clearCache();
          print('📊 Expired cache cleared (${hoursSinceSync}h old)');
        }
      }
    } catch (e) {
      print('❌ Error cleaning up expired cache: $e');
    }
  }

  Future<void> _migrateCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheVersion = prefs.getString(_cacheVersionKey);
      
      if (cacheVersion != currentCacheVersion) {
        // Perform migration if needed
        await clearCache();
        await prefs.setString(_cacheVersionKey, currentCacheVersion);
        print('📊 Cache migrated to version $currentCacheVersion');
      }
    } catch (e) {
      print('❌ Error migrating cache: $e');
    }
  }

  Future<void> _cleanupOldestEntries(Map<String, ScamNumberData> scamNumbers) async {
    try {
      // Sort by last reported date and remove oldest 10%
      final sortedEntries = scamNumbers.entries.toList()
        ..sort((a, b) => a.value.lastReported.compareTo(b.value.lastReported));
      
      final entriesToRemove = (scamNumbers.length * 0.1).round();
      for (int i = 0; i < entriesToRemove; i++) {
        scamNumbers.remove(sortedEntries[i].key);
      }
      
      print('📊 Cleaned up $entriesToRemove old cache entries');
    } catch (e) {
      print('❌ Error cleaning up old entries: $e');
    }
  }

  Future<double> _calculateCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double totalSize = 0;
      
      final keys = [_scamNumbersKey, _spamNumbersKey, _whitelistKey, _callHistoryKey];
      for (final key in keys) {
        final data = prefs.getString(key);
        if (data != null) {
          totalSize += data.length;
        }
      }
      
      return totalSize / (1024 * 1024); // Convert to MB
    } catch (e) {
      print('❌ Error calculating cache size: $e');
      return 0.0;
    }
  }
}

/// Data model for scam number entries
class ScamNumberData {
  final String phoneNumber;
  final String riskLevel;
  final double confidence;
  final String source;
  final int reportCount;
  final DateTime lastReported;
  final Map<String, dynamic> metadata;

  ScamNumberData({
    required this.phoneNumber,
    required this.riskLevel,
    required this.confidence,
    required this.source,
    required this.reportCount,
    required this.lastReported,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'phone_number': phoneNumber,
    'risk_level': riskLevel,
    'confidence': confidence,
    'source': source,
    'report_count': reportCount,
    'last_reported': lastReported.toIso8601String(),
    'metadata': metadata,
  };

  factory ScamNumberData.fromJson(Map<String, dynamic> json) => ScamNumberData(
    phoneNumber: json['phone_number'],
    riskLevel: json['risk_level'],
    confidence: json['confidence'].toDouble(),
    source: json['source'],
    reportCount: json['report_count'],
    lastReported: DateTime.parse(json['last_reported']),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Data model for spam number entries
class SpamNumberData {
  final String phoneNumber;
  final String source;
  final int reportCount;
  final DateTime lastReported;
  final Map<String, dynamic> metadata;

  SpamNumberData({
    required this.phoneNumber,
    required this.source,
    required this.reportCount,
    required this.lastReported,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'phone_number': phoneNumber,
    'source': source,
    'report_count': reportCount,
    'last_reported': lastReported.toIso8601String(),
    'metadata': metadata,
  };

  factory SpamNumberData.fromJson(Map<String, dynamic> json) => SpamNumberData(
    phoneNumber: json['phone_number'],
    source: json['source'],
    reportCount: json['report_count'],
    lastReported: DateTime.parse(json['last_reported']),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Result model for scam check operations
class ScamCheckResult {
  final String phoneNumber;
  final bool isScam;
  final bool isSpam;
  final String riskLevel;
  final double confidence;
  final String source;
  final DateTime lastUpdated;

  ScamCheckResult({
    required this.phoneNumber,
    required this.isScam,
    required this.isSpam,
    required this.riskLevel,
    required this.confidence,
    required this.source,
    required this.lastUpdated,
  });

  bool get shouldAutoReject => isScam && riskLevel == 'high' && confidence > 0.8;
  bool get shouldBlock => isScam || (isSpam && confidence > 0.6);
  bool get shouldSilence => riskLevel == 'unknown' || (isSpam && confidence <= 0.6);
}
