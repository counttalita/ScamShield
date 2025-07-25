/**
 * Session Management Service
 */

const { generateSessionId, log } = require('../utils/helpers');

class SessionService {
  constructor() {
    this.activeSessions = new Map();
  }

  /**
   * Create a new analysis session
   * @param {Object} sessionData - Session initialization data
   * @returns {Object} Created session object
   */
  createSession(sessionData) {
    const { phoneNumber, userPhone, direction, isContact } = sessionData;
    
    const sessionId = generateSessionId();
    const session = {
      id: sessionId,
      phoneNumber,
      userPhone,
      direction: direction || 'Incoming',
      isContact: isContact || false,
      startTime: new Date(),
      status: 'initialized',
      transcript: [],
      results: [],
      warnings: []
    };
    
    this.activeSessions.set(sessionId, session);
    log('info', `Created analysis session ${sessionId} for ${phoneNumber}`);
    
    return session;
  }

  /**
   * Get session by ID
   * @param {string} sessionId - Session ID
   * @returns {Object|null} Session object or null if not found
   */
  getSession(sessionId) {
    return this.activeSessions.get(sessionId) || null;
  }

  /**
   * Update session status
   * @param {string} sessionId - Session ID
   * @param {string} status - New status
   * @returns {boolean} Success status
   */
  updateSessionStatus(sessionId, status) {
    const session = this.getSession(sessionId);
    if (session) {
      session.status = status;
      session.lastUpdated = new Date();
      log('info', `Session ${sessionId} status updated to: ${status}`);
      return true;
    }
    return false;
  }

  /**
   * Add transcript to session
   * @param {string} sessionId - Session ID
   * @param {Object} transcriptEvent - Transcript event from Hiya
   * @returns {boolean} Success status
   */
  addTranscript(sessionId, transcriptEvent) {
    const session = this.getSession(sessionId);
    if (session) {
      session.transcript.push({
        ...transcriptEvent,
        timestamp: new Date().toISOString()
      });
      return true;
    }
    return false;
  }

  /**
   * Add result to session
   * @param {string} sessionId - Session ID
   * @param {Object} resultEvent - Result event from Hiya
   * @returns {boolean} Success status
   */
  addResult(sessionId, resultEvent) {
    const session = this.getSession(sessionId);
    if (session) {
      session.results.push({
        ...resultEvent,
        timestamp: new Date().toISOString()
      });
      return true;
    }
    return false;
  }

  /**
   * Add warning to session
   * @param {string} sessionId - Session ID
   * @param {Object} warning - Warning object
   * @returns {boolean} Success status
   */
  addWarning(sessionId, warning) {
    const session = this.getSession(sessionId);
    if (session) {
      session.warnings.push(warning);
      log('warn', `Warning added to session ${sessionId}: ${warning.level}`);
      return true;
    }
    return false;
  }

  /**
   * Close session
   * @param {string} sessionId - Session ID
   * @returns {boolean} Success status
   */
  closeSession(sessionId) {
    const session = this.getSession(sessionId);
    if (session) {
      session.status = 'closed';
      session.endTime = new Date();
      session.duration = session.endTime - session.startTime;
      log('info', `Session ${sessionId} closed after ${session.duration}ms`);
      return true;
    }
    return false;
  }

  /**
   * Clean up old sessions (older than 1 hour)
   * @returns {number} Number of sessions cleaned up
   */
  cleanupOldSessions() {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    let cleanedCount = 0;
    
    for (const [sessionId, session] of this.activeSessions.entries()) {
      if (session.startTime < oneHourAgo) {
        this.activeSessions.delete(sessionId);
        cleanedCount++;
      }
    }
    
    if (cleanedCount > 0) {
      log('info', `Cleaned up ${cleanedCount} old sessions`);
    }
    
    return cleanedCount;
  }

  /**
   * Get session statistics
   * @returns {Object} Statistics object
   */
  getStatistics() {
    const sessions = Array.from(this.activeSessions.values());
    
    return {
      totalSessions: sessions.length,
      activeSessions: sessions.filter(s => s.status === 'connected').length,
      closedSessions: sessions.filter(s => s.status === 'closed').length,
      totalWarnings: sessions.reduce((sum, s) => sum + s.warnings.length, 0),
      scamWarnings: sessions.reduce((sum, s) => 
        sum + s.warnings.filter(w => w.level === 'SCAM').length, 0
      ),
      privacyWarnings: sessions.reduce((sum, s) => 
        sum + s.warnings.filter(w => w.level === 'PRIVACY').length, 0
      )
    };
  }

  /**
   * Get all active sessions (for debugging)
   * @returns {Array} Array of session objects
   */
  getAllSessions() {
    return Array.from(this.activeSessions.values());
  }
}

module.exports = SessionService;
