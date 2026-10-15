# flutter_jk_biometric

[![pub package](https://img.shields.io/pub/v/flutter_jk_biometric.svg)](https://pub.dev/packages/flutter_jk_biometric)

Stores a secret string (e.g. a password) behind the device's fingerprint/Face ID sensor.

Unlike `flutter_secure_storage` — which only encrypts at rest and lets the app read the
value back anytime — every `saveSecret`/`readSecret` call here is backed by a hardware
(Keystore on Android, Keychain on iOS) key that the OS refuses to use unless the current
biometric prompt succeeds. On Android, the key is also tied to the device's *current*
biometric enrollment, so adding or removing a fingerprint/face invalidates it — surfaced
as `FlutterJkBiometricException.keyInvalidated`.

## Platform support

| Android | iOS |
|---------|-----|
| ✅ minSdk 24, Keystore + `BiometricPrompt` | ✅ iOS 15+, Keychain + `LocalAuthentication` |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_jk_biometric: ^1.0.1
```

Or, until it's published on pub.dev, point straight at the GitHub repo:

```yaml
dependencies:
  flutter_jk_biometric:
    git:
      url: https://github.com/MrTuyennn/flutter_jk_biometric.git
```

Then run:

```sh
flutter pub get
```

### Android setup

The biometric prompt (`BiometricPrompt`) needs a `FragmentActivity` host. If your
`MainActivity` extends `FlutterActivity`, change it to `FlutterFragmentActivity`:

```kotlin
package com.example.app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

The `android.permission.USE_BIOMETRIC` permission is already declared by this plugin and
merges into your app automatically — no manifest changes needed. Minimum `minSdk` is 24.

### iOS setup

Add a `NSFaceIDUsageDescription` entry to `ios/Runner/Info.plist` (required or Face ID
silently fails):

```xml
<key>NSFaceIDUsageDescription</key>
<string>Face ID is used to protect your saved secrets.</string>
```

## Usage

```dart
import 'package:flutter_jk_biometric/flutter_jk_biometric.dart';

const vault = FlutterJkBiometric();

// 1. Check whether the device can show a biometric prompt right now.
final availability = await vault.checkAvailability();
if (availability == BiometricAvailability.available) {
  // 2. Save a secret — prompts for biometric auth, then encrypts and stores it.
  await vault.saveSecret(
    key: 'login',
    secret: 'p@ss',
    reason: 'Authenticate to save your password',
    negativeButtonText: 'Cancel',
  );

  // 3. Read it back — prompts again, then decrypts.
  final secret = await vault.readSecret(
    key: 'login',
    reason: 'Authenticate to read your password',
    negativeButtonText: 'Cancel',
  );

  // 4. Check whether something is saved, without showing a prompt.
  final saved = await vault.hasSecret(key: 'login');

  // 5. Delete it — also without a prompt.
  await vault.deleteSecret(key: 'login');
}
```

`key` namespaces multiple secrets under one vault (e.g. `'login'` vs `'withdrawal_pin'`) —
each gets its own native Keystore/Keychain item. It's an identifier, not a secret itself:
it's stored unencrypted (as the Keystore alias / `SharedPreferences` entry name on
Android, and as the Keychain account attribute on iOS) — don't put sensitive data in it.

`negativeButtonText` only applies on **Android**, and only when `allowDeviceCredential`
is `false` (it labels the cancel button on `BiometricPrompt`; Android forbids a custom
negative button once the device PIN/pattern/password fallback is enabled, since the
system supplies its own "use PIN" affordance instead). iOS's Face ID/Touch ID dialog has
its own system-provided cancel button and ignores this value — pass a localized string
regardless, since Android still needs it.

### Checking availability

`BiometricAvailability` has four values:

- `available` — hardware present and at least one biometric enrolled.
- `noHardware` — no biometric sensor on this device (or it's permanently disabled).
- `notEnrolled` — hardware present but nothing enrolled yet; send the user to OS settings.
- `unknown` — the platform returned something this plugin doesn't recognize.

Call `getAvailableBiometrics()` to find out *which* sensor is enrolled, for adaptive UI
(e.g. showing a Face ID vs. fingerprint icon):

```dart
final types = await vault.getAvailableBiometrics(); // e.g. [BiometricType.face]
```

### Falling back to the device PIN/pattern/password

Pass `allowDeviceCredential: true` to `saveSecret`/`readSecret` to let the user
authenticate with their device credential when biometrics aren't usable (not enrolled,
sensor dirty, etc.) instead of only ever offering biometrics:

```dart
await vault.saveSecret(
  key: 'login',
  secret: 'p@ss',
  reason: 'Authenticate to save your password',
  negativeButtonText: 'Cancel',
  allowDeviceCredential: true,
);
```

This is only honored on **Android 11+ (API 30+)**; on older Android it's ignored and the
call stays biometric-only, since combining the device credential fallback with the
hardware-backed crypto key isn't supported by the platform below that version.

### Cancelling a prompt

```dart
final cancelled = await vault.stopAuthentication(); // true if a prompt was showing
```

### Error handling

`saveSecret`/`readSecret` throw `FlutterJkBiometricException`:

```dart
try {
  await vault.readSecret(
    key: 'login',
    reason: 'Authenticate to read your password',
    negativeButtonText: 'Cancel',
  );
} on FlutterJkBiometricException catch (e) {
  if (e.isUserCancelled) {
    // User dismissed/declined the prompt.
  } else if (e.isKeyInvalidated) {
    // Biometric enrollment changed since the save — drop your "biometrics
    // enabled" flag and ask the user to re-enable.
  } else if (e.isLockedOut) {
    // Too many failed attempts — sensor temporarily locked, try again shortly.
  } else if (e.isLockedOutPermanently) {
    // Won't clear on its own — the user must unlock with their device
    // PIN/pattern/password first.
  } else if (e.isNoData) {
    // readSecret was called for a key with nothing saved.
  } else if (e.isAuthInProgress) {
    // Another saveSecret/readSecret call already has a prompt showing.
  }
}
```

## Example

See [`example/`](example) for a complete runnable app exercising every method.

## License

[MIT](LICENSE)
