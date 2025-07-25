/**
 * WebSocket Handler for Voice Analysis
 */

const { processScamResult, log } = require('../utils/helpers');

class VoiceAnalysisHandler {
  constructor(sessionService, hiyaService) {
    this.sessionService = sessionService;
    this.hiyaService = hiyaService;
  }

  /**
   * Setup WebSocket server with connection handling
   * @param {WebSocket.Server} wss - WebSocket server instance
   */
  setupWebSocket(wss) {
    log('info', 'Setting up WebSocket server for voice analysis');
    
    wss.on('connection', (ws, req) => {
      this.handleConnection(ws, req);
    });
    
    log('success', 'WebSocket server setup complete');
  }

  /**
   * Handle new WebSocket connection
   * @param {WebSocket} ws - Client WebSocket connection
   * @param {Object} req - HTTP request object
   */
  handleConnection(ws, req) {
    log('info', 'New WebSocket connection established');
    
    let sessionId = null;
    let hiyaWebSocket = null;
    
    ws.on('message', async (message) => {
      try {
        await this.handleMessage(ws, message, sessionId, hiyaWebSocket);
      } catch (error) {
        log('error', 'WebSocket message error:', error);
        ws.send(JSON.stringify({ error: error.message }));
      }
    });
    
    ws.on('close', () => {
      this.handleClose(sessionId, hiyaWebSocket);
    });
    
    ws.on('error', (error) => {
      log('error', 'WebSocket error:', error);
    });
  }

  /**
   * Handle incoming WebSocket message
   * @param {WebSocket} ws - Client WebSocket
   * @param {Buffer|String} message - Incoming message
   * @param {string} sessionId - Current session ID
   * @param {WebSocket} hiyaWebSocket - Hiya WebSocket connection
   */
  async handleMessage(ws, message, sessionId, hiyaWebSocket) {
    // First message should be session initialization
    if (!sessionId) {
      const initData = JSON.parse(message);
      sessionId = initData.sessionId;
      
      const session = this.sessionService.getSession(sessionId);
      if (!session) {
        ws.send(JSON.stringify({ error: 'Invalid session ID' }));
        return;
      }
      
      // Connect to Hiya WebSocket API
      hiyaWebSocket = await this.hiyaService.connectToAPI(session);
      
      if (hiyaWebSocket) {
        this.sessionService.updateSessionStatus(sessionId, 'connected');
        
        // Set up Hiya event forwarding
        this.setupHiyaEventForwarding(ws, sessionId, hiyaWebSocket);
        
        ws.send(JSON.stringify({ 
          type: 'sessionConnected', 
          sessionId,
          message: 'Connected to Hiya Voice Scam Protection' 
        }));
      } else {
        ws.send(JSON.stringify({ 
          error: 'Failed to connect to Hiya API',
          sessionId 
        }));
      }
    } else {
      // Forward audio data to Hiya WebSocket
      if (hiyaWebSocket && hiyaWebSocket.readyState === 1) {
        hiyaWebSocket.send(message);
      }
    }
  }

  /**
   * Set up event forwarding from Hiya WebSocket to client
   * @param {WebSocket} clientWs - Client WebSocket
   * @param {string} sessionId - Session ID
   * @param {WebSocket} hiyaWs - Hiya WebSocket
   */
  setupHiyaEventForwarding(clientWs, sessionId, hiyaWs) {
    hiyaWs.on('message', (hiyaMessage) => {
      try {
        const event = JSON.parse(hiyaMessage);
        
        if (event.type === 'result') {
          // Store result in session
          this.sessionService.addResult(sessionId, event);
          
          // Generate and send warning if needed
          const warning = processScamResult(event);
          if (warning) {
            this.sessionService.addWarning(sessionId, warning);
            clientWs.send(JSON.stringify(warning));
          }
        } else if (event.type === 'transcript') {
          // Store transcript in session
          this.sessionService.addTranscript(sessionId, event);
        } else if (event.type === 'error') {
          log('error', `Hiya API error for session ${sessionId}:`, event.message);
        }
        
        // Forward all events to client
        clientWs.send(hiyaMessage);
      } catch (error) {
        log('error', 'Error processing Hiya message:', error);
      }
    });
    
    hiyaWs.on('close', () => {
      log('info', `Hiya WebSocket closed for session ${sessionId}`);
      this.sessionService.updateSessionStatus(sessionId, 'disconnected');
    });
    
    hiyaWs.on('error', (error) => {
      log('error', `Hiya WebSocket error for session ${sessionId}:`, error);
      this.sessionService.updateSessionStatus(sessionId, 'error');
    });
  }

  /**
   * Handle WebSocket connection close
   * @param {string} sessionId - Session ID
   * @param {WebSocket} hiyaWebSocket - Hiya WebSocket connection
   */
  handleClose(sessionId, hiyaWebSocket) {
    log('info', `Client WebSocket closed for session ${sessionId}`);
    
    if (hiyaWebSocket) {
      hiyaWebSocket.close();
    }
    
    if (sessionId) {
      this.sessionService.closeSession(sessionId);
    }
  }

  /**
   * Broadcast message to all connected clients (if needed for admin features)
   * @param {Object} message - Message to broadcast
   */
  broadcast(message) {
    // This could be implemented if we need to send system-wide notifications
    log('info', 'Broadcasting message to all clients:', message);
  }
}

module.exports = VoiceAnalysisHandler;
