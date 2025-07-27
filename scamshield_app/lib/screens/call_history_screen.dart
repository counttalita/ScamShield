import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  List<CallHistoryEntry> _callHistory = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get call history for the last week from PostgreSQL
      final response = await ApiService.getWeeklyCallHistory(page: 1, limit: _pageSize);
      
      final callHistoryData = response['data'] as List<dynamic>? ?? [];
      
      if (callHistoryData.isNotEmpty) {
        final callHistory = callHistoryData.map<CallHistoryEntry>((item) => CallHistoryEntry(
          phoneNumber: item['phoneNumber'] ?? '',
          timestamp: DateTime.parse(item['timestamp'] ?? DateTime.now().toIso8601String()),
          action: item['action'] ?? 'unknown',
          reason: item['reason'] ?? 'No reason provided',
          riskLevel: item['riskLevel'] ?? 'medium',
        )).toList();
        
        setState(() {
          _callHistory = callHistory;
          _hasMoreData = callHistory.length >= _pageSize;
          _currentPage = 1;
        });
      } else {
        setState(() {
          _callHistory = [];
          _hasMoreData = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      print('❌ Error loading call history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData) return;
    
    setState(() => _isLoading = true);
    
    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getWeeklyCallHistory(page: nextPage, limit: _pageSize);
      
      final callHistoryData = response['data'] as List<dynamic>? ?? [];
      
      if (callHistoryData.isNotEmpty) {
        final moreHistory = callHistoryData.map<CallHistoryEntry>((item) => CallHistoryEntry(
          phoneNumber: item['phoneNumber'] ?? '',
          timestamp: DateTime.parse(item['timestamp'] ?? DateTime.now().toIso8601String()),
          action: item['action'] ?? 'unknown',
          reason: item['reason'] ?? 'No reason provided',
          riskLevel: item['riskLevel'] ?? 'medium',
        )).toList();
        
        setState(() {
          _callHistory.addAll(moreHistory);
          _hasMoreData = moreHistory.length >= _pageSize;
          _currentPage = nextPage;
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      print('❌ Error loading more call history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    _currentPage = 0;
    _hasMoreData = true;
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _callHistory.isEmpty && !_isLoading
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _callHistory.length + (_hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _callHistory.length) {
                    return _buildLoadingIndicator();
                  }
                  
                  final call = _callHistory[index];
                  return _buildCallHistoryItem(call);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No call history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your blocked and silenced calls will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(),
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
          color: actionColor.withOpacity(0.2),
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
}
