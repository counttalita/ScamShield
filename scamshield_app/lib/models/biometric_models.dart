/// Biometric error types
enum BiometricErrorType {
  notEnabled,
  cooldown,
  authenticationFailed,
  userCancelled,
  timeout,
  systemError,
}

/// Enhanced biometric authentication result
class BiometricAuthResult {
  final bool success;
  final String? error;
  final BiometricErrorType? errorType;
  final int? cooldownMinutes;

  BiometricAuthResult({
    required this.success,
    this.error,
    this.errorType,
    this.cooldownMinutes,
  });

  @override
  String toString() {
    if (success) {
      return 'BiometricAuthResult(success: true)';
    } else {
      return 'BiometricAuthResult(success: false, error: $error, type: $errorType)';
    }
  }
}
