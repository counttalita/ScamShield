/**
 * PostgreSQL Database Service
 * Handles all database operations for ScamShield backend
 */

const { Pool } = require('pg');
const { log } = require('../utils/helpers');

class PostgresService {
  constructor() {
    this.pool = null;
    this.initialized = false;
  }

  /**
   * Initialize PostgreSQL connection pool
   */
  async initialize() {
    try {
      // Database configuration from environment variables
      const config = {
        user: process.env.DB_USER || 'postgres',
        host: process.env.DB_HOST || 'localhost',
        database: process.env.DB_NAME || 'scamshield',
        password: process.env.DB_PASSWORD || 'password',
        port: process.env.DB_PORT || 5432,
        max: 20, // Maximum number of clients in the pool
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
      };

      this.pool = new Pool(config);

      // Test the connection
      const client = await this.pool.connect();
      await client.query('SELECT NOW()');
      client.release();

      this.initialized = true;
      log('success', `PostgreSQL connected successfully to ${config.host}:${config.port}/${config.database}`);

      // Create tables if they don't exist
      await this.createTables();

    } catch (error) {
      log('error', 'Failed to initialize PostgreSQL connection:', error.message);
      throw error;
    }
  }

  /**
   * Create database tables if they don't exist
   */
  async createTables() {
    const createTablesSQL = `
      -- Users table
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        phone_number VARCHAR(20) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_premium BOOLEAN DEFAULT FALSE,
        subscription_status VARCHAR(20) DEFAULT 'trial'
      );

      -- Call history table
      CREATE TABLE IF NOT EXISTS call_history (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(20) NOT NULL,
        phone_number VARCHAR(20) NOT NULL,
        action VARCHAR(20) NOT NULL, -- 'blocked' or 'silenced'
        reason TEXT NOT NULL,
        timestamp TIMESTAMP NOT NULL,
        risk_level VARCHAR(10) NOT NULL, -- 'high', 'medium', 'low'
        session_id VARCHAR(50),
        api_provider VARCHAR(20), -- 'hiya', 'truecaller', 'local', etc.
        confidence DECIMAL(3,2), -- 0.00 to 1.00
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Create indexes for call_history table
      CREATE INDEX IF NOT EXISTS idx_call_history_user_timestamp ON call_history (user_id, timestamp DESC);
      CREATE INDEX IF NOT EXISTS idx_call_history_phone_number ON call_history (phone_number);
      CREATE INDEX IF NOT EXISTS idx_call_history_action ON call_history (action);

      -- Scam numbers cache table
      CREATE TABLE IF NOT EXISTS scam_numbers (
        id SERIAL PRIMARY KEY,
        phone_number VARCHAR(20) UNIQUE NOT NULL,
        risk_level VARCHAR(10) NOT NULL,
        reason TEXT NOT NULL,
        source VARCHAR(50) NOT NULL, -- 'hiya', 'user_report', 'community', etc.
        confidence DECIMAL(3,2),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Create indexes for scam_numbers table
      CREATE INDEX IF NOT EXISTS idx_scam_numbers_phone_number ON scam_numbers (phone_number);
      CREATE INDEX IF NOT EXISTS idx_scam_numbers_risk_level ON scam_numbers (risk_level);

      -- User reports table
      CREATE TABLE IF NOT EXISTS user_reports (
        id SERIAL PRIMARY KEY,
        reporter_id VARCHAR(20) NOT NULL,
        reported_number VARCHAR(20) NOT NULL,
        report_type VARCHAR(20) NOT NULL, -- 'spam', 'scam', 'telemarketing', etc.
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Create indexes for user_reports table
      CREATE INDEX IF NOT EXISTS idx_user_reports_reported_number ON user_reports (reported_number);
      CREATE INDEX IF NOT EXISTS idx_user_reports_reporter ON user_reports (reporter_id);
    `;

    try {
      await this.pool.query(createTablesSQL);
      log('success', 'Database tables created/verified successfully');
    } catch (error) {
      log('error', 'Failed to create database tables:', error.message);
      throw error;
    }
  }

  /**
   * Add call history entry
   */
  async addCallHistory(entry) {
    const query = `
      INSERT INTO call_history (user_id, phone_number, action, reason, timestamp, risk_level, session_id, api_provider, confidence)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id
    `;
    
    const values = [
      entry.userId,
      entry.phoneNumber,
      entry.action,
      entry.reason,
      entry.timestamp,
      entry.riskLevel,
      entry.sessionId,
      entry.apiProvider,
      entry.confidence
    ];

    try {
      const result = await this.pool.query(query, values);
      return result.rows[0].id;
    } catch (error) {
      log('error', 'Failed to add call history:', error.message);
      throw error;
    }
  }

  /**
   * Get call history for a user (paginated)
   */
  async getCallHistory(userId, limit = 20, offset = 0, daysBack = 7) {
    const query = `
      SELECT * FROM call_history 
      WHERE user_id = $1 
        AND timestamp >= NOW() - INTERVAL '${daysBack} days'
      ORDER BY timestamp DESC 
      LIMIT $2 OFFSET $3
    `;

    try {
      const result = await this.pool.query(query, [userId, limit, offset]);
      return result.rows;
    } catch (error) {
      log('error', 'Failed to get call history:', error.message);
      throw error;
    }
  }

  /**
   * Get recent call history (last 5 entries)
   */
  async getRecentCallHistory(userId) {
    return await this.getCallHistory(userId, 5, 0, 7);
  }

  /**
   * Get call history statistics for a user
   */
  async getCallHistoryStats(userId, daysBack = 7) {
    const query = `
      SELECT 
        COUNT(*) as total_calls,
        COUNT(CASE WHEN action = 'blocked' THEN 1 END) as blocked_calls,
        COUNT(CASE WHEN action = 'silenced' THEN 1 END) as silenced_calls
      FROM call_history 
      WHERE user_id = $1 
        AND timestamp >= NOW() - INTERVAL '${daysBack} days'
    `;

    try {
      const result = await this.pool.query(query, [userId]);
      return result.rows[0];
    } catch (error) {
      log('error', 'Failed to get call history stats:', error.message);
      throw error;
    }
  }

  /**
   * Clear call history for a user (for testing)
   */
  async clearCallHistory(userId) {
    const query = 'DELETE FROM call_history WHERE user_id = $1';
    
    try {
      const result = await this.pool.query(query, [userId]);
      return result.rowCount;
    } catch (error) {
      log('error', 'Failed to clear call history:', error.message);
      throw error;
    }
  }

  /**
   * Close database connection
   */
  async close() {
    if (this.pool) {
      await this.pool.end();
      log('info', 'PostgreSQL connection pool closed');
    }
  }

  /**
   * Execute raw SQL query (for seeding and maintenance)
   */
  async query(sql, params = []) {
    try {
      const result = await this.pool.query(sql, params);
      return result;
    } catch (error) {
      log('error', 'Database query failed:', error.message);
      throw error;
    }
  }
}

module.exports = PostgresService;
