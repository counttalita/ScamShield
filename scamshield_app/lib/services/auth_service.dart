import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/biometric_models.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:3000';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTimeoutKey = 'biometric_timeout';
  static const String _biometricFailedAttemptsKey = 'biometric_failed_attempts';
  static const String _biometricLastFailureKey = 'biometric_last_failure';
  static const int _defaultBiometricTimeout = 30; // 30 seconds default
  static const int _maxFailedAttempts =
      3; // Max failed attempts before cooldown
  static const int _cooldownMinutes = 5; // Cooldown period in minutes

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Send OTP to phone number
  static Future<AuthResult> sendOTP(String phoneNumber) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': phoneNumber}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return AuthResult(
          success: true,
          message: data['message'],
          expiresIn: data['expiresIn'],
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to send OTP',
          code: data['code'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Verify OTP and login/register user
  static Future<AuthResult> verifyOTP(String phoneNumber, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': phoneNumber, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Save token and user data
        await _saveAuthData(data['token'], data['user']);

        return AuthResult(
          success: true,
          message: data['message'],
          token: data['token'],
          user: User.fromJson(data['user']),
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to verify OTP',
          code: data['code'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Get stored auth token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get stored user data
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  /// Save authentication data
  static Future<void> _saveAuthData(
    String token,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Save sensitive data securely
  Future<void> saveSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Retrieve sensitive data securely
  Future<String?> getSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        // Call logout endpoint
        await http
            .post(
              Uri.parse('$_baseUrl/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      // Continue with local logout even if server call fails
    }

    // Clear local data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Enable biometric authentication
  Future<bool> enableBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Enable biometric authentication for ScamShield',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_biometricEnabledKey, true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, false);
  }

  /// Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Check if biometric authentication is in cooldown period
  Future<bool> _isBiometricInCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_biometricFailedAttemptsKey) ?? 0;

    if (failedAttempts >= _maxFailedAttempts) {
      final lastFailure = prefs.getInt(_biometricLastFailureKey) ?? 0;
      final cooldownEnd = lastFailure + (_cooldownMinutes * 60 * 1000);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now < cooldownEnd) {
        return true; // Still in cooldown
      } else {
        // Cooldown expired, reset attempts
        await prefs.remove(_biometricFailedAttemptsKey);
        await prefs.remove(_biometricLastFailureKey);
        return false;
      }
    }
    return false;
  }

  /// Record failed biometric attempt
  Future<void> _recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAttempts = prefs.getInt(_biometricFailedAttemptsKey) ?? 0;
    final newAttempts = currentAttempts + 1;

    await prefs.setInt(_biometricFailedAttemptsKey, newAttempts);

    if (newAttempts >= _maxFailedAttempts) {
      await prefs.setInt(
        _biometricLastFailureKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Reset failed biometric attempts
  Future<void> _resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricFailedAttemptsKey);
    await prefs.remove(_biometricLastFailureKey);
  }

  /// Get remaining cooldown time in minutes
  Future<int> getBiometricCooldownMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_biometricFailedAttemptsKey) ?? 0;

    if (failedAttempts >= _maxFailedAttempts) {
      final lastFailure = prefs.getInt(_biometricLastFailureKey) ?? 0;
      final cooldownEnd = lastFailure + (_cooldownMinutes * 60 * 1000);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now < cooldownEnd) {
        return ((cooldownEnd - now) / (60 * 1000)).ceil();
      }
    }
    return 0;
  }

  /// Enhanced biometric authentication with security features
  Future<BiometricAuthResult> authenticateWithBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return BiometricAuthResult(
          success: false,
          error: 'Biometric authentication is not enabled',
          errorType: BiometricErrorType.notEnabled,
        );
      }

      // Check if in cooldown period
      final inCooldown = await _isBiometricInCooldown();
      if (inCooldown) {
        final remainingMinutes = await getBiometricCooldownMinutes();
        return BiometricAuthResult(
          success: false,
          error:
              'Too many failed attempts. Try again in $remainingMinutes minutes.',
          errorType: BiometricErrorType.cooldown,
          cooldownMinutes: remainingMinutes,
        );
      }

      final timeout = await getBiometricTimeout();

      final didAuthenticate = await _localAuth
          .authenticate(
            localizedReason: 'Authenticate to access ScamShield',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          )
          .timeout(Duration(seconds: timeout));

      if (didAuthenticate) {
        // Reset failed attempts on successful authentication
        await _resetFailedAttempts();
        return BiometricAuthResult(success: true);
      } else {
        // Record failed attempt
        await _recordFailedAttempt();
        return BiometricAuthResult(
          success: false,
          error: 'Biometric authentication failed',
          errorType: BiometricErrorType.authenticationFailed,
        );
      }
    } catch (e) {
      // Record failed attempt for exceptions too
      await _recordFailedAttempt();

      if (e.toString().contains('UserCancel')) {
        return BiometricAuthResult(
          success: false,
          error: 'Authentication cancelled by user',
          errorType: BiometricErrorType.userCancelled,
        );
      } else if (e.toString().contains('timeout')) {
        return BiometricAuthResult(
          success: false,
          error: 'Authentication timed out',
          errorType: BiometricErrorType.timeout,
        );
      } else {
        return BiometricAuthResult(
          success: false,
          error: 'Biometric authentication error: ${e.toString()}',
          errorType: BiometricErrorType.systemError,
        );
      }
    }
  }

  /// Authenticate with biometric with custom timeout (legacy method for backward compatibility)
  Future<bool> authenticateWithBiometricTimeout({
    required String reason,
    int? timeoutSeconds,
  }) async {
    final result = await authenticateWithBiometric();
    return result.success;
  }

  /// Legacy method for backward compatibility
  Future<bool> authenticateWithBiometricLegacy() async {
    final result = await authenticateWithBiometric();
    return result.success;
  }

  /// Set biometric authentication timeout
  Future<void> setBiometricTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_biometricTimeoutKey, seconds);
  }

  /// Get biometric authentication timeout
  Future<int> getBiometricTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_biometricTimeoutKey) ?? _defaultBiometricTimeout;
  }

  /// Reset biometric timeout to default
  Future<void> resetBiometricTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricTimeoutKey);
  }

  /// Get user profile from server
  static Future<AuthResult> getUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(
          success: false,
          message: 'No authentication token found',
          code: 'NO_TOKEN',
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return AuthResult(success: true, user: User.fromJson(data['user']));
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to get user profile',
          code: data['code'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Refresh authentication token
  static Future<AuthResult> refreshToken() async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(
          success: false,
          message: 'No authentication token found',
          code: 'NO_TOKEN',
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Save new token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['token']);

        return AuthResult(
          success: true,
          message: data['message'],
          token: data['token'],
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to refresh token',
          code: data['code'],
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }
}

/// User model - matches backend structure exactly
class User {
  final String id;
  final String phoneNumber;
  final String createdAt;
  final String lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.phoneNumber,
    required this.createdAt,
    required this.lastLogin,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      createdAt: json['createdAt'],
      lastLogin: json['lastLogin'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'isActive': isActive,
    };
  }
}
