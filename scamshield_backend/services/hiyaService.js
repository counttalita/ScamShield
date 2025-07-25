/**
 * Hiya Voice Scam Protection API Service
 */

const WebSocket = require('ws');
const { log } = require('../utils/helpers');

class HiyaService {
  constructor() {
    this.websocketUrl = process.env.HIYA_WEBSOCKET_URL;
    this.appId = process.env.HIYA_APP_ID || 'default';
    this.appSecret = process.env.HIYA_APP_SECRET;
  }

  /**
   * Connect to Hiya Voice Scam Protection API
   * @param {Object} session - Session data
   * @returns {Promise<WebSocket|null>} WebSocket connection or null
   */
  async connectToAPI(session) {
    try {
      if (!this.appSecret) {
        log('error', 'Hiya API credentials not configured');
        return null;
      }
      
      const credentials = Buffer.from(`${this.appId}:${this.appSecret}`).toString('base64');
      
      const hiyaWs = new WebSocket(this.websocketUrl, {
        headers: {
          'Authorization': `Basic ${credentials}`
        }
      });
      
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          reject(new Error('Hiya WebSocket connection timeout'));
        }, 10000);

        hiyaWs.on('open', () => {
          clearTimeout(timeout);
          log('success', `Connected to Hiya API for session ${session.id}`);
          
          // Send initial metadata frame
          const initialFrame = this.createInitialFrame(session);
          hiyaWs.send(JSON.stringify(initialFrame));
          resolve(hiyaWs);
        });
        
        hiyaWs.on('error', (error) => {
          clearTimeout(timeout);
          log('error', 'Hiya WebSocket error:', error);
          reject(error);
        });
      });
    } catch (error) {
      log('error', 'Failed to connect to Hiya API:', error);
      return null;
    }
  }

  /**
   * Create initial metadata frame for Hiya API
   * @param {Object} session - Session data
   * @returns {Object} Initial frame object
   */
  createInitialFrame(session) {
    return {
      sampleRate: 8000, // Default sample rate for phone calls
      phone: session.phoneNumber,
      userPhone: session.userPhone || '+27000000000',
      direction: session.direction,
      isContact: session.isContact,
      sipMethod: 'INVITE',
      sipHeaders: {
        'Call-ID': session.id,
        'From': `"Caller" <sip:${session.phoneNumber}@scamshield.com>`,
        'To': `"User" <sip:${session.userPhone}@scamshield.com>`,
        'Via': 'SIP/2.0/UDP scamshield.com:5060',
        'Max-Forwards': '70',
        'CSeq': '1 INVITE',
        'Contact': `"Caller" <sip:${session.phoneNumber}@scamshield.com>`,
        'Content-Length': '0'
      }
    };
  }

  /**
   * Send report to Hiya API (for user feedback)
   * @param {string} sessionId - Session ID
   * @param {boolean} isScam - Whether call was a scam
   * @param {string} transcript - Call transcript
   * @returns {Promise<boolean>} Success status
   */
  async reportSession(sessionId, isScam, transcript = '') {
    try {
      // TODO: Implement Hiya Report Session API call
      // This would use the REST API endpoint for reporting
      log('info', `Report session ${sessionId} as ${isScam ? 'SCAM' : 'NOT SCAM'}`);
      
      // For now, just log the report
      // In production, this would make an HTTP POST to Hiya's reporting endpoint
      return true;
    } catch (error) {
      log('error', 'Failed to report session to Hiya:', error);
      return false;
    }
  }

  /**
   * Validate Hiya API configuration
   * @returns {boolean} True if properly configured
   */
  isConfigured() {
    return !!(this.websocketUrl && this.appSecret);
  }

  /**
   * Get API status information
   * @returns {Object} Status information
   */
  getStatus() {
    return {
      configured: this.isConfigured(),
      websocketUrl: this.websocketUrl,
      appId: this.appId,
      hasSecret: !!this.appSecret
    };
  }
}

module.exports = HiyaService;
