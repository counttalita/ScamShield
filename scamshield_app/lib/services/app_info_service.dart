import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  static AppInfoService? _instance;
  static AppInfoService get instance => _instance ??= AppInfoService._();
  AppInfoService._();

  PackageInfo? _packageInfo;

  /// Initialize package info (call this once at app startup)
  Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get app version (e.g., "1.0.0")
  String get version {
    return _packageInfo?.version ?? '1.0.0';
  }

  /// Get build number (e.g., "1")
  String get buildNumber {
    return _packageInfo?.buildNumber ?? '1';
  }

  /// Get full version string (e.g., "1.0.0 (1)")
  String get fullVersion {
    return '${version} (${buildNumber})';
  }

  /// Get app name
  String get appName {
    return _packageInfo?.appName ?? 'ScamShield';
  }

  /// Get package name (bundle identifier)
  String get packageName {
    return _packageInfo?.packageName ?? 'com.example.scamshield';
  }

  /// Get formatted version for display (e.g., "ScamShield v1.0.0")
  String get displayVersion {
    return '${appName} v${version}';
  }

  /// Get detailed app info for debugging
  Map<String, String> get appInfo {
    return {
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'buildNumber': buildNumber,
      'fullVersion': fullVersion,
    };
  }
}
