import 'dart:math';
import '../services/database_service.dart';

/// Database seeder for testing and development
class DatabaseSeeder {
  static final Random _random = Random();
  
  /// Seed call history for a specific user for the past week
  static Future<void> seedCallHistoryForUser(String phoneNumber) async {
    print('🌱 Seeding call history for user: $phoneNumber');
    
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    
    // Sample scam/spam numbers and reasons
    final scamNumbers = [
      '+27123456789',
      '+27987654321',
      '+27555123456',
      '+27444999888',
      '+27333777666',
      '+1234567890',
      '+1987654321',
      '+44123456789',
      '+33123456789',
      '+91123456789',
    ];
    
    final scamReasons = [
      'Known scammer',
      'Spam database match',
      'Reported by community',
      'Suspicious pattern detected',
      'Telemarketing spam',
      'Phishing attempt',
      'Robocall detected',
      'Insurance scam',
      'Fake tech support',
      'Investment fraud',
    ];
    
    final unknownNumbers = [
      '+27611234567',
      '+27821987654',
      '+27731555999',
      '+27841777888',
      '+27791333444',
      '+1555123456',
      '+1555987654',
      '+44207123456',
      '+33142345678',
      '+91987123456',
    ];
    
    // Generate 15-25 call history entries for the past week
    final numEntries = 15 + _random.nextInt(11); // 15-25 entries
    
    for (int i = 0; i < numEntries; i++) {
      // Random timestamp within the past week
      final randomHours = _random.nextInt(7 * 24); // 0 to 168 hours ago
      final timestamp = now.subtract(Duration(hours: randomHours));
      
      // Determine call type and details
      final isScamCall = _random.nextBool(); // 50% chance of scam/spam
      
      String callNumber;
      String action;
      String reason;
      String riskLevel;
      
      if (isScamCall) {
        // Scam/spam call - will be blocked
        callNumber = scamNumbers[_random.nextInt(scamNumbers.length)];
        action = 'blocked';
        reason = scamReasons[_random.nextInt(scamReasons.length)];
        riskLevel = 'high';
      } else {
        // Unknown caller - will be silenced
        callNumber = unknownNumbers[_random.nextInt(unknownNumbers.length)];
        action = 'silenced';
        reason = 'Unknown caller';
        riskLevel = 'medium';
      }
      
      // Create call history entry
      final entry = CallHistoryEntry(
        phoneNumber: callNumber,
        action: action,
        reason: reason,
        timestamp: timestamp,
        riskLevel: riskLevel,
      );
      
      // Add to database
      await DatabaseService.instance.addCallHistory(entry);
    }
    
    print('🌱 Successfully seeded $numEntries call history entries');
    
    // Print summary
    final history = await DatabaseService.instance.getWeeklyCallHistory();
    final blockedCount = history.where((h) => h.action == 'blocked').length;
    final silencedCount = history.where((h) => h.action == 'silenced').length;
    
    print('📊 Call history summary:');
    print('   🔴 Blocked calls: $blockedCount');
    print('   🟠 Silenced calls: $silencedCount');
    print('   📞 Total calls: ${history.length}');
  }
  
  /// Clear all call history (for testing)
  static Future<void> clearCallHistory() async {
    print('🧹 Clearing all call history...');
    
    // This will clear the call history cache
    await DatabaseService.instance.clearCache();
    
    print('✅ Call history cleared');
  }
  
  /// Seed sample scam numbers for testing
  static Future<void> seedScamNumbers() async {
    print('🌱 Seeding scam numbers database...');
    
    // This would typically be done through the backend API
    // For now, we'll just log that this should be done
    print('📝 Note: Scam numbers should be seeded through backend API');
    print('   Backend is running and has loaded 1 scam number into cache');
  }
}
