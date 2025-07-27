const path = require('path');

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const PostgresService = require('../services/postgresService');

/**
 * PostgreSQL Database Seeder for Call History
 * Seeds realistic call history data for testing user: +13456789099
 */

// Sample data for realistic call history
const SCAM_NUMBERS = [
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

const SCAM_REASONS = [
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

const UNKNOWN_NUMBERS = [
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

/**
 * Generate realistic call history entries for the past week
 */
function generateCallHistoryEntries(userId, numEntries = 25) {
  const entries = [];
  const now = new Date();
  
  console.log(`🔢 Generating ${numEntries} call history entries for user: ${userId}`);
  
  for (let i = 0; i < numEntries; i++) {
    // Random timestamp within the past week (0-168 hours ago)
    const randomHours = Math.floor(Math.random() * 7 * 24);
    const timestamp = new Date(now.getTime() - (randomHours * 60 * 60 * 1000));
    
    // 60% chance of scam/spam calls (realistic ratio)
    const isScamCall = Math.random() < 0.6;
    
    let callNumber, action, reason, riskLevel;
    
    if (isScamCall) {
      // Scam/spam call - will be blocked
      callNumber = SCAM_NUMBERS[Math.floor(Math.random() * SCAM_NUMBERS.length)];
      action = 'blocked';
      reason = SCAM_REASONS[Math.floor(Math.random() * SCAM_REASONS.length)];
      riskLevel = 'high';
    } else {
      // Unknown caller - will be silenced  
      callNumber = UNKNOWN_NUMBERS[Math.floor(Math.random() * UNKNOWN_NUMBERS.length)];
      action = 'silenced';
      reason = 'Unknown caller';
      riskLevel = 'medium';
    }
    
    entries.push({
      userId,
      phoneNumber: callNumber,
      action,
      reason,
      timestamp: timestamp.toISOString(),
      riskLevel,
      sessionId: `session_${Date.now()}_${i}`,
      apiProvider: isScamCall ? 'hiya' : 'local',
      confidence: isScamCall ? 0.85 + (Math.random() * 0.15) : 0.5 + (Math.random() * 0.3)
    });
  }
  
  return entries;
}

/**
 * Helper function to get human-readable time ago
 */
function getTimeAgo(date) {
  const now = new Date();
  const diffMs = now - date;
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffHours / 24);
  
  if (diffDays > 0) {
    return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
  } else if (diffHours > 0) {
    return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
  } else {
    return 'Just now';
  }
}

/**
 * Seed call history data into PostgreSQL database
 */
async function seedCallHistory() {
  console.log('🌱 ScamShield PostgreSQL Database Seeder');
  console.log('========================================');
  
  const targetUser = '+13456789099'; // User from backend logs
  const db = new PostgresService();
  
  try {
    // Initialize database connection
    console.log('🔌 Connecting to PostgreSQL...');
    await db.initialize();
    
    // Clear existing call history for this user (for clean seeding)
    console.log(`🧹 Clearing existing call history for user: ${targetUser}`);
    const deletedCount = await db.clearCallHistory(targetUser);
    console.log(`   Deleted ${deletedCount} existing entries`);
    
    // Generate realistic call history entries
    const callHistoryEntries = generateCallHistoryEntries(targetUser, 25);
    
    console.log(`📱 Seeding call history for user: ${targetUser}`);
    console.log(`📊 Generated ${callHistoryEntries.length} entries`);
    
    // Insert entries into database
    console.log('💾 Inserting entries into PostgreSQL...');
    let insertedCount = 0;
    
    for (const entry of callHistoryEntries) {
      await db.addCallHistory(entry);
      insertedCount++;
      
      // Progress indicator
      if (insertedCount % 5 === 0) {
        console.log(`   📞 Inserted ${insertedCount}/${callHistoryEntries.length} entries...`);
      }
    }
    
    // Get statistics
    const stats = await db.getCallHistoryStats(targetUser);
    const recentCalls = await db.getRecentCallHistory(targetUser);
    
    console.log('');
    console.log('📊 Call History Summary:');
    console.log(`   🔴 Blocked calls: ${stats.blocked_calls}`);
    console.log(`   🟠 Silenced calls: ${stats.silenced_calls}`);
    console.log(`   📞 Total calls: ${stats.total_calls}`);
    console.log(`   📅 Date range: Past 7 days`);
    console.log(`   💾 Stored in PostgreSQL database`);
    
    // Show recent entries
    console.log('');
    console.log('📋 Recent Call History (last 5 entries):');
    recentCalls.forEach(call => {
      const emoji = call.action === 'blocked' ? '🔴' : '🟠';
      const timeAgo = getTimeAgo(new Date(call.timestamp));
      console.log(`   ${emoji} ${call.phone_number} - ${call.action} (${timeAgo})`);
    });
    
    console.log('');
    console.log('✅ PostgreSQL database seeding completed!');
    console.log(`💡 User ${targetUser} now has realistic call history data`);
    console.log('🚀 The Flutter app can now fetch this data via backend API');
    
  } catch (error) {
    console.error('❌ Error seeding PostgreSQL database:', error.message);
  } finally {
    // Close database connection
    await db.close();
  }
}

// Run the seeder
if (require.main === module) {
  seedCallHistory();
}

module.exports = { seedCallHistory, generateCallHistoryEntries };
