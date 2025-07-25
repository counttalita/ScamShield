import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../services/app_info_service.dart';
import '../services/contacts_service.dart';
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
      appBar: AppBar(title: const Text('Settings')),
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
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Subscription'),
            content: const Text(
              'ScamShield Premium provides unlimited spam call protection for \$2/month.\n\n'
              'Features:\n'
              '• Real-time spam detection\n'
              '• Automatic call blocking\n'
              '• Call history and statistics\n'
              '• Priority support',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Implement subscription flow
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subscription management coming soon!'),
                    ),
                  );
                },
                child: const Text('Subscribe'),
              ),
            ],
          ),
    );
  }
}
