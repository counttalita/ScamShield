import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:3000';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Send OTP to phone number
  static Future<AuthResult> sendOTP(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 10));

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
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 10));

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
  static Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        // Call logout endpoint
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
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

  /// Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access ScamShield',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
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

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return AuthResult(
          success: true,
          user: User.fromJson(data['user']),
        );
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

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

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

/// Authentication result model
class AuthResult {
  final bool success;
  final String? message;
  final String? code;
  final String? token;
  final User? user;
  final int? expiresIn;

  AuthResult({
    required this.success,
    this.message,
    this.code,
    this.token,
    this.user,
    this.expiresIn,
  });
}

/// User model
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
    required this.isActive,
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
