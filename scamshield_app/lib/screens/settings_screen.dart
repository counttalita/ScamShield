import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../services/app_info_service.dart';
import '../services/contacts_service.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProtectionEnabled = true;
  bool _showNotifications = true;
  bool _blockUnknownNumbers = false;
  String _backendUrl = 'http://localhost:3000';
  bool _isBackendHealthy = false;
  String _appVersion = 'Loading...';
  bool _hasContactsPermission = false;
  bool _isCheckingContactsPermission = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBackendHealth();
    _loadAppVersion();
    _checkContactsPermission();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isProtectionEnabled = prefs.getBool('protection_enabled') ?? true;
      _showNotifications = prefs.getBool('show_notifications') ?? true;
      _blockUnknownNumbers = prefs.getBool('block_unknown_numbers') ?? false;
      _backendUrl = prefs.getString('backend_url') ?? 'http://localhost:3000';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('protection_enabled', _isProtectionEnabled);
    await prefs.setBool('show_notifications', _showNotifications);
    await prefs.setBool('block_unknown_numbers', _blockUnknownNumbers);
    await prefs.setString('backend_url', _backendUrl);

    // Update call service
    await CallService.setProtectionEnabled(_isProtectionEnabled);
  }

  /// Load app version from package info
  Future<void> _loadAppVersion() async {
    try {
      await AppInfoService.instance.initialize();
      setState(() {
        _appVersion = AppInfoService.instance.displayVersion;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'ScamShield v1.0.0'; // Fallback
      });
    }
  }

  /// Check contacts permission status
  Future<void> _checkContactsPermission() async {
    try {
      final hasPermission = await ContactsService.instance.hasContactsPermission();
      setState(() {
        _hasContactsPermission = hasPermission;
      });
    } catch (e) {
      setState(() {
        _hasContactsPermission = false;
      });
    }
  }

  /// Check backend health
  Future<void> _checkBackendHealth() async {
    try {
      final isHealthy = await ApiService.isBackendHealthy();
      setState(() {
        _isBackendHealthy = isHealthy;
      });
    } catch (e) {
      setState(() {
        _isBackendHealthy = false;
      });
    }
  }

  /// Handle block unknown numbers toggle with permission check
  Future<void> _handleBlockUnknownNumbersToggle(bool value) async {
    if (value && !_hasContactsPermission) {
      // Show permission explanation dialog
      final shouldRequest = await _showContactsPermissionDialog();
      if (!shouldRequest) return;

      setState(() {
        _isCheckingContactsPermission = true;
      });

      try {
        final granted = await ContactsService.instance.requestContactsPermission();
        setState(() {
          _hasContactsPermission = granted;
          _isCheckingContactsPermission = false;
        });

        if (granted) {
          setState(() {
            _blockUnknownNumbers = true;
          });
          await _saveSettings();
        } else {
          _showPermissionDeniedDialog();
        }
      } catch (e) {
        setState(() {
          _isCheckingContactsPermission = false;
        });
        _showPermissionErrorDialog();
      }
    } else {
      setState(() {
        _blockUnknownNumbers = value;
      });
      await _saveSettings();
    }
  }

  /// Show contacts permission explanation dialog
  Future<bool> _showContactsPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacts Permission Required'),
        content: const Text(
          'To block unknown numbers, ScamShield needs access to your contacts to determine which numbers are known to you.\n\n'
          'Your contact information stays on your device and is never sent to our servers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show permission denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Contacts permission is required to block unknown numbers. '
          'You can enable this permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show permission error dialog
  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Error'),
        content: const Text(
          'An error occurred while requesting contacts permission. '
          'Please try again or check your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('call_history');
    await prefs.remove('blocked_calls_count');
    await prefs.remove('allowed_calls_count');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call history cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showBackendUrlDialog() async {
    final controller = TextEditingController(text: _backendUrl);

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Backend URL'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://localhost:3000',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _backendUrl = controller.text);
                  _saveSettings();
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/ScamShield.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Protection Settings
          _buildSectionHeader('Protection'),
          _buildSwitchTile(
            title: 'Enable Protection',
            subtitle: 'Block spam calls automatically',
            value: _isProtectionEnabled,
            onChanged: (value) {
              setState(() => _isProtectionEnabled = value);
              _saveSettings();
            },
            icon: Icons.shield,
          ),
          _buildSwitchTile(
            title: 'Block Unknown Numbers',
            subtitle: _hasContactsPermission 
                ? 'Block calls from numbers not in contacts'
                : 'Requires contacts permission to work',
            value: _blockUnknownNumbers,
            onChanged: _isCheckingContactsPermission ? null : _handleBlockUnknownNumbersToggle,
            icon: Icons.contact_phone,
            trailing: _isCheckingContactsPermission 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),

          const SizedBox(height: 24),

          // Notification Settings
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            title: 'Show Notifications',
            subtitle: 'Get notified when calls are blocked',
            value: _showNotifications,
            onChanged: (value) {
              setState(() => _showNotifications = value);
              _saveSettings();
            },
            icon: Icons.notifications,
          ),

          const SizedBox(height: 24),

          // Backend Settings
          _buildSectionHeader('Backend'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Backend URL'),
            subtitle: Text(_backendUrl),
            trailing: const Icon(Icons.edit),
            onTap: _showBackendUrlDialog,
          ),

          const SizedBox(height: 24),

          // Data Management
          _buildSectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Clear Call History'),
            subtitle: const Text('Remove all call logs and statistics'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showClearHistoryDialog(),
          ),

          const SizedBox(height: 24),

          // About
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About ScamShield'),
            subtitle: Text(_appVersion),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showAboutDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showPrivacyDialog(),
          ),

          const SizedBox(height: 32),

          // Subscription Info
          _buildSubscriptionCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildSubscriptionCard() {
    return Card(
      elevation: 4,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'ScamShield Premium',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlimited protection for just \$2/month',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _showSubscriptionDialog(),
              child: const Text('Manage Subscription'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearHistoryDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Call History'),
            content: const Text(
              'This will permanently delete all call logs and statistics. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _clearCallHistory();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAboutDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About ScamShield'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ScamShield v1.0.0'),
                SizedBox(height: 8),
                Text('Real-time spam call protection powered by TOSH.'),
                SizedBox(height: 8),
                Text('© 2025 ScamShield Team'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _showPrivacyDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'ScamShield respects your privacy. We only process phone numbers to check against spam databases. No personal information is stored or shared with third parties.\n\n'
                'Call data is processed locally and only phone numbers are sent to our secure backend for spam verification.\n\n'
                'For more information, visit our website.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _showSubscriptionDialog() async {
    final subscriptionService = SubscriptionService.instance;
    final details = await subscriptionService.getSubscriptionDetails();
    final status = details['status'] as String;
    final hasPremium = details['has_premium'] as bool;
    final trialDaysRemaining = details['trial_days_remaining'] as int;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/ScamShield.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ScamShield Premium',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(status, trialDaysRemaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Pricing
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        subscriptionService.formattedPrice,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        '/month',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${subscriptionService.trialPeriodText} FREE TRIAL',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Features
            const Text(
              'Premium Features:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('Real-time spam detection'),
            _buildFeatureItem('Automatic call blocking'),
            _buildFeatureItem('Call history and statistics'),
            _buildFeatureItem('Priority support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSubscriptionAction(status, hasPremium);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getActionButtonColor(status),
            ),
            child: Text(_getActionButtonText(status, hasPremium)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(feature, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'trial':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, int trialDaysRemaining) {
    switch (status) {
      case 'active':
        return 'Premium Active';
      case 'trial':
        return 'Trial: $trialDaysRemaining days left';
      case 'expired':
        return 'Trial Expired';
      default:
        return 'No Subscription';
    }
  }

  Color _getActionButtonColor(String status) {
    switch (status) {
      case 'active':
        return Colors.grey;
      case 'trial':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _getActionButtonText(String status, bool hasPremium) {
    switch (status) {
      case 'active':
        return 'Manage';
      case 'trial':
        return 'Upgrade Now';
      case 'expired':
        return 'Subscribe';
      default:
        return hasPremium ? 'Subscribe' : 'Start Free Trial';
    }
  }

  Future<void> _handleSubscriptionAction(String status, bool hasPremium) async {
    final subscriptionService = SubscriptionService.instance;
    
    if (status == 'active') {
      _showManageSubscriptionDialog();
    } else if (status == 'none' && !hasPremium) {
      await _startFreeTrial();
    } else {
      await _showPaymentDialog();
    }
  }

  Future<void> _startFreeTrial() async {
    final subscriptionService = SubscriptionService.instance;
    
    try {
      final success = await subscriptionService.startFreeTrial();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Free trial started! Enjoy 30 days of premium protection.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar('Failed to start trial. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred. Please try again.');
    }
  }

  Future<void> _showPaymentDialog() async {
    final emailController = TextEditingController();
    
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe to Premium'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'your@email.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );

    if (email != null && email.isNotEmpty) {
      await _processPayment(email);
    }
  }

  Future<void> _processPayment(String email) async {
    final subscriptionService = SubscriptionService.instance;
    
    try {
      final success = await subscriptionService.initializePayment(
        email: email,
        context: context,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Payment successful! Welcome to ScamShield Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar('Payment failed. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Payment error. Please try again.');
    }
  }

  void _showManageSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: const Text(
          'Your premium subscription is active. You can manage your subscription through your Paystack dashboard or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCancelSubscriptionDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your premium subscription? You will lose access to premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final subscriptionService = SubscriptionService.instance;
              await subscriptionService.cancelSubscription();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription cancelled successfully.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
