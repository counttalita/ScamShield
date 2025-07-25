/**
 * Hiya API Provider
 * Implements the spam detection interface for Hiya Voice Scam Protection API
 */

const { log } = require('../utils/helpers');

class HiyaProvider {
  constructor(hiyaService) {
    this.hiyaService = hiyaService;
    this.name = 'hiya';
  }

  /**
   * Check if a phone number is spam/scam using Hiya API
   * @param {string} phoneNumber - Phone number to check
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} Spam detection result
   */
  async checkSpamNumber(phoneNumber, options = {}) {
    try {
      log('info', `🔍 Checking ${phoneNumber} with Hiya API`);

      // For now, generate mock result (in production, this would call real Hiya API)
      const mockResult = this.generateMockHiyaResult(phoneNumber);
      
      // Process Hiya result into standardized format
      const standardizedResult = this.standardizeResult(mockResult, phoneNumber);
      
      log('info', `✅ Hiya API result: ${standardizedResult.riskLevel} risk`);
      
      return standardizedResult;

    } catch (error) {
      log('error', `❌ Hiya API error for ${phoneNumber}:`, error);
      throw new Error(`Hiya API failed: ${error.message}`);
    }
  }

  /**
   * Generate mock Hiya API result for testing
   * @param {string} phoneNumber - Phone number
   * @returns {Object} Mock Hiya API response
   */
  generateMockHiyaResult(phoneNumber) {
    const isScamNumber = phoneNumber.includes('666') || phoneNumber.includes('999');
    const isSuspiciousNumber = phoneNumber.includes('555');

    if (isScamNumber) {
      return {
        type: 'result',
        callScamRisk: 'HIGH_SCAM_RISK',
        callOriginatorRisk: 'HIGH',
        scamDialog: {
          scamDialogRisk: 'SCAM',
          confidence: 'HIGH'
        },
        syntheticVoice: {
          syntheticVoiceDetected: 'YES',
          score: 0.85
        }
      };
    } else if (isSuspiciousNumber) {
      return {
        type: 'result',
        callScamRisk: 'MEDIUM_SCAM_RISK',
        callOriginatorRisk: 'MEDIUM',
        scamDialog: {
          scamDialogRisk: 'NEUTRAL',
          confidence: 'MEDIUM'
        },
        syntheticVoice: {
          syntheticVoiceDetected: 'NO',
          score: 0.15
        }
      };
    } else {
      return {
        type: 'result',
        callScamRisk: 'NOT_SCAM',
        callOriginatorRisk: 'LOW',
        scamDialog: {
          scamDialogRisk: 'NEUTRAL',
          confidence: 'LOW'
        },
        syntheticVoice: {
          syntheticVoiceDetected: 'NO',
          score: 0.05
        }
      };
    }
  }

  /**
   * Standardize Hiya API result to common format
   * @param {Object} hiyaResult - Raw Hiya API result
   * @param {string} phoneNumber - Phone number
   * @returns {Object} Standardized result
   */
  standardizeResult(hiyaResult, phoneNumber) {
    const riskLevel = this.mapRiskLevel(hiyaResult.callScamRisk);
    const confidence = this.mapConfidence(hiyaResult.scamDialog?.confidence);
    const category = this.mapCategory(hiyaResult.callScamRisk);
    const action = riskLevel === 'HIGH' ? 'block' : 'allow';
    const autoReject = riskLevel === 'HIGH';

    return {
      phoneNumber,
      riskLevel,
      confidence,
      action,
      autoReject,
      category,
      score: this.calculateScore(hiyaResult),
      provider: 'hiya',
      rawData: hiyaResult,
      features: {
        syntheticVoice: hiyaResult.syntheticVoice?.syntheticVoiceDetected === 'YES',
        syntheticVoiceScore: hiyaResult.syntheticVoice?.score || 0,
        originatorRisk: hiyaResult.callOriginatorRisk,
        dialogRisk: hiyaResult.scamDialog?.scamDialogRisk
      }
    };
  }

  /**
   * Map Hiya risk level to standard risk level
   * @param {string} hiyaRisk - Hiya risk level
   * @returns {string} Standard risk level
   */
  mapRiskLevel(hiyaRisk) {
    switch (hiyaRisk) {
      case 'HIGH_SCAM_RISK':
        return 'HIGH';
      case 'MEDIUM_SCAM_RISK':
        return 'MEDIUM';
      case 'NOT_SCAM':
      default:
        return 'LOW';
    }
  }

  /**
   * Map Hiya confidence to standard confidence
   * @param {string} hiyaConfidence - Hiya confidence level
   * @returns {string} Standard confidence level
   */
  mapConfidence(hiyaConfidence) {
    switch (hiyaConfidence) {
      case 'HIGH':
        return 'HIGH';
      case 'MEDIUM':
        return 'MEDIUM';
      case 'LOW':
        return 'LOW';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * Map Hiya risk to category
   * @param {string} hiyaRisk - Hiya risk level
   * @returns {string} Category
   */
  mapCategory(hiyaRisk) {
    switch (hiyaRisk) {
      case 'HIGH_SCAM_RISK':
        return 'scam';
      case 'MEDIUM_SCAM_RISK':
        return 'suspicious';
      case 'NOT_SCAM':
      default:
        return 'legitimate';
    }
  }

  /**
   * Calculate numeric score from Hiya result
   * @param {Object} hiyaResult - Hiya API result
   * @returns {number} Score between 0 and 1
   */
  calculateScore(hiyaResult) {
    switch (hiyaResult.callScamRisk) {
      case 'HIGH_SCAM_RISK':
        return 0.9;
      case 'MEDIUM_SCAM_RISK':
        return 0.6;
      case 'NOT_SCAM':
      default:
        return 0.1;
    }
  }

  /**
   * Get provider information
   * @returns {Object} Provider info
   */
  getProviderInfo() {
    return {
      name: 'hiya',
      displayName: 'Hiya Voice Scam Protection',
      version: '1.0.0',
      features: [
        'voice_scam_detection',
        'synthetic_voice_detection',
        'real_time_analysis',
        'originator_risk_assessment'
      ],
      configured: this.hiyaService.isConfigured(),
      status: this.hiyaService.getStatus()
    };
  }
}

module.exports = HiyaProvider;
