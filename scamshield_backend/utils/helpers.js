/**
 * Utility functions for ScamShield backend
 */

/**
 * Generate unique session ID
 * @returns {string} Unique session identifier
 */
function generateSessionId() {
  return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

/**
 * Process scam detection result and generate appropriate warning and action
 * @param {Object} result - Hiya API result
 * @returns {Object} Processing result with warning and recommended action
 */
function processScamResult(result) {
  const response = {
    warning: null,
    action: 'allow',
    autoReject: false,
    riskLevel: 'LOW',
    confidence: 'UNKNOWN'
  };

  if (!result || !result.callScamRisk) {
    return response;
  }

  const risk = result.callScamRisk;
  const confidence = result.scamDialog?.confidence || 'UNKNOWN';
  const syntheticVoice = result.syntheticVoice?.syntheticVoiceDetected === 'YES';
  const originatorRisk = result.callOriginatorRisk || 'UNKNOWN';

  response.confidence = confidence;

  // High-risk scam calls - AUTO REJECT
  if (risk === 'HIGH_SCAM_RISK' || (originatorRisk === 'HIGH' && confidence === 'HIGH')) {
    response.riskLevel = 'HIGH';
    response.action = 'block';
    response.autoReject = true;
    response.warning = {
      type: 'scamWarning',
      level: 'SCAM',
      title: 'Scam call blocked',
      message: 'This call has been automatically blocked due to high scam risk. We detected language or tactics commonly used by scammers.',
      actions: ['dismiss', 'viewDetails', 'reportFalsePositive'],
      confidence: confidence,
      autoBlocked: true,
      timestamp: new Date().toISOString()
    };
  }
  // Medium-risk calls - WARN but allow
  else if (risk === 'MEDIUM_SCAM_RISK' || syntheticVoice || originatorRisk === 'MEDIUM') {
    response.riskLevel = 'MEDIUM';
    response.action = 'allow';
    response.autoReject = false;
    response.warning = {
      type: 'privacyWarning',
      level: 'PRIVACY',
      title: 'Information sharing warning',
      message: 'It appears that sensitive information may be shared in this conversation. Please stop and think, and make sure you know and trust the person you are talking with. Use caution when sharing sensitive information. If you\'re unsure, end your call.',
      actions: ['dismiss', 'hangUp', 'hangUpAndReport'],
      confidence: confidence,
      autoBlocked: false,
      timestamp: new Date().toISOString()
    };
  }
  // Low-risk calls - ALLOW
  else {
    response.riskLevel = 'LOW';
    response.action = 'allow';
    response.autoReject = false;
  }

  return response;
}

/**
 * Validate phone number format
 * @param {string} phoneNumber - Phone number to validate
 * @returns {boolean} True if valid format
 */
function isValidPhoneNumber(phoneNumber) {
  if (!phoneNumber || typeof phoneNumber !== 'string') {
    return false;
  }
  
  // Basic phone number validation (starts with + and contains digits)
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  return phoneRegex.test(phoneNumber);
}

/**
 * Log with timestamp and emoji
 * @param {string} level - Log level (info, warn, error)
 * @param {string} message - Message to log
 * @param {Object} data - Additional data to log
 */
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const emoji = {
    info: '📝',
    warn: '⚠️',
    error: '❌',
    success: '✅'
  };
  
  const logMessage = `${emoji[level] || '📝'} [${timestamp}] ${message}`;
  
  if (data) {
    console.log(logMessage, data);
  } else {
    console.log(logMessage);
  }
}

module.exports = {
  generateSessionId,
  processScamResult,
  isValidPhoneNumber,
  log
};
