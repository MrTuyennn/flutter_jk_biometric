import 'flutter_jk_biometric_platform_interface.dart';
import 'src/biometric_availability.dart';
import 'src/biometric_type.dart';

export 'src/biometric_availability.dart';
export 'src/biometric_type.dart';
export 'src/flutter_jk_biometric_exception.dart';

/// Stores a secret behind the device's biometric sensor, backed by a
/// hardware Keystore/Keychain key.
class FlutterJkBiometric {
  const FlutterJkBiometric();

  /// Whether a biometric prompt can be shown right now.
  Future<BiometricAvailability> checkAvailability() =>
      FlutterJkBiometricPlatform.instance.checkAvailability();

  /// Which biometric sensor types (fingerprint/face/iris) are enrolled.
  Future<List<BiometricType>> getAvailableBiometrics() =>
      FlutterJkBiometricPlatform.instance.getAvailableBiometrics();

  /// Prompts for biometric auth, then encrypts and stores [secret] under
  /// [key]. Set [allowDeviceCredential] to also accept the device
  /// PIN/pattern/password as a fallback.
  Future<void> saveSecret({
    required String key,
    required String secret,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) => FlutterJkBiometricPlatform.instance.saveSecret(
    key: key,
    secret: secret,
    reason: reason,
    negativeButtonText: negativeButtonText,
    allowDeviceCredential: allowDeviceCredential,
  );

  /// Prompts for biometric auth, then decrypts and returns the secret saved
  /// under [key]. Set [allowDeviceCredential] to also accept the device
  /// PIN/pattern/password as a fallback.
  Future<String> readSecret({
    required String key,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) => FlutterJkBiometricPlatform.instance.readSecret(
    key: key,
    reason: reason,
    negativeButtonText: negativeButtonText,
    allowDeviceCredential: allowDeviceCredential,
  );

  /// Whether a secret is currently saved under [key].
  Future<bool> hasSecret({required String key}) =>
      FlutterJkBiometricPlatform.instance.hasSecret(key: key);

  /// Deletes the secret saved under [key].
  Future<void> deleteSecret({required String key}) =>
      FlutterJkBiometricPlatform.instance.deleteSecret(key: key);

  /// Cancels an in-progress [saveSecret]/[readSecret] prompt. Returns `true`
  /// if one was actually cancelled.
  Future<bool> stopAuthentication() =>
      FlutterJkBiometricPlatform.instance.stopAuthentication();
}
