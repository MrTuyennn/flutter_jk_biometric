/// A category of biometric sensor the device reports as available.
enum BiometricType {
  /// A fingerprint sensor (Touch ID, Android fingerprint).
  fingerprint,

  /// A face recognition sensor (Face ID, Android face unlock).
  face,

  /// An iris scanner.
  iris,

  /// Reported by the platform but not one of the known categories above.
  unknown,
}
