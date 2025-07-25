/**
 * Database Service - Local cache for scam/spam numbers
 * Stores known scam numbers to check before making API calls
 */

const fs = require('fs').promises;
const path = require('path');
const { log } = require('../utils/helpers');

class DatabaseService {
  constructor() {
    this.dbPath = path.join(__dirname, '../data');
    this.scamNumbersFile = path.join(this.dbPath, 'scam_numbers.json');
    this.userReportsFile = path.join(this.dbPath, 'user_reports.json');
    this.statisticsFile = path.join(this.dbPath, 'db_statistics.json');
    
    // In-memory cache for faster lookups
    this.scamNumbersCache = new Map();
    this.userReportsCache = new Map();
    
    this.initialized = false;
  }

  /**
   * Initialize the database service
   */
  async initialize() {
    try {
      // Create data directory if it doesn't exist
      await fs.mkdir(this.dbPath, { recursive: true });
      
      // Load existing data into memory cache
      await this.loadScamNumbers();
      await this.loadUserReports();
      
      this.initialized = true;
      log('success', 'Database service initialized successfully');
      
      // Log initial statistics
      const stats = await this.getStatistics();
      log('info', `Loaded ${stats.totalScamNumbers} scam numbers and ${stats.totalUserReports} user reports`);
      
    } catch (error) {
      log('error', 'Failed to initialize database service:', error);
      throw error;
    }
  }

  /**
   * Load scam numbers from file into memory cache
   */
  async loadScamNumbers() {
    try {
      const data = await fs.readFile(this.scamNumbersFile, 'utf8');
      const scamNumbers = JSON.parse(data);
      
      this.scamNumbersCache.clear();
      for (const entry of scamNumbers) {
        this.scamNumbersCache.set(entry.phoneNumber, entry);
      }
      
      log('info', `Loaded ${scamNumbers.length} scam numbers into cache`);
    } catch (error) {
      if (error.code === 'ENOENT') {
        // File doesn't exist, start with empty cache
        this.scamNumbersCache.clear();
        await this.saveScamNumbers();
        log('info', 'Created new scam numbers database');
      } else {
        log('error', 'Error loading scam numbers:', error);
      }
    }
  }

  /**
   * Load user reports from file into memory cache
   */
  async loadUserReports() {
    try {
      const data = await fs.readFile(this.userReportsFile, 'utf8');
      const userReports = JSON.parse(data);
      
      this.userReportsCache.clear();
      for (const entry of userReports) {
        this.userReportsCache.set(entry.phoneNumber, entry);
      }
      
      log('info', `Loaded ${userReports.length} user reports into cache`);
    } catch (error) {
      if (error.code === 'ENOENT') {
        // File doesn't exist, start with empty cache
        this.userReportsCache.clear();
        await this.saveUserReports();
        log('info', 'Created new user reports database');
      } else {
        log('error', 'Error loading user reports:', error);
      }
    }
  }

  /**
   * Check if a phone number is in the scam database
   * @param {string} phoneNumber - Phone number to check
   * @returns {Object|null} Scam entry if found, null otherwise
   */
  async checkScamNumber(phoneNumber) {
    if (!this.initialized) {
      await this.initialize();
    }

    const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
    const entry = this.scamNumbersCache.get(normalizedNumber);
    
    if (entry) {
      // Update last seen timestamp
      entry.lastSeen = new Date().toISOString();
      entry.hitCount = (entry.hitCount || 0) + 1;
      
      log('info', `📋 Found ${phoneNumber} in scam database (${entry.riskLevel} risk)`);
      return entry;
    }
    
    return null;
  }

  /**
   * Add a scam number to the database
   * @param {string} phoneNumber - Phone number to add
   * @param {Object} scamData - Scam detection data from Hiya API
   * @param {string} source - Source of the data ('hiya_api', 'user_report', 'manual')
   */
  async addScamNumber(phoneNumber, scamData, source = 'hiya_api') {
    if (!this.initialized) {
      await this.initialize();
    }

    const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
    const timestamp = new Date().toISOString();
    
    const entry = {
      phoneNumber: normalizedNumber,
      originalNumber: phoneNumber,
      riskLevel: this.determineRiskLevel(scamData),
      confidence: scamData.scamDialog?.confidence || 'UNKNOWN',
      category: this.determineCategory(scamData),
      source: source,
      scamData: scamData,
      firstSeen: timestamp,
      lastSeen: timestamp,
      hitCount: 0,
      autoReject: scamData.callScamRisk === 'HIGH_SCAM_RISK'
    };

    this.scamNumbersCache.set(normalizedNumber, entry);
    await this.saveScamNumbers();
    
    log('success', `📝 Added ${phoneNumber} to scam database (${entry.riskLevel} risk, source: ${source})`);
    return entry;
  }

  /**
   * Add or update a user report
   * @param {string} phoneNumber - Phone number reported
   * @param {string} reportType - 'scam', 'not_scam', 'spam'
   * @param {string} userPhone - User who made the report
   * @param {Object} additionalData - Additional report data
   */
  async addUserReport(phoneNumber, reportType, userPhone, additionalData = {}) {
    if (!this.initialized) {
      await this.initialize();
    }

    const normalizedNumber = this.normalizePhoneNumber(phoneNumber);
    const timestamp = new Date().toISOString();
    
    const report = {
      phoneNumber: normalizedNumber,
      originalNumber: phoneNumber,
      reportType: reportType,
      userPhone: userPhone,
      timestamp: timestamp,
      additionalData: additionalData
    };

    // Store user report
    const reportKey = `${normalizedNumber}_${userPhone}_${timestamp}`;
    this.userReportsCache.set(reportKey, report);
    await this.saveUserReports();
    
    // Update scam number entry if it exists
    const existingEntry = this.scamNumbersCache.get(normalizedNumber);
    if (existingEntry) {
      existingEntry.userReports = existingEntry.userReports || [];
      existingEntry.userReports.push(report);
      existingEntry.lastSeen = timestamp;
      
      // Adjust risk level based on user reports
      this.adjustRiskLevelFromReports(existingEntry);
      await this.saveScamNumbers();
    }
    
    log('info', `📋 User report added: ${phoneNumber} reported as ${reportType} by ${userPhone}`);
    return report;
  }

  /**
   * Get comprehensive statistics about the database
   */
  async getStatistics() {
    if (!this.initialized) {
      await this.initialize();
    }

    const scamNumbers = Array.from(this.scamNumbersCache.values());
    const userReports = Array.from(this.userReportsCache.values());
    
    const stats = {
      totalScamNumbers: scamNumbers.length,
      totalUserReports: userReports.length,
      riskLevels: {
        HIGH: scamNumbers.filter(n => n.riskLevel === 'HIGH').length,
        MEDIUM: scamNumbers.filter(n => n.riskLevel === 'MEDIUM').length,
        LOW: scamNumbers.filter(n => n.riskLevel === 'LOW').length
      },
      sources: {
        hiya_api: scamNumbers.filter(n => n.source === 'hiya_api').length,
        user_report: scamNumbers.filter(n => n.source === 'user_report').length,
        manual: scamNumbers.filter(n => n.source === 'manual').length
      },
      autoRejectNumbers: scamNumbers.filter(n => n.autoReject).length,
      totalHits: scamNumbers.reduce((sum, n) => sum + (n.hitCount || 0), 0),
      lastUpdated: new Date().toISOString()
    };

    // Save statistics to file
    await fs.writeFile(this.statisticsFile, JSON.stringify(stats, null, 2));
    
    return stats;
  }

  /**
   * Save scam numbers cache to file
   */
  async saveScamNumbers() {
    try {
      const scamNumbers = Array.from(this.scamNumbersCache.values());
      await fs.writeFile(this.scamNumbersFile, JSON.stringify(scamNumbers, null, 2));
    } catch (error) {
      log('error', 'Error saving scam numbers:', error);
    }
  }

  /**
   * Save user reports cache to file
   */
  async saveUserReports() {
    try {
      const userReports = Array.from(this.userReportsCache.values());
      await fs.writeFile(this.userReportsFile, JSON.stringify(userReports, null, 2));
    } catch (error) {
      log('error', 'Error saving user reports:', error);
    }
  }

  /**
   * Normalize phone number for consistent storage
   * @param {string} phoneNumber - Raw phone number
   * @returns {string} Normalized phone number
   */
  normalizePhoneNumber(phoneNumber) {
    // Remove all non-digit characters except +
    let normalized = phoneNumber.replace(/[^\d+]/g, '');
    
    // Ensure it starts with +
    if (!normalized.startsWith('+')) {
      normalized = '+' + normalized;
    }
    
    return normalized;
  }

  /**
   * Determine risk level from Hiya API data
   * @param {Object} scamData - Hiya API response
   * @returns {string} Risk level
   */
  determineRiskLevel(scamData) {
    if (scamData.callScamRisk === 'HIGH_SCAM_RISK') return 'HIGH';
    if (scamData.callScamRisk === 'MEDIUM_SCAM_RISK') return 'MEDIUM';
    return 'LOW';
  }

  /**
   * Determine category from Hiya API data
   * @param {Object} scamData - Hiya API response
   * @returns {string} Category
   */
  determineCategory(scamData) {
    if (scamData.callScamRisk === 'HIGH_SCAM_RISK') return 'scam';
    if (scamData.callScamRisk === 'MEDIUM_SCAM_RISK') return 'suspicious';
    return 'legitimate';
  }

  /**
   * Adjust risk level based on user reports
   * @param {Object} entry - Scam number entry
   */
  adjustRiskLevelFromReports(entry) {
    if (!entry.userReports || entry.userReports.length === 0) return;
    
    const scamReports = entry.userReports.filter(r => r.reportType === 'scam').length;
    const notScamReports = entry.userReports.filter(r => r.reportType === 'not_scam').length;
    
    // If multiple users report as scam, increase risk
    if (scamReports >= 3 && scamReports > notScamReports) {
      entry.riskLevel = 'HIGH';
      entry.autoReject = true;
    }
    // If multiple users report as not scam, decrease risk
    else if (notScamReports >= 3 && notScamReports > scamReports) {
      entry.riskLevel = 'LOW';
      entry.autoReject = false;
    }
  }

  /**
   * Clean up old entries (optional maintenance)
   * @param {number} daysOld - Remove entries older than this many days
   */
  async cleanupOldEntries(daysOld = 90) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);
    
    let removedCount = 0;
    
    for (const [key, entry] of this.scamNumbersCache.entries()) {
      const lastSeen = new Date(entry.lastSeen);
      if (lastSeen < cutoffDate && (entry.hitCount || 0) === 0) {
        this.scamNumbersCache.delete(key);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      await this.saveScamNumbers();
      log('info', `🧹 Cleaned up ${removedCount} old scam number entries`);
    }
    
    return removedCount;
  }
}

module.exports = DatabaseService;
