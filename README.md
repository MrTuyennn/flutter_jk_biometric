# flutter_jk_biometric

Stores a secret string (e.g. a password) behind the device's fingerprint/Face ID sensor.

Unlike `flutter_secure_storage` — which only encrypts at rest and lets the app read the
value back anytime — every `saveSecret`/`readSecret` call here is backed by a hardware
(Keystore/Keychain) key that the OS refuses to use unless the current biometric prompt
succeeds. On Android, the key is also tied to the device's *current* biometric enrollment,
so adding or removing a fingerprint/face invalidates it — surfaced as
`FlutterJkBiometricException.keyInvalidated`.

## Usage

```dart
import 'package:flutter_jk_biometric/flutter_jk_biometric.dart';

const vault = FlutterJkBiometric();

final availability = await vault.checkAvailability();
if (availability == BiometricAvailability.available) {
  await vault.saveSecret(
    key: 'login',
    secret: 'p@ss',
    reason: 'Authenticate to save your password',
    negativeButtonText: 'Cancel',
  );

  final secret = await vault.readSecret(
    key: 'login',
    reason: 'Authenticate to read your password',
    negativeButtonText: 'Cancel',
  );
}
```

`key` namespaces multiple secrets under one vault (e.g. `'login'` vs `'withdrawal_pin'`) —
each gets its own native key/Keychain item.

## Error handling

`saveSecret`/`readSecret` throw `FlutterJkBiometricException`:

- `isUserCancelled` — the user dismissed/declined the biometric prompt.
- `isKeyInvalidated` — biometric enrollment changed since the save; drop the "biometrics
  enabled" flag and ask the user to re-enable.
- `isLockedOut` — too many failed biometric attempts; the sensor is temporarily locked.
- `isNoData` — `readSecret` was called for a `key` with nothing saved.

## Platform support

| Android | iOS |
|---------|-----|
| ✅ (Keystore + BiometricPrompt) | ✅ (Keychain + LocalAuthentication) |
