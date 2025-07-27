const fs = require('fs');
const path = require('path');

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

/**
 * Backend Database Seeder for Call History
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
 * Seed call history data into backend database
 * This would typically use your actual database connection
 */
async function seedCallHistory() {
  console.log('🌱 ScamShield Backend Database Seeder');
  console.log('====================================');
  
  const targetUser = '+13456789099'; // User from backend logs
  
  try {
    // Generate realistic call history entries
    const callHistoryEntries = generateCallHistoryEntries(targetUser, 25);
    
    console.log(`📱 Seeding call history for user: ${targetUser}`);
    console.log(`📊 Generated ${callHistoryEntries.length} entries`);
    
    // In a real implementation, you would:
    // 1. Connect to PostgreSQL database
    // 2. Insert entries into call_history table
    // 3. Update user statistics
    
    // For now, we'll output the SQL that should be executed
    console.log('');
    console.log('📝 SQL to execute in PostgreSQL:');
    console.log('================================');
    
    // Create table if not exists
    console.log(`
-- Create call_history table if not exists
CREATE TABLE IF NOT EXISTS call_history (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(20) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  action VARCHAR(20) NOT NULL,
  reason TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  risk_level VARCHAR(10) NOT NULL,
  session_id VARCHAR(50),
  api_provider VARCHAR(20),
  confidence DECIMAL(3,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`);
    
    // Generate INSERT statements
    console.log('\\n-- Insert call history entries');
    callHistoryEntries.forEach((entry, index) => {
      console.log(`INSERT INTO call_history (user_id, phone_number, action, reason, timestamp, risk_level, session_id, api_provider, confidence) VALUES ('${entry.userId}', '${entry.phoneNumber}', '${entry.action}', '${entry.reason}', '${entry.timestamp}', '${entry.riskLevel}', '${entry.sessionId}', '${entry.apiProvider}', ${entry.confidence.toFixed(2)});`);
    });
    
    // Statistics
    const blockedCount = callHistoryEntries.filter(e => e.action === 'blocked').length;
    const silencedCount = callHistoryEntries.filter(e => e.action === 'silenced').length;
    
    console.log('');
    console.log('📊 Call History Summary:');
    console.log(`   🔴 Blocked calls: ${blockedCount}`);
    console.log(`   🟠 Silenced calls: ${silencedCount}`);
    console.log(`   📞 Total calls: ${callHistoryEntries.length}`);
    console.log(`   📅 Date range: Past 7 days`);
    
    console.log('');
    console.log('✅ Database seeding SQL generated!');
    console.log('💡 Copy the SQL above and execute it in your PostgreSQL database');
    
  } catch (error) {
    console.error('❌ Error seeding database:', error);
  }
}

// Run the seeder
if (require.main === module) {
  seedCallHistory();
}

module.exports = { seedCallHistory, generateCallHistoryEntries };
