/**
 * Call History API Routes
 * Serves call history data from PostgreSQL database
 */

const express = require('express');
const PostgresService = require('../services/postgresService');
const { createAuthMiddleware } = require('../middleware/authMiddleware');
const AuthService = require('../services/authService');
const { log } = require('../utils/helpers');

// Create router factory function that accepts dependencies
function createCallHistoryRoutes() {
  const router = express.Router();
  const authService = new AuthService();
  const authMiddleware = createAuthMiddleware(authService);
  
  // Initialize PostgreSQL service
  const db = new PostgresService();

/**
 * GET /api/call-history/recent
 * Get recent call history (last 5 entries) for authenticated user
 */
router.get('/recent', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.phoneNumber; // From JWT token
    
    log('info', `Fetching recent call history for user: ${userId}`);
    
    // Ensure database is initialized
    if (!db.initialized) {
      await db.initialize();
    }
    
    const recentCalls = await db.getRecentCallHistory(userId);
    
    // Transform data for Flutter app compatibility
    const transformedCalls = recentCalls.map(call => ({
      phoneNumber: call.phone_number,
      action: call.action,
      reason: call.reason,
      timestamp: call.timestamp,
      riskLevel: call.risk_level,
      sessionId: call.session_id,
      apiProvider: call.api_provider,
      confidence: parseFloat(call.confidence || 0),
      timeAgo: getTimeAgo(new Date(call.timestamp))
    }));
    
    res.json({
      success: true,
      data: transformedCalls,
      count: transformedCalls.length
    });
    
  } catch (error) {
    log('error', 'Failed to fetch recent call history:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch call history',
      message: error.message
    });
  }
});

/**
 * GET /api/call-history/weekly
 * Get paginated call history for the past week
 */
router.get('/weekly', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.phoneNumber; // From JWT token
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    
    log('info', `Fetching weekly call history for user: ${userId}, page: ${page}, limit: ${limit}`);
    
    // Ensure database is initialized
    if (!db.initialized) {
      await db.initialize();
    }
    
    const calls = await db.getCallHistory(userId, limit, offset, 7);
    const stats = await db.getCallHistoryStats(userId, 7);
    
    // Transform data for Flutter app compatibility
    const transformedCalls = calls.map(call => ({
      phoneNumber: call.phone_number,
      action: call.action,
      reason: call.reason,
      timestamp: call.timestamp,
      riskLevel: call.risk_level,
      sessionId: call.session_id,
      apiProvider: call.api_provider,
      confidence: parseFloat(call.confidence || 0),
      timeAgo: getTimeAgo(new Date(call.timestamp))
    }));
    
    res.json({
      success: true,
      data: transformedCalls,
      pagination: {
        page,
        limit,
        offset,
        hasMore: calls.length === limit
      },
      statistics: {
        totalCalls: parseInt(stats.total_calls),
        blockedCalls: parseInt(stats.blocked_calls),
        silencedCalls: parseInt(stats.silenced_calls)
      }
    });
    
  } catch (error) {
    log('error', 'Failed to fetch weekly call history:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch call history',
      message: error.message
    });
  }
});

/**
 * GET /api/call-history/stats
 * Get call history statistics for authenticated user
 */
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.phoneNumber; // From JWT token
    const daysBack = parseInt(req.query.days) || 7;
    
    log('info', `Fetching call history stats for user: ${userId}, days: ${daysBack}`);
    
    // Ensure database is initialized
    if (!db.initialized) {
      await db.initialize();
    }
    
    const stats = await db.getCallHistoryStats(userId, daysBack);
    
    res.json({
      success: true,
      data: {
        totalCalls: parseInt(stats.total_calls),
        blockedCalls: parseInt(stats.blocked_calls),
        silencedCalls: parseInt(stats.silenced_calls),
        daysBack
      }
    });
    
  } catch (error) {
    log('error', 'Failed to fetch call history stats:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch statistics',
      message: error.message
    });
  }
});

/**
 * POST /api/call-history/add
 * Add a new call history entry (for real-time call processing)
 */
router.post('/add', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.phoneNumber; // From JWT token
    const { phoneNumber, action, reason, riskLevel, sessionId, apiProvider, confidence } = req.body;
    
    // Validate required fields
    if (!phoneNumber || !action || !reason) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: phoneNumber, action, reason'
      });
    }
    
    log('info', `Adding call history entry for user: ${userId}, number: ${phoneNumber}, action: ${action}`);
    
    // Ensure database is initialized
    if (!db.initialized) {
      await db.initialize();
    }
    
    const entry = {
      userId,
      phoneNumber,
      action,
      reason,
      timestamp: new Date().toISOString(),
      riskLevel: riskLevel || 'medium',
      sessionId: sessionId || `session_${Date.now()}`,
      apiProvider: apiProvider || 'local',
      confidence: confidence || 0.5
    };
    
    const entryId = await db.addCallHistory(entry);
    
    res.json({
      success: true,
      data: {
        id: entryId,
        message: 'Call history entry added successfully'
      }
    });
    
  } catch (error) {
    log('error', 'Failed to add call history entry:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to add call history entry',
      message: error.message
    });
  }
});

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

  return router;
}

module.exports = createCallHistoryRoutes;
