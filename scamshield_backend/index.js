/**
 * ScamShield Voice Scam Protection API Server
 * Modular backend for real-time voice scam detection using Hiya API
 */

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
require('dotenv').config();

// Import services and handlers
const SessionService = require('./services/sessionService');
const HiyaService = require('./services/hiyaService');
const DatabaseService = require('./services/databaseService');
const SpamDetectionService = require('./services/spamDetectionService');
const AuthService = require('./services/authService');
const PostgresService = require('./services/postgresService');
const VoiceAnalysisHandler = require('./websocket/voiceAnalysisHandler');
const createApiRoutes = require('./routes/api');
const createAuthRoutes = require('./routes/auth');
const createCallHistoryRoutes = require('./routes/callHistory');
const createSubscriptionRoutes = require('./routes/subscription');
const { createAuthMiddleware, createOptionalAuthMiddleware } = require('./middleware/authMiddleware');
const { log } = require('./utils/helpers');

// Import providers
const HiyaProvider = require('./providers/hiyaProvider');
const TruecallerProvider = require('./providers/truecallerProvider');
const TelesignProvider = require('./providers/telesignProvider');

// Initialize services
const sessionService = new SessionService();
const hiyaService = new HiyaService();
const databaseService = new DatabaseService();
const spamDetectionService = new SpamDetectionService();
const authService = new AuthService();
const postgresService = new PostgresService();
const voiceAnalysisHandler = new VoiceAnalysisHandler(sessionService, hiyaService);

// Create Express app and HTTP server
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Middleware
app.use(express.json());
app.use(express.raw({ type: 'audio/wav', limit: '50mb' }));

// CORS middleware for development
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Initialize database service and spam detection providers
(async () => {
  try {
    // Initialize database service
    await databaseService.initialize();
    log('success', 'Database service initialized');
    
    // Initialize and register spam detection providers
    const hiyaProvider = new HiyaProvider(hiyaService);
    spamDetectionService.registerProvider('hiya', hiyaProvider, {
      enabled: true,
      weight: 1.0,
      priority: 1,
      timeout: 5000
    });
    
    // Register Truecaller provider (disabled by default until API key is provided)
    const truecallerProvider = new TruecallerProvider(process.env.TRUECALLER_API_KEY);
    spamDetectionService.registerProvider('truecaller', truecallerProvider, {
      enabled: !!process.env.TRUECALLER_API_KEY,
      weight: 0.8,
      priority: 2,
      timeout: 3000
    });
    
    // Register Telesign provider (disabled by default until credentials are provided)
    const telesignProvider = new TelesignProvider(
      process.env.TELESIGN_CUSTOMER_ID,
      process.env.TELESIGN_API_KEY
    );
    spamDetectionService.registerProvider('telesign', telesignProvider, {
      enabled: !!(process.env.TELESIGN_CUSTOMER_ID && process.env.TELESIGN_API_KEY),
      weight: 0.9,
      priority: 3,
      timeout: 4000
    });
    
    log('success', 'Multi-API spam detection service initialized');
    
    // Initialize PostgreSQL service
    await postgresService.initialize();
    log('success', 'PostgreSQL service initialized');
    
  } catch (error) {
    log('error', 'Failed to initialize services:', error);
  }
})();

// Create middleware
const authMiddleware = createAuthMiddleware(authService);
const optionalAuthMiddleware = createOptionalAuthMiddleware(authService);

// Setup routes
const apiRoutes = createApiRoutes(
  sessionService,
  hiyaService,
  databaseService,
  spamDetectionService
);
const authRoutes = createAuthRoutes(authService, authMiddleware);
const callHistoryRoutes = createCallHistoryRoutes();
const subscriptionRoutes = createSubscriptionRoutes(postgresService);

// Mount routes
app.use('/auth', authRoutes);
app.use('/api/call-history', callHistoryRoutes);
app.use('/api/subscription', authMiddleware, subscriptionRoutes);
app.use('/', optionalAuthMiddleware, apiRoutes);

// WebSocket connection handling
voiceAnalysisHandler.setupWebSocket(wss);

// Periodic cleanup of old sessions (every hour)
setInterval(() => {
  sessionService.cleanupOldSessions();
}, 60 * 60 * 1000);

// Error handling middleware
app.use((err, req, res, next) => {
  log('error', 'Unhandled error:', err);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  log('info', 'SIGTERM received, shutting down gracefully');
  server.close(() => {
    log('info', 'Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  log('info', 'SIGINT received, shutting down gracefully');
  server.close(() => {
    log('info', 'Server closed');
    process.exit(0);
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  log('success', `ScamShield Voice Scam Protection API v2.0.0 running on port ${PORT}`);
  log('info', `Health check: http://localhost:${PORT}/`);
  log('info', `WebSocket endpoint: ws://localhost:${PORT}/voice-analysis`);
  log('info', `Start analysis: POST http://localhost:${PORT}/start-analysis`);
  log('info', `Statistics: GET http://localhost:${PORT}/stats`);
  
  // Log configuration status
  const hiyaStatus = hiyaService.getStatus();
  if (hiyaStatus.configured) {
    log('success', 'Hiya API configured and ready');
  } else {
    log('warn', 'Hiya API not configured - voice analysis will not work');
  }
  
  log('info', 'Server ready to accept connections');
});
