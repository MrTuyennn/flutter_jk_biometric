## 1.0.0

* Initial release: biometric-gated secret storage (`saveSecret`/`readSecret`/`hasSecret`/
  `deleteSecret`) backed by Android Keystore (`BiometricPrompt`) and iOS Keychain
  (`LocalAuthentication`).
* `checkAvailability()` reports whether the device can show a biometric prompt right now
  (`available`/`noHardware`/`notEnrolled`/`unknown`).
* Failures surface as `FlutterJkBiometricException` with `isUserCancelled`,
  `isKeyInvalidated`, `isLockedOut`, and `isNoData` flags.
