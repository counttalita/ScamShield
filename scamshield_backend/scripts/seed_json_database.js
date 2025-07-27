const fs = require('fs').promises;
const path = require('path');

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

/**
 * Backend JSON Database Seeder for Call History
 * Seeds realistic call history data for testing user: +13456789099
 * Works with the existing JSON file-based DatabaseService
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
      id: `call_${Date.now()}_${i}`,
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
 * Seed call history data into backend JSON database
 */
async function seedCallHistory() {
  console.log('🌱 ScamShield Backend JSON Database Seeder');
  console.log('==========================================');
  
  const targetUser = '+13456789099'; // User from backend logs
  const dataDir = path.join(__dirname, '..', 'data');
  const callHistoryFile = path.join(dataDir, 'call_history.json');
  
  try {
    // Ensure data directory exists
    await fs.mkdir(dataDir, { recursive: true });
    
    // Generate realistic call history entries
    const callHistoryEntries = generateCallHistoryEntries(targetUser, 25);
    
    console.log(`📱 Seeding call history for user: ${targetUser}`);
    console.log(`📊 Generated ${callHistoryEntries.length} entries`);
    
    // Load existing call history or create empty object
    let existingCallHistory = {};
    try {
      const existingData = await fs.readFile(callHistoryFile, 'utf8');
      existingCallHistory = JSON.parse(existingData);
    } catch (error) {
      console.log('📝 No existing call history file, creating new one...');
    }
    
    // Add entries for the target user
    if (!existingCallHistory[targetUser]) {
      existingCallHistory[targetUser] = [];
    }
    
    // Clear existing entries for this user (for clean seeding)
    existingCallHistory[targetUser] = [];
    
    // Add new entries
    existingCallHistory[targetUser] = callHistoryEntries;
    
    // Write back to file
    await fs.writeFile(callHistoryFile, JSON.stringify(existingCallHistory, null, 2));
    
    // Statistics
    const blockedCount = callHistoryEntries.filter(e => e.action === 'blocked').length;
    const silencedCount = callHistoryEntries.filter(e => e.action === 'silenced').length;
    
    console.log('');
    console.log('📊 Call History Summary:');
    console.log(`   🔴 Blocked calls: ${blockedCount}`);
    console.log(`   🟠 Silenced calls: ${silencedCount}`);
    console.log(`   📞 Total calls: ${callHistoryEntries.length}`);
    console.log(`   📅 Date range: Past 7 days`);
    console.log(`   💾 Saved to: ${callHistoryFile}`);
    
    // Show recent entries
    console.log('');
    console.log('📋 Recent Call History (last 5 entries):');
    const recentCalls = callHistoryEntries
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, 5);
      
    recentCalls.forEach(call => {
      const emoji = call.action === 'blocked' ? '🔴' : '🟠';
      const timeAgo = getTimeAgo(new Date(call.timestamp));
      console.log(`   ${emoji} ${call.phoneNumber} - ${call.action} (${timeAgo})`);
    });
    
    console.log('');
    console.log('✅ Backend JSON database seeding completed!');
    console.log('💡 The Flutter app will now load this call history from the backend');
    
  } catch (error) {
    console.error('❌ Error seeding database:', error);
  }
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

// Run the seeder
if (require.main === module) {
  seedCallHistory();
}

module.exports = { seedCallHistory, generateCallHistoryEntries };
