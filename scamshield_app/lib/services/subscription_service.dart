import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static SubscriptionService get instance => _instance;

  // Paystack Configuration
  static const String _publicKey = 'pk_test_17888922be48dfe8b87c86a4cec5eaae533f06c0';
  static const String _secretKey = 'sk_test_564758713eb90887f7d1a4c91a74ab46b12b66da';
  static const String _planCode = 'PLN_g9u94yi9dyrf5ut';
  
  // Subscription Details
  static const int _monthlyAmountZAR = 3500; // ZAR 35.00 in kobo/cents
  static const int _trialDays = 30;



  // Check if user is on trial
  Future<bool> isOnTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStartDate = prefs.getString('trial_start_date');
    
    if (trialStartDate == null) return false;
    
    final startDate = DateTime.parse(trialStartDate);
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    
    return daysSinceStart < _trialDays;
  }

  // Start free trial
  Future<bool> startFreeTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    
    await prefs.setString('trial_start_date', now);
    await prefs.setBool('has_started_trial', true);
    await prefs.setString('subscription_status', 'trial');
    
    return true;
  }

  // Get trial days remaining
  Future<int> getTrialDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStartDate = prefs.getString('trial_start_date');
    
    if (trialStartDate == null) return 0;
    
    final startDate = DateTime.parse(trialStartDate);
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    
    return (_trialDays - daysSinceStart).clamp(0, _trialDays);
  }

  // Check if user has premium subscription
  Future<bool> hasPremiumSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString('subscription_status') ?? 'none';
    return status == 'active' || status == 'trial';
  }

  // Get subscription status
  Future<String> getSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString('subscription_status') ?? 'none';
    
    if (status == 'trial') {
      final isStillOnTrial = await isOnTrial();
      if (!isStillOnTrial) {
        await prefs.setString('subscription_status', 'expired');
        return 'expired';
      }
    }
    
    return status;
  }

  // Initialize payment with Paystack (HTTP-based)
  Future<bool> initializePayment({
    required String email,
    required BuildContext context,
  }) async {
    try {
      // Create payment initialization request
      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'amount': _monthlyAmountZAR,
          'currency': 'ZAR',
          'plan': _planCode,
          'reference': 'scamshield_${DateTime.now().millisecondsSinceEpoch}',
          'callback_url': 'https://scamshield.app/payment/callback',
          'metadata': {
            'subscription_type': 'premium',
            'trial_converted': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == true) {
          final authorizationUrl = data['data']['authorization_url'] as String;
          final reference = data['data']['reference'] as String;
          
          // Launch payment URL in browser
          final uri = Uri.parse(authorizationUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            
            // Store payment reference for verification
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pending_payment_reference', reference);
            
            // Show success message (payment verification will happen separately)
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment initiated! Complete payment in your browser.'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
            
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Payment initialization error: $e');
      return false;
    }
  }



  // Get subscription details
  Future<Map<String, dynamic>> getSubscriptionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await getSubscriptionStatus();
    
    return {
      'status': status,
      'plan_code': _planCode,
      'amount': _monthlyAmountZAR,
      'currency': 'ZAR',
      'trial_days_remaining': await getTrialDaysRemaining(),
      'is_on_trial': await isOnTrial(),
      'has_premium': await hasPremiumSubscription(),
      'start_date': prefs.getString('subscription_start_date'),
      'trial_start_date': prefs.getString('trial_start_date'),
    };
  }



  // Check if user has started trial before
  Future<bool> hasStartedTrialBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_started_trial') ?? false;
  }

  // Format amount for display
  String formatAmount(int amountInCents) {
    return 'R${(amountInCents / 100).toStringAsFixed(2)}';
  }

  // Get formatted subscription price
  String get formattedPrice => formatAmount(_monthlyAmountZAR);

  // Get trial period text
  String get trialPeriodText => '$_trialDays days';

  // Cancel subscription
  Future<bool> cancelSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('subscription_status', 'cancelled');
    await prefs.setString('subscription_cancelled_date', DateTime.now().toIso8601String());
    
    // Sync cancellation with backend
    await _syncSubscriptionToBackend('cancelled');
    
    return true;
  }

  // Sync subscription status to backend database
  Future<bool> _syncSubscriptionToBackend(String status) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('No auth token available for subscription sync');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/subscription/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': status,
          'plan_code': _planCode,
          'amount': _monthlyAmountZAR,
          'currency': 'ZAR',
          'trial_start_date': prefs.getString('trial_start_date'),
          'subscription_start_date': prefs.getString('subscription_start_date'),
          'payment_reference': prefs.getString('pending_payment_reference'),
          'sync_timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Update local status based on backend response
          final backendStatus = data['subscription_status'];
          if (backendStatus != null) {
            await prefs.setString('subscription_status', backendStatus);
          }
          return true;
        }
      }
      
      print('Failed to sync subscription to backend: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error syncing subscription to backend: $e');
      return false;
    }
  }

  // Get auth token for backend requests
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      return null;
    }
  }

  // Sync subscription status from backend (for feature access control)
  Future<Map<String, dynamic>> syncFromBackend() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('http://localhost:3000/api/subscription/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final subscription = data['subscription'];
          
          // Update local storage with backend data
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('subscription_status', subscription['status'] ?? 'none');
          
          if (subscription['trial_start_date'] != null) {
            await prefs.setString('trial_start_date', subscription['trial_start_date']);
          }
          
          if (subscription['subscription_start_date'] != null) {
            await prefs.setString('subscription_start_date', subscription['subscription_start_date']);
          }
          
          return {
            'success': true,
            'status': subscription['status'],
            'has_premium': subscription['has_premium'] ?? false,
            'features_enabled': subscription['features_enabled'] ?? {},
          };
        }
      }
      
      return {'success': false, 'error': 'Failed to fetch from backend'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Check if specific feature is enabled based on subscription
  Future<bool> isFeatureEnabled(String featureName) async {
    try {
      // First sync with backend to get latest status
      final syncResult = await syncFromBackend();
      
      if (syncResult['success'] == true) {
        final featuresEnabled = syncResult['features_enabled'] as Map<String, dynamic>? ?? {};
        return featuresEnabled[featureName] == true;
      }
      
      // Fallback to local check if backend sync fails
      final hasPremium = await hasPremiumSubscription();
      
      // Define premium features
      const premiumFeatures = {
        'real_time_detection': true,
        'auto_block': true,
        'call_statistics': true,
        'priority_support': true,
        'advanced_filters': true,
      };
      
      return hasPremium && (premiumFeatures[featureName] == true);
    } catch (e) {
      print('Error checking feature access: $e');
      return false;
    }
  }

  // Update subscription status after successful payment
  Future<void> handleSuccessfulPayment(String paymentReference) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    await prefs.setString('subscription_status', 'active');
    await prefs.setString('subscription_start_date', now.toIso8601String());
    await prefs.setString('payment_reference', paymentReference);
    await prefs.remove('pending_payment_reference');
    
    // Clear trial data since user is now subscribed
    await prefs.remove('trial_start_date');
    
    // Sync with backend
    await _syncSubscriptionToBackend('active');
  }
}
