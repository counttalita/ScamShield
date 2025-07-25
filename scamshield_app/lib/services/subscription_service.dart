import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  late PaystackPlugin _paystack;
  bool _isInitialized = false;

  // Initialize Paystack
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _paystack = PaystackPlugin();
    await _paystack.initialize(publicKey: _publicKey);
    _isInitialized = true;
  }

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

  // Initialize payment for subscription
  Future<bool> initializePayment({
    required String email,
    required BuildContext context,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final charge = Charge()
        ..amount = _monthlyAmountZAR
        ..currency = 'ZAR'
        ..reference = _generateReference()
        ..email = email
        ..plan = _planCode;

      final response = await _paystack.checkout(
        context,
        method: CheckoutMethod.card,
        charge: charge,
      );

      if (response.status) {
        await _handleSuccessfulPayment(response);
        return true;
      } else {
        debugPrint('Payment failed: ${response.message}');
        return false;
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      return false;
    }
  }

  // Handle successful payment
  Future<void> _handleSuccessfulPayment(CheckoutResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    await prefs.setString('subscription_status', 'active');
    await prefs.setString('subscription_start_date', now.toIso8601String());
    await prefs.setString('subscription_reference', response.reference ?? '');
    await prefs.setString('subscription_plan_code', _planCode);
    await prefs.setInt('subscription_amount', _monthlyAmountZAR);
    
    // Clear trial data since user is now subscribed
    await prefs.remove('trial_start_date');
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

  // Generate unique payment reference
  String _generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'scamshield_$timestamp';
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
    
    return true;
  }
}
