/// Thrown by [FlutterJkBiometric] when a native call fails after the
/// biometric prompt was (or should have been) shown.
class FlutterJkBiometricException implements Exception {
  const FlutterJkBiometricException(this.code, this.message);

  /// The user dismissed/declined the biometric prompt.
  static const userCancelled = 'USER_CANCELLED';

  /// The OS invalidated the vault's key for this `key` — usually because the
  /// user added/removed a fingerprint or face since it was saved. Callers
  /// should treat this like [hasSecret] returning `false` and re-save.
  static const keyInvalidated = 'KEY_INVALIDATED';

  /// Too many failed biometric attempts — the sensor is temporarily locked.
  static const lockedOut = 'LOCKED_OUT';

  /// [readSecret] was called for a `key` with nothing saved.
  static const noData = 'NO_DATA';

  final String code;
  final String message;

  bool get isUserCancelled => code == userCancelled;
  bool get isKeyInvalidated => code == keyInvalidated;
  bool get isLockedOut => code == lockedOut;
  bool get isNoData => code == noData;

  @override
  String toString() => 'FlutterJkBiometricException($code, $message)';
}
