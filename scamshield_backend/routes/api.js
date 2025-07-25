/**
 * API Routes for ScamShield Backend
 */

const express = require('express');
const { isValidPhoneNumber, log, processScamResult } = require('../utils/helpers');
const FlowTestService = require('../services/flowTestService');

function createApiRoutes(sessionService, hiyaService, databaseService, spamDetectionService) {
  const router = express.Router();
  const flowTestService = new FlowTestService(sessionService, hiyaService);

  // Helper function to generate mock scam results for testing
  function generateMockScamResult(phoneNumber) {
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

  // Health check endpoint
  router.get('/', (req, res) => {
    const hiyaStatus = hiyaService.getStatus();
    const sessionStats = sessionService.getStatistics();
    
    res.json({ 
      message: 'ScamShield Voice Scam Protection API is running', 
      version: '2.0.0',
      features: ['real-time-voice-analysis', 'websocket-streaming', 'scam-warnings'],
      status: {
        hiya: hiyaStatus,
        sessions: sessionStats,
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      }
    });
  });

  // Legacy endpoint for basic phone number checking with database cache
  router.post('/check-call', async (req, res) => {
    const { phoneNumber } = req.body;
    
    if (!phoneNumber) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    if (!isValidPhoneNumber(phoneNumber)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    log('info', `🔍 Check-call request for ${phoneNumber}`);
    
    try {
      // STEP 1: Check local database cache first
      const cachedResult = await databaseService.checkScamNumber(phoneNumber);
      
      if (cachedResult) {
        log('success', `📋 Found ${phoneNumber} in local database cache`);
        
        // Create session for tracking
        const session = sessionService.createSession({
          phoneNumber,
          userPhone: '+27000000000',
          direction: 'Incoming',
          isContact: false
        });
        
        // Use cached data
        const processedResult = {
          action: cachedResult.autoReject ? 'block' : 'allow',
          autoReject: cachedResult.autoReject,
          riskLevel: cachedResult.riskLevel,
          confidence: cachedResult.confidence,
          warning: cachedResult.autoReject ? {
            type: 'scamWarning',
            level: 'SCAM',
            title: 'Known scam number blocked',
            message: 'This number is in our scam database and has been automatically blocked.',
            autoBlocked: true,
            source: 'database_cache'
          } : null
        };
        
        sessionService.addResult(session.id, cachedResult.scamData);
        if (processedResult.warning) {
          sessionService.addWarning(session.id, processedResult.warning);
        }
        sessionService.closeSession(session.id);
        
        return res.json({
          action: processedResult.action,
          autoReject: processedResult.autoReject,
          riskLevel: processedResult.riskLevel,
          confidence: processedResult.confidence,
          warning: processedResult.warning,
          sessionId: session.id,
          shouldBlock: processedResult.action === 'block',
          score: cachedResult.riskLevel === 'HIGH' ? 0.9 : cachedResult.riskLevel === 'MEDIUM' ? 0.6 : 0.1,
          category: cachedResult.category,
          source: 'database_cache',
          message: processedResult.autoReject ? 
                   'Call automatically blocked - known scam number' : 
                   'Number found in database cache'
        });
      }
      
      // STEP 2: Not in cache, check with multi-API spam detection service
      log('info', `🌐 ${phoneNumber} not in cache, checking with multi-API service...`);
      
      const session = sessionService.createSession({
        phoneNumber,
        userPhone: '+27000000000',
        direction: 'Incoming',
        isContact: false
      });

      // Use multi-API spam detection service
      const apiResult = await spamDetectionService.checkNumber(phoneNumber);
      
      // Convert to legacy format for session storage
      const legacyResult = {
        type: 'result',
        callScamRisk: apiResult.riskLevel === 'HIGH' ? 'HIGH_SCAM_RISK' : 
                      apiResult.riskLevel === 'MEDIUM' ? 'MEDIUM_SCAM_RISK' : 'NOT_SCAM',
        callOriginatorRisk: apiResult.riskLevel,
        scamDialog: {
          scamDialogRisk: apiResult.category === 'scam' ? 'SCAM' : 'NEUTRAL',
          confidence: apiResult.confidence
        },
        multiApiData: apiResult // Store full multi-API result
      };
      
      sessionService.addResult(session.id, legacyResult);
      
      // STEP 3: Store result in database for future use
      if (apiResult.riskLevel !== 'LOW') {
        await databaseService.addScamNumber(phoneNumber, legacyResult, 'multi_api');
        log('success', `💾 Stored ${phoneNumber} in database cache (sources: ${apiResult.sources?.join(', ')})`);
      }
      
      // Use the standardized API result directly
      const processedResult = {
        action: apiResult.action,
        autoReject: apiResult.autoReject,
        riskLevel: apiResult.riskLevel,
        confidence: apiResult.confidence,
        warning: apiResult.autoReject ? {
          type: 'scamWarning',
          level: 'SCAM',
          title: 'Multi-API scam detection',
          message: `Detected as ${apiResult.category} by ${apiResult.sources?.join(', ') || 'spam detection APIs'}`,
          autoBlocked: true,
          sources: apiResult.sources
        } : null
      };
      
      if (processedResult.warning) {
        sessionService.addWarning(session.id, processedResult.warning);
      }
      
      sessionService.closeSession(session.id);
      
      // Return enhanced response with multi-API metadata
      res.json({
        action: processedResult.action,
        autoReject: processedResult.autoReject,
        riskLevel: processedResult.riskLevel,
        confidence: processedResult.confidence,
        warning: processedResult.warning,
        sessionId: session.id,
        shouldBlock: processedResult.action === 'block',
        score: apiResult.score || 0.5,
        category: apiResult.category,
        sources: apiResult.sources || ['multi_api'],
        primarySource: apiResult.primarySource,
        metadata: apiResult.metadata,
        message: processedResult.autoReject ? 
                 `Call automatically blocked by ${apiResult.sources?.join(', ') || 'spam detection APIs'}` : 
                 'Multi-API analysis complete'
      });
      
    } catch (error) {
      log('error', `Error processing check-call for ${phoneNumber}:`, error);
      res.status(500).json({ 
        error: 'Failed to check call',
        action: 'allow', // Safe default
        autoReject: false,
        riskLevel: 'LOW',
        confidence: 'UNKNOWN'
      });
    }
  });

  // Start voice analysis session
  router.post('/start-analysis', (req, res) => {
    const { phoneNumber, userPhone, direction, isContact } = req.body;
    
    if (!phoneNumber) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    if (!isValidPhoneNumber(phoneNumber)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    if (!hiyaService.isConfigured()) {
      return res.status(503).json({ 
        error: 'Hiya API not configured',
        message: 'Voice scam protection service is not available'
      });
    }

    try {
      const session = sessionService.createSession({
        phoneNumber,
        userPhone,
        direction,
        isContact
      });
      
      res.json({
        sessionId: session.id,
        message: 'Analysis session started',
        websocket_url: `ws://localhost:${process.env.PORT || 3000}/voice-analysis`,
        instructions: 'Connect to WebSocket and send audio data for real-time analysis',
        session: {
          id: session.id,
          phoneNumber: session.phoneNumber,
          direction: session.direction,
          startTime: session.startTime
        }
      });
    } catch (error) {
      log('error', 'Failed to create analysis session:', error);
      res.status(500).json({ error: 'Failed to create analysis session' });
    }
  });

  // Get session status and data
  router.get('/session/:sessionId', (req, res) => {
    const { sessionId } = req.params;
    const session = sessionService.getSession(sessionId);
    
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    
    res.json({
      sessionId: session.id,
      phoneNumber: session.phoneNumber,
      userPhone: session.userPhone,
      direction: session.direction,
      isContact: session.isContact,
      status: session.status,
      startTime: session.startTime,
      endTime: session.endTime,
      duration: session.duration,
      transcript: session.transcript,
      results: session.results,
      warnings: session.warnings,
      stats: {
        transcriptLines: session.transcript.length,
        analysisResults: session.results.length,
        warningsGenerated: session.warnings.length
      }
    });
  });

  // Report session (for user feedback)
  router.post('/report-session', async (req, res) => {
    const { sessionId, isScam, transcript, reason } = req.body;
    
    if (!sessionId) {
      return res.status(400).json({ error: 'Session ID is required' });
    }
    
    const session = sessionService.getSession(sessionId);
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }
    
    try {
      // Send report to Hiya API
      const reportSuccess = await hiyaService.reportSession(
        sessionId, 
        isScam, 
        transcript || session.transcript.map(t => t.transcript).join(' ')
      );
      
      // Add report to session data
      if (!session.reports) {
        session.reports = [];
      }
      
      session.reports.push({
        isScam,
        reason,
        timestamp: new Date().toISOString(),
        reportedToHiya: reportSuccess
      });
      
      log('info', `User reported session ${sessionId} as ${isScam ? 'SCAM' : 'NOT SCAM'}`);
      
      res.json({ 
        message: 'Report submitted successfully',
        sessionId,
        reported: isScam ? 'scam' : 'not_scam',
        sentToHiya: reportSuccess
      });
    } catch (error) {
      log('error', 'Failed to process session report:', error);
      res.status(500).json({ error: 'Failed to process report' });
    }
  });

  // Get system statistics
  router.get('/stats', (req, res) => {
    const sessionStats = sessionService.getStatistics();
    const hiyaStatus = hiyaService.getStatus();
    
    res.json({
      sessions: sessionStats,
      hiya: hiyaStatus,
      system: {
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        version: '2.0.0',
        timestamp: new Date().toISOString()
      }
    });
  });

  // Clean up old sessions (admin endpoint)
  router.post('/admin/cleanup', (req, res) => {
    const cleanedCount = sessionService.cleanupOldSessions();
    
    res.json({
      message: 'Cleanup completed',
      sessionsRemoved: cleanedCount,
      timestamp: new Date().toISOString()
    });
  });

  // Get all sessions (admin/debug endpoint)
  router.get('/admin/sessions', (req, res) => {
    const sessions = sessionService.getAllSessions();
    
    res.json({
      totalSessions: sessions.length,
      sessions: sessions.map(session => ({
        id: session.id,
        phoneNumber: session.phoneNumber,
        status: session.status,
        startTime: session.startTime,
        warningsCount: session.warnings.length,
        resultsCount: session.results.length
      }))
    });
  });

  // Test complete user flow
  router.post('/test/user-flow', async (req, res) => {
    const { phoneNumber, userPhone } = req.body;
    
    if (!phoneNumber) {
      return res.status(400).json({ error: 'Phone number is required for testing' });
    }

    try {
      const testResults = await flowTestService.testCompleteUserFlow(phoneNumber, userPhone);
      res.json(testResults);
    } catch (error) {
      log('error', 'Flow test failed:', error);
      res.status(500).json({ error: 'Flow test failed', details: error.message });
    }
  });

  // Test data flow
  router.get('/test/data-flow', async (req, res) => {
    try {
      const testResults = await flowTestService.testDataFlow();
      res.json(testResults);
    } catch (error) {
      log('error', 'Data flow test failed:', error);
      res.status(500).json({ error: 'Data flow test failed', details: error.message });
    }
  });

  // Run comprehensive tests
  router.get('/test/comprehensive', async (req, res) => {
    try {
      const testResults = await flowTestService.runComprehensiveTests();
      res.json(testResults);
    } catch (error) {
      log('error', 'Comprehensive tests failed:', error);
      res.status(500).json({ error: 'Comprehensive tests failed', details: error.message });
    }
  });

  // Database management endpoints
  
  // Get database statistics
  router.get('/db/stats', async (req, res) => {
    try {
      const stats = await databaseService.getStatistics();
      res.json(stats);
    } catch (error) {
      log('error', 'Failed to get database statistics:', error);
      res.status(500).json({ error: 'Failed to get database statistics' });
    }
  });

  // Add user report
  router.post('/db/report', async (req, res) => {
    const { phoneNumber, reportType, userPhone, additionalData } = req.body;
    
    if (!phoneNumber || !reportType || !userPhone) {
      return res.status(400).json({ 
        error: 'Phone number, report type, and user phone are required' 
      });
    }

    if (!['scam', 'not_scam', 'spam'].includes(reportType)) {
      return res.status(400).json({ 
        error: 'Report type must be: scam, not_scam, or spam' 
      });
    }

    try {
      const report = await databaseService.addUserReport(
        phoneNumber, 
        reportType, 
        userPhone, 
        additionalData || {}
      );
      
      res.json({
        message: 'Report added successfully',
        report: report
      });
    } catch (error) {
      log('error', 'Failed to add user report:', error);
      res.status(500).json({ error: 'Failed to add user report' });
    }
  });

  // Check if number is in database
  router.get('/db/check/:phoneNumber', async (req, res) => {
    const { phoneNumber } = req.params;
    
    if (!isValidPhoneNumber(phoneNumber)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    try {
      const result = await databaseService.checkScamNumber(phoneNumber);
      
      if (result) {
        res.json({
          found: true,
          data: result
        });
      } else {
        res.json({
          found: false,
          message: 'Number not found in database'
        });
      }
    } catch (error) {
      log('error', 'Failed to check database:', error);
      res.status(500).json({ error: 'Failed to check database' });
    }
  });

  // Cleanup old entries (admin endpoint)
  router.post('/db/cleanup', async (req, res) => {
    const { daysOld } = req.body;
    const days = daysOld || 90;

    try {
      const removedCount = await databaseService.cleanupOldEntries(days);
      res.json({
        message: `Cleanup completed`,
        removedEntries: removedCount,
        daysOld: days
      });
    } catch (error) {
      log('error', 'Failed to cleanup database:', error);
      res.status(500).json({ error: 'Failed to cleanup database' });
    }
  });

  // Multi-API spam detection management endpoints
  
  // Get provider statistics and configuration
  router.get('/api/providers', (req, res) => {
    try {
      const stats = spamDetectionService.getProviderStats();
      res.json({
        providers: stats,
        aggregationStrategy: spamDetectionService.config?.aggregationStrategy || 'highest_risk',
        totalProviders: Object.keys(stats).length,
        enabledProviders: Object.values(stats).filter(p => p.config.enabled).length
      });
    } catch (error) {
      log('error', 'Failed to get provider stats:', error);
      res.status(500).json({ error: 'Failed to get provider statistics' });
    }
  });

  // Enable/disable a specific provider
  router.post('/api/providers/:providerName/toggle', (req, res) => {
    const { providerName } = req.params;
    const { enabled } = req.body;
    
    if (typeof enabled !== 'boolean') {
      return res.status(400).json({ error: 'enabled must be a boolean value' });
    }

    try {
      spamDetectionService.setProviderEnabled(providerName, enabled);
      res.json({
        message: `Provider ${providerName} ${enabled ? 'enabled' : 'disabled'}`,
        provider: providerName,
        enabled: enabled
      });
    } catch (error) {
      log('error', `Failed to toggle provider ${providerName}:`, error);
      res.status(500).json({ error: `Failed to toggle provider ${providerName}` });
    }
  });

  // Update provider configuration
  router.post('/api/providers/:providerName/config', (req, res) => {
    const { providerName } = req.params;
    const config = req.body;
    
    try {
      spamDetectionService.updateProviderConfig(providerName, config);
      res.json({
        message: `Provider ${providerName} configuration updated`,
        provider: providerName,
        config: config
      });
    } catch (error) {
      log('error', `Failed to update provider ${providerName} config:`, error);
      res.status(500).json({ error: `Failed to update provider ${providerName} configuration` });
    }
  });

  // Test multi-API spam detection
  router.post('/api/test-detection', async (req, res) => {
    const { phoneNumber } = req.body;
    
    if (!phoneNumber) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    if (!isValidPhoneNumber(phoneNumber)) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    try {
      const result = await spamDetectionService.checkNumber(phoneNumber);
      res.json({
        phoneNumber: phoneNumber,
        result: result,
        message: 'Multi-API detection test completed'
      });
    } catch (error) {
      log('error', `Failed to test detection for ${phoneNumber}:`, error);
      res.status(500).json({ error: 'Failed to test spam detection' });
    }
  });

  return router;
}

module.exports = createApiRoutes;
