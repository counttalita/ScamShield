/**
 * Authentication Service
 * Handles phone number registration, OTP verification, and JWT tokens
 */

const twilio = require('twilio');
const jwt = require('jsonwebtoken');
const { log } = require('../utils/helpers');

class AuthService {
  constructor() {
    this.twilioClient = null;
    this.otpStore = new Map(); // In production, use Redis or database
    this.userStore = new Map(); // In production, use proper database
    this.init();
  }

  /**
   * Initialize Twilio client
   */
  init() {
    try {
      const accountSid = process.env.TWILIO_ACCOUNT_SID;
      const authToken = process.env.TWILIO_AUTH_TOKEN;
      
      if (!accountSid || !authToken) {
        log('warn', 'Twilio credentials not found. OTP functionality will be disabled.');
        return;
      }

      this.twilioClient = twilio(accountSid, authToken);
      log('success', 'Twilio client initialized successfully');
    } catch (error) {
      log('error', 'Failed to initialize Twilio client:', error);
    }
  }

  /**
   * Generate and send OTP to phone number
   * @param {string} phoneNumber - Phone number in E.164 format
   * @returns {Promise<Object>} Result with success status and message
   */
  async sendOTP(phoneNumber) {
    try {
      // Validate phone number format
      if (!this.isValidPhoneNumber(phoneNumber)) {
        return {
          success: false,
          message: 'Invalid phone number format. Please use E.164 format (+1234567890)'
        };
      }

      // Generate 6-digit OTP
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      
      // Store OTP with expiration (5 minutes)
      const otpData = {
        otp: otp,
        phoneNumber: phoneNumber,
        expiresAt: Date.now() + (5 * 60 * 1000), // 5 minutes
        attempts: 0
      };
      
      this.otpStore.set(phoneNumber, otpData);

      // Send OTP via Twilio (if available)
      if (this.twilioClient) {
        const message = `Your ScamShield verification code is: ${otp}. Valid for 5 minutes.`;
        
        await this.twilioClient.messages.create({
          body: message,
          from: process.env.TWILIO_PHONE_NUM,
          to: phoneNumber
        });

        log('info', `OTP sent to ${phoneNumber}`);
      } else {
        // Development mode - log OTP
        log('info', `[DEV MODE] OTP for ${phoneNumber}: ${otp}`);
      }

      return {
        success: true,
        message: 'OTP sent successfully',
        expiresIn: 300 // 5 minutes in seconds
      };

    } catch (error) {
      log('error', `Failed to send OTP to ${phoneNumber}:`, error);
      return {
        success: false,
        message: 'Failed to send OTP. Please try again.'
      };
    }
  }

  /**
   * Verify OTP and generate JWT token
   * @param {string} phoneNumber - Phone number
   * @param {string} otp - OTP code
   * @returns {Promise<Object>} Result with token or error
   */
  async verifyOTP(phoneNumber, otp) {
    try {
      const otpData = this.otpStore.get(phoneNumber);
      
      if (!otpData) {
        return {
          success: false,
          message: 'OTP not found or expired. Please request a new one.'
        };
      }

      // Check expiration
      if (Date.now() > otpData.expiresAt) {
        this.otpStore.delete(phoneNumber);
        return {
          success: false,
          message: 'OTP has expired. Please request a new one.'
        };
      }

      // Check attempts
      if (otpData.attempts >= 3) {
        this.otpStore.delete(phoneNumber);
        return {
          success: false,
          message: 'Too many failed attempts. Please request a new OTP.'
        };
      }

      // Verify OTP
      if (otpData.otp !== otp) {
        otpData.attempts++;
        return {
          success: false,
          message: `Invalid OTP. ${3 - otpData.attempts} attempts remaining.`
        };
      }

      // OTP verified - clean up and create/update user
      this.otpStore.delete(phoneNumber);
      
      // Create or update user
      const user = this.createOrUpdateUser(phoneNumber);
      
      // Generate JWT token
      const token = this.generateJWT(user);

      log('info', `User authenticated successfully: ${phoneNumber}`);

      return {
        success: true,
        message: 'Authentication successful',
        token: token,
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          createdAt: user.createdAt,
          lastLogin: user.lastLogin
        }
      };

    } catch (error) {
      log('error', `Failed to verify OTP for ${phoneNumber}:`, error);
      return {
        success: false,
        message: 'Verification failed. Please try again.'
      };
    }
  }

  /**
   * Create or update user record
   * @param {string} phoneNumber - Phone number
   * @returns {Object} User object
   */
  createOrUpdateUser(phoneNumber) {
    let user = this.userStore.get(phoneNumber);
    
    if (!user) {
      // Create new user
      user = {
        id: this.generateUserId(),
        phoneNumber: phoneNumber,
        createdAt: new Date().toISOString(),
        lastLogin: new Date().toISOString(),
        isActive: true
      };
    } else {
      // Update existing user
      user.lastLogin = new Date().toISOString();
    }
    
    this.userStore.set(phoneNumber, user);
    return user;
  }

  /**
   * Generate JWT token
   * @param {Object} user - User object
   * @returns {string} JWT token
   */
  generateJWT(user) {
    const payload = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      iat: Math.floor(Date.now() / 1000)
    };

    return jwt.sign(payload, process.env.JWT_SECRET, {
      expiresIn: '30d' // Token valid for 30 days
    });
  }

  /**
   * Verify JWT token
   * @param {string} token - JWT token
   * @returns {Object|null} Decoded token or null if invalid
   */
  verifyJWT(token) {
    try {
      return jwt.verify(token, process.env.JWT_SECRET);
    } catch (error) {
      log('warn', 'Invalid JWT token:', error.message);
      return null;
    }
  }

  /**
   * Get user by phone number
   * @param {string} phoneNumber - Phone number
   * @returns {Object|null} User object or null
   */
  getUser(phoneNumber) {
    return this.userStore.get(phoneNumber) || null;
  }

  /**
   * Validate phone number format
   * @param {string} phoneNumber - Phone number
   * @returns {boolean} True if valid
   */
  isValidPhoneNumber(phoneNumber) {
    // E.164 format: +[country code][number]
    const e164Regex = /^\+[1-9]\d{1,14}$/;
    return e164Regex.test(phoneNumber);
  }

  /**
   * Generate unique user ID
   * @returns {string} Unique user ID
   */
  generateUserId() {
    return 'user_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  /**
   * Clean up expired OTPs (should be called periodically)
   */
  cleanupExpiredOTPs() {
    const now = Date.now();
    for (const [phoneNumber, otpData] of this.otpStore.entries()) {
      if (now > otpData.expiresAt) {
        this.otpStore.delete(phoneNumber);
      }
    }
  }

  /**
   * Get authentication statistics
   * @returns {Object} Statistics
   */
  getStats() {
    return {
      totalUsers: this.userStore.size,
      activeOTPs: this.otpStore.size,
      twilioEnabled: !!this.twilioClient
    };
  }
}

module.exports = AuthService;
