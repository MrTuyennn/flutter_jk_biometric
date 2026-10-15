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

  /// Too many failed biometric attempts — the sensor is temporarily locked
  /// (Android only; resets on its own after a short wait).
  static const lockedOut = 'LOCKED_OUT';

  /// Too many failed attempts and the lockout won't clear on its own — the
  /// user must unlock with their device PIN/pattern/password first.
  static const lockedOutPermanently = 'LOCKED_OUT_PERMANENTLY';

  /// [readSecret] was called for a `key` with nothing saved.
  static const noData = 'NO_DATA';

  /// Another [saveSecret]/[readSecret] call already has a biometric prompt
  /// in progress; only one can run at a time.
  static const authInProgress = 'AUTH_IN_PROGRESS';

  final String code;
  final String message;

  bool get isUserCancelled => code == userCancelled;
  bool get isKeyInvalidated => code == keyInvalidated;
  bool get isLockedOut => code == lockedOut;
  bool get isLockedOutPermanently => code == lockedOutPermanently;
  bool get isNoData => code == noData;
  bool get isAuthInProgress => code == authInProgress;

  @override
  String toString() => 'FlutterJkBiometricException($code, $message)';
}
