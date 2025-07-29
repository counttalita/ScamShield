import 'dart:io';

class AppwriteConstants {
  // iOS Project ID
  static const String APPWRITE_PROJECT_ID_IOS = "688848600038358e4c8f";
  
  // Android Project ID
  static const String APPWRITE_PROJECT_ID_ANDROID = "688848680038358e4c8f";
  
  // Get the correct project ID based on platform
  static String get APPWRITE_PROJECT_ID {
    if (Platform.isIOS) {
      return APPWRITE_PROJECT_ID_IOS;
    } else if (Platform.isAndroid) {
      return APPWRITE_PROJECT_ID_ANDROID;
    } else {
      // Default to iOS for other platforms (web, etc.)
      return APPWRITE_PROJECT_ID_IOS;
    }
  }
}
