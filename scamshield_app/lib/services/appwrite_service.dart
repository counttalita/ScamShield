import 'package:appwrite/appwrite.dart';
import '../constants/appwrite.dart';

class AppwriteService {
  static Client? _client;
  static Account? _account;

  static Client get client {
    _client ??= Client()
        .setEndpoint('https://cloud.appwrite.io/v1')
        .setProject(AppwriteConstants.APPWRITE_PROJECT_ID);
    return _client!;
  }

  static Account get account {
    _account ??= Account(client);
    return _account!;
  }

  // Simple connectivity test method
  static Future<bool> testConnection() async {
    try {
      // Test basic client connectivity
      final account = Account(client);
      // Try to create an anonymous session - this tests connectivity
      await account.createAnonymousSession();
      print('✅ Appwrite connected successfully!');
      return true;
    } catch (e) {
      // Check if it's just a session already exists error
      if (e.toString().contains('session') || e.toString().contains('user')) {
        print('✅ Appwrite connected successfully! (Already has session)');
        return true;
      }
      print('❌ Appwrite connection failed: $e');
      return false;
    }
  }
}
