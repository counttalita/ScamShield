import 'dart:math';
import '../services/database_service.dart';

/// Standalone database seeding script for development/testing
/// Run this manually to seed call history for specific users
void main() async {
  print('🌱 ScamShield Database Seeder');
  print('============================');
  
  // Initialize database service
  await DatabaseService.instance.initialize();
  
  // User from backend logs: +13456789099
  const targetUser = '+13456789099';
  
  print('📱 Seeding call history for user: $targetUser');
  
  await seedCallHistoryForUser(targetUser);
  
  print('✅ Database seeding completed!');
}

/// Seed realistic call history for a specific user for the past week
Future<void> seedCallHistoryForUser(String phoneNumber) async {
  final random = Random();
  final now = DateTime.now();
  
  // Sample scam/spam numbers with South African and international numbers
  final scamNumbers = [
    '+27123456789',  // SA scammer
    '+27987654321',  // SA telemarketer
    '+27555123456',  // SA robocaller
    '+27444999888',  // SA phishing
    '+27333777666',  // SA insurance scam
    '+1234567890',   // US robocaller
    '+1987654321',   // US telemarketer
    '+44123456789',  // UK scammer
    '+33123456789',  // France spam
    '+91123456789',  // India call center
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
    'Lottery scam',
    'Bank fraud attempt',
  ];
  
  final unknownNumbers = [
    '+27611234567',  // SA mobile
    '+27821987654',  // SA mobile
    '+27731555999',  // SA mobile
    '+27841777888',  // SA mobile
    '+27791333444',  // SA mobile
    '+1555123456',   // US number
    '+1555987654',   // US number
    '+44207123456',  // UK London
    '+33142345678',  // France Paris
    '+91987123456',  // India mobile
  ];
  
  // Generate 20-30 call history entries for the past week
  final numEntries = 20 + random.nextInt(11); // 20-30 entries
  
  print('🔢 Generating $numEntries call history entries...');
  
  for (int i = 0; i < numEntries; i++) {
    // Random timestamp within the past week (0-168 hours ago)
    final randomHours = random.nextInt(7 * 24);
    final timestamp = now.subtract(Duration(hours: randomHours));
    
    // 60% chance of scam/spam calls (realistic ratio)
    final isScamCall = random.nextDouble() < 0.6;
    
    String callNumber;
    String action;
    String reason;
    String riskLevel;
    
    if (isScamCall) {
      // Scam/spam call - will be blocked
      callNumber = scamNumbers[random.nextInt(scamNumbers.length)];
      action = 'blocked';
      reason = scamReasons[random.nextInt(scamReasons.length)];
      riskLevel = 'high';
    } else {
      // Unknown caller - will be silenced
      callNumber = unknownNumbers[random.nextInt(unknownNumbers.length)];
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
    
    // Progress indicator
    if ((i + 1) % 5 == 0) {
      print('   📞 Added ${i + 1}/$numEntries entries...');
    }
  }
  
  // Print summary
  final history = await DatabaseService.instance.getWeeklyCallHistory();
  final blockedCount = history.where((h) => h.action == 'blocked').length;
  final silencedCount = history.where((h) => h.action == 'silenced').length;
  
  print('');
  print('📊 Call History Summary for $phoneNumber:');
  print('   🔴 Blocked calls: $blockedCount');
  print('   🟠 Silenced calls: $silencedCount');
  print('   📞 Total calls: ${history.length}');
  print('   📅 Date range: Past 7 days');
  
  // Show recent entries
  print('');
  print('📋 Recent Call History (last 5 entries):');
  final recentCalls = await DatabaseService.instance.getRecentCallHistory();
  for (int i = 0; i < recentCalls.length.clamp(0, 5); i++) {
    final call = recentCalls[i];
    final emoji = call.action == 'blocked' ? '🔴' : '🟠';
    print('   $emoji ${call.phoneNumber} - ${call.action} (${call.timeAgo})');
  }
}
