import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

import 'settings_screen.dart';
import 'call_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isProtectionEnabled = true;
  Map<String, int> _statistics = {'blocked': 0, 'allowed': 0};
  bool _isLoading = true;
  List<CallHistoryEntry> _recentCallHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // Health check only on specific events, not continuous pinging
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Smart health check when user resumes app from background
    if (state == AppLifecycleState.resumed) {
      _performSmartHealthCheck('app_resume');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Smart health check on user-initiated refresh
      _performSmartHealthCheck('user_refresh');
      

      
      // Load protection status
      _isProtectionEnabled = await CallService.isProtectionEnabled();
      
      // Load statistics from PostgreSQL backend
      final stats = await ApiService.getCallHistoryStats();
      _statistics = {
        'totalCalls': stats['totalCalls'] ?? 0,
        'blockedCalls': stats['blockedCalls'] ?? 0,
        'silencedCalls': stats['silencedCalls'] ?? 0,
      };
      
      // Load recent call history from PostgreSQL backend
      final recentHistoryData = await ApiService.getRecentCallHistory();
      final recentHistory = recentHistoryData.map((item) => CallHistoryEntry(
        phoneNumber: item['phoneNumber'] ?? '',
        action: item['action'] ?? '',
        reason: item['reason'] ?? '',
        timestamp: DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now(),
        riskLevel: item['riskLevel'] ?? 'medium',
      )).toList();
      
      setState(() {
        _recentCallHistory = recentHistory;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleProtection(bool enabled) async {
    await CallService.setProtectionEnabled(enabled);
    setState(() => _isProtectionEnabled = enabled);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? '🛡️ Protection enabled' : '🔓 Protection disabled',
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }



  /// Smart event-driven health check - only on specific user actions
  /// Called on: OTP validation, manual refresh, app resume from background
  Future<void> _performSmartHealthCheck(String trigger) async {
    try {
      final isHealthy = await ApiService.isBackendHealthy();
      final status = isHealthy ? 'Connected' : 'Disconnected';
      final emoji = isHealthy ? '✅' : '❌';
      
      print('🏥 [Smart] Backend health check ($trigger): $emoji $status');
      
      if (!isHealthy) {
        print('⚠️ [Smart] Backend unreachable on $trigger - app continues with cached data');
      }
    } catch (e) {
      print('🔧 [Smart] Health check error on $trigger: $e');
    }
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
              'ScamShield',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Protection Status Card
                    _buildProtectionCard(),
                    const SizedBox(height: 16),
                    
                    // Call History Card
                    _buildCallHistoryCard(),
                    const SizedBox(height: 16),
                    
                    // Statistics Card
                    _buildStatisticsCard(),
                    const SizedBox(height: 16),
                    
                    // How It Works Card
                    _buildHowItWorksCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProtectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isProtectionEnabled ? Icons.shield : Icons.shield_outlined,
                  color: _isProtectionEnabled ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spam Protection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        _isProtectionEnabled ? 'Active' : 'Disabled',
                        style: TextStyle(
                          color: _isProtectionEnabled ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isProtectionEnabled,
                  onChanged: _toggleProtection,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isProtectionEnabled
                  ? 'Your phone is protected from spam calls. Incoming calls are automatically checked against our spam database.'
                  : 'Protection is disabled. All calls will be allowed through.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryCard() {
    // Use PostgreSQL data loaded in _loadData()
    return _buildCallHistoryContent(_recentCallHistory);
  }
  
  Widget _buildCallHistoryContent(List<CallHistoryEntry> recentCalls) {

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Call Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentCalls.isEmpty)
              const Text(
                'No recent call actions',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...recentCalls.map((call) => _buildCallHistoryItem(call)).toList(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CallHistoryScreen(),
                  ),
                );
              },
              child: const Text('View All History'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryItem(CallHistoryEntry call) {
    final isBlocked = call.action == 'blocked';
    final actionColor = isBlocked ? Colors.red : Colors.orange;
    final actionIcon = isBlocked ? Icons.block : Icons.volume_off;
    final actionText = isBlocked ? 'Blocked' : 'Silenced';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: actionColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            actionIcon,
            color: actionColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.contactName ?? call.phoneNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (call.contactName != null)
                  Text(
                    call.phoneNumber,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  call.reason,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                actionText,
                style: TextStyle(
                  color: actionColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                call.timeAgo,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final totalCalls = _statistics['totalCalls'] ?? 0;
    final blockedCalls = _statistics['blockedCalls'] ?? 0;
    final silencedCalls = _statistics['silencedCalls'] ?? 0;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protection Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Blocked',
                    blockedCalls,
                    Colors.red,
                    Icons.block,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Silenced',
                    silencedCalls,
                    Colors.orange,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalCalls > 0)
              LinearProgressIndicator(
                value: blockedCalls / totalCalls,
                backgroundColor: Colors.green.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            const SizedBox(height: 8),
            Text(
              totalCalls > 0
                  ? 'Blocked ${((blockedCalls / totalCalls) * 100).toStringAsFixed(1)}% of calls'
                  : 'No calls processed yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How ScamShield Works',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildHowItWorksStep(
              1,
              'Incoming Call Detected',
              'ScamShield intercepts incoming calls before they ring',
            ),
            _buildHowItWorksStep(
              2,
              'Real-time Analysis',
              'Phone number is checked against Hiya\'s spam database',
            ),
            _buildHowItWorksStep(
              3,
              'Automatic Action',
              'Spam calls are silently blocked, legitimate calls ring normally',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(int step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
