import 'package:flutter/material.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProtectionEnabled = true;
  bool _isBackendHealthy = false;
  Map<String, int> _statistics = {'blocked': 0, 'allowed': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load protection status
      _isProtectionEnabled = await CallService.isProtectionEnabled();
      
      // Check backend health
      _isBackendHealthy = await ApiService.isBackendHealthy();
      
      // Load statistics
      _statistics = await CallService.getStatistics();
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScamShield'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                    
                    // Backend Status Card
                    _buildBackendStatusCard(),
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

  Widget _buildBackendStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _isBackendHealthy ? Icons.cloud_done : Icons.cloud_off,
              color: _isBackendHealthy ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backend Service',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _isBackendHealthy ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: _isBackendHealthy ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final totalCalls = _statistics['blocked']! + _statistics['allowed']!;
    
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
                    _statistics['blocked']!,
                    Colors.red,
                    Icons.block,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Allowed',
                    _statistics['allowed']!,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalCalls > 0)
              LinearProgressIndicator(
                value: _statistics['blocked']! / totalCalls,
                backgroundColor: Colors.green.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            const SizedBox(height: 8),
            Text(
              totalCalls > 0
                  ? 'Blocked ${((_statistics['blocked']! / totalCalls) * 100).toStringAsFixed(1)}% of calls'
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
