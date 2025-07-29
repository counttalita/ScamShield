import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';

class AppwriteTestWidget extends StatefulWidget {
  const AppwriteTestWidget({Key? key}) : super(key: key);

  @override
  State<AppwriteTestWidget> createState() => _AppwriteTestWidgetState();
}

class _AppwriteTestWidgetState extends State<AppwriteTestWidget> {
  bool _isLoading = false;
  String _status = 'Not tested';
  Color _statusColor = Colors.grey;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing...';
      _statusColor = Colors.orange;
    });

    try {
      final isConnected = await AppwriteService.testConnection();
      setState(() {
        _isLoading = false;
        if (isConnected) {
          _status = 'Connected ✅';
          _statusColor = Colors.green;
        } else {
          _status = 'Failed ❌';
          _statusColor = Colors.red;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Appwrite Connection Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status: '),
                Text(
                  _status,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testConnection,
                child: _isLoading
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                    : const Text('Test Appwrite Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
