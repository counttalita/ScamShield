/**
 * Authentication Middleware
 * JWT token verification for protected routes
 */

const { log } = require('../utils/helpers');

/**
 * Middleware to verify JWT token
 * @param {Object} authService - AuthService instance
 * @returns {Function} Express middleware function
 */
function createAuthMiddleware(authService) {
  return (req, res, next) => {
    try {
      // Get token from Authorization header
      const authHeader = req.headers.authorization;
      
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          error: 'Access denied. No token provided.',
          code: 'NO_TOKEN'
        });
      }

      // Extract token
      const token = authHeader.substring(7); // Remove 'Bearer ' prefix
      
      // Verify token
      const decoded = authService.verifyJWT(token);
      
      if (!decoded) {
        return res.status(401).json({
          error: 'Invalid or expired token.',
          code: 'INVALID_TOKEN'
        });
      }

      // Add user info to request
      req.user = {
        userId: decoded.userId,
        phoneNumber: decoded.phoneNumber,
        iat: decoded.iat
      };

      next();
    } catch (error) {
      log('error', 'Auth middleware error:', error);
      res.status(500).json({
        error: 'Authentication error.',
        code: 'AUTH_ERROR'
      });
    }
  };
}

/**
 * Optional auth middleware - doesn't fail if no token
 * @param {Object} authService - AuthService instance
 * @returns {Function} Express middleware function
 */
function createOptionalAuthMiddleware(authService) {
  return (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      
      if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const decoded = authService.verifyJWT(token);
        
        if (decoded) {
          req.user = {
            userId: decoded.userId,
            phoneNumber: decoded.phoneNumber,
            iat: decoded.iat
          };
        }
      }

      next();
    } catch (error) {
      log('warn', 'Optional auth middleware error:', error);
      next(); // Continue without auth
    }
  };
}

module.exports = {
  createAuthMiddleware,
  createOptionalAuthMiddleware
};
