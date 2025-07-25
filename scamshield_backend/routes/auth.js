/**
 * Authentication Routes
 * Handle phone number registration, OTP verification, and user management
 */

const express = require('express');
const { log } = require('../utils/helpers');

/**
 * Create authentication routes
 * @param {Object} authService - AuthService instance
 * @param {Function} authMiddleware - Authentication middleware
 * @returns {Object} Express router
 */
function createAuthRoutes(authService, authMiddleware) {
  const router = express.Router();

  /**
   * Send OTP to phone number
   * POST /auth/send-otp
   */
  router.post('/send-otp', async (req, res) => {
    try {
      const { phoneNumber } = req.body;

      // Validate input
      if (!phoneNumber) {
        return res.status(400).json({
          success: false,
          error: 'Phone number is required',
          code: 'MISSING_PHONE'
        });
      }

      // Send OTP
      const result = await authService.sendOTP(phoneNumber);

      if (result.success) {
        res.json({
          success: true,
          message: result.message,
          expiresIn: result.expiresIn
        });
      } else {
        res.status(400).json({
          success: false,
          error: result.message,
          code: 'OTP_SEND_FAILED'
        });
      }

    } catch (error) {
      log('error', 'Send OTP error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to send OTP',
        code: 'SERVER_ERROR'
      });
    }
  });

  /**
   * Verify OTP and login/register user
   * POST /auth/verify-otp
   */
  router.post('/verify-otp', async (req, res) => {
    try {
      const { phoneNumber, otp } = req.body;

      // Validate input
      if (!phoneNumber || !otp) {
        return res.status(400).json({
          success: false,
          error: 'Phone number and OTP are required',
          code: 'MISSING_CREDENTIALS'
        });
      }

      // Verify OTP
      const result = await authService.verifyOTP(phoneNumber, otp);

      if (result.success) {
        res.json({
          success: true,
          message: result.message,
          token: result.token,
          user: result.user
        });
      } else {
        res.status(400).json({
          success: false,
          error: result.message,
          code: 'OTP_VERIFICATION_FAILED'
        });
      }

    } catch (error) {
      log('error', 'Verify OTP error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to verify OTP',
        code: 'SERVER_ERROR'
      });
    }
  });

  /**
   * Get current user profile (protected route)
   * GET /auth/profile
   */
  router.get('/profile', authMiddleware, (req, res) => {
    try {
      const user = authService.getUser(req.user.phoneNumber);
      
      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      res.json({
        success: true,
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          createdAt: user.createdAt,
          lastLogin: user.lastLogin,
          isActive: user.isActive
        }
      });

    } catch (error) {
      log('error', 'Get profile error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get user profile',
        code: 'SERVER_ERROR'
      });
    }
  });

  /**
   * Refresh JWT token (protected route)
   * POST /auth/refresh-token
   */
  router.post('/refresh-token', authMiddleware, (req, res) => {
    try {
      const user = authService.getUser(req.user.phoneNumber);
      
      if (!user) {
        return res.status(404).json({
          success: false,
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Generate new token
      const newToken = authService.generateJWT(user);

      res.json({
        success: true,
        message: 'Token refreshed successfully',
        token: newToken
      });

    } catch (error) {
      log('error', 'Refresh token error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to refresh token',
        code: 'SERVER_ERROR'
      });
    }
  });

  /**
   * Logout user (protected route)
   * POST /auth/logout
   */
  router.post('/logout', authMiddleware, (req, res) => {
    try {
      // In a real app, you might want to blacklist the token
      // For now, we just return success (client should delete token)
      
      log('info', `User logged out: ${req.user.phoneNumber}`);

      res.json({
        success: true,
        message: 'Logged out successfully'
      });

    } catch (error) {
      log('error', 'Logout error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to logout',
        code: 'SERVER_ERROR'
      });
    }
  });

  /**
   * Check authentication status
   * GET /auth/status
   */
  router.get('/status', authMiddleware, (req, res) => {
    res.json({
      success: true,
      authenticated: true,
      user: {
        userId: req.user.userId,
        phoneNumber: req.user.phoneNumber
      }
    });
  });

  /**
   * Get authentication statistics (admin endpoint)
   * GET /auth/stats
   */
  router.get('/stats', (req, res) => {
    try {
      const stats = authService.getStats();
      res.json({
        success: true,
        stats: stats
      });
    } catch (error) {
      log('error', 'Get auth stats error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get authentication statistics',
        code: 'SERVER_ERROR'
      });
    }
  });

  return router;
}

module.exports = createAuthRoutes;
