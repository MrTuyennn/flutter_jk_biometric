## 1.0.1

* Fix: `saveSecret`/`readSecret` now reject a concurrent call with
  `FlutterJkBiometricException.isAuthInProgress` instead of risking a crash
  (Android) or stacking a second Face ID/Touch ID prompt (iOS) when two calls
  overlap.
* Fix (Android): if the host `Activity` is detached while a biometric prompt
  is showing, the pending `saveSecret`/`readSecret` call is now failed with
  `ACTIVITY_DETACHED` instead of leaving the Dart `Future` pending forever.
* Fix (iOS): `readSecret` now authenticates via an explicit `LAContext` and
  passes it to the Keychain query via `kSecUseAuthenticationContext`, instead
  of the deprecated (and on current iOS, largely ignored by Face ID)
  `kSecUseOperationPrompt`. The `reason` text is now reliably shown.
* Add `allowDeviceCredential` parameter to `saveSecret`/`readSecret` to allow
  falling back to the device PIN/pattern/password when biometrics aren't
  usable. Honored on Android 11+ (API 30+); ignored on older Android, where
  the call stays biometric-only.
* Add `getAvailableBiometrics()`, reporting which `BiometricType`s
  (`fingerprint`/`face`/`iris`) are enrolled.
* Add `stopAuthentication()` to cancel an in-progress prompt programmatically.
* Add `FlutterJkBiometricException.isLockedOutPermanently`, distinct from
  `isLockedOut`: the former means the sensor won't unlock on its own and the
  user must enter their device PIN/pattern/password first.

## 1.0.0

* Initial release: biometric-gated secret storage (`saveSecret`/`readSecret`/`hasSecret`/
  `deleteSecret`) backed by Android Keystore (`BiometricPrompt`) and iOS Keychain
  (`LocalAuthentication`).
* `checkAvailability()` reports whether the device can show a biometric prompt right now
  (`available`/`noHardware`/`notEnrolled`/`unknown`).
* Failures surface as `FlutterJkBiometricException` with `isUserCancelled`,
  `isKeyInvalidated`, `isLockedOut`, and `isNoData` flags.
