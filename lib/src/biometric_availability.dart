/// Whether this device can show a biometric prompt right now.
enum BiometricAvailability {
  /// Hardware present and at least one biometric enrolled — safe to call
  /// [saveSecret]/[readSecret].
  available,

  /// No biometric sensor on this device (or it's permanently disabled).
  noHardware,

  /// Hardware present but the user hasn't enrolled a fingerprint/face yet —
  /// send them to the OS settings instead of calling [saveSecret].
  notEnrolled,

  /// Platform returned something this plugin doesn't recognize.
  unknown,
}
