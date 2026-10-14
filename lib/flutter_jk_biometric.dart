import 'flutter_jk_biometric_platform_interface.dart';
import 'src/biometric_availability.dart';

export 'src/biometric_availability.dart';
export 'src/flutter_jk_biometric_exception.dart';

class FlutterJkBiometric {
  const FlutterJkBiometric();

  /// Whether a biometric prompt can be shown right now.
  Future<BiometricAvailability> checkAvailability() =>
      FlutterJkBiometricPlatform.instance.checkAvailability();

  /// Prompts for biometric auth, then encrypts and stores [secret] under
  /// [key].
  Future<void> saveSecret({
    required String key,
    required String secret,
    required String reason,
    required String negativeButtonText,
  }) => FlutterJkBiometricPlatform.instance.saveSecret(
    key: key,
    secret: secret,
    reason: reason,
    negativeButtonText: negativeButtonText,
  );

  /// Prompts for biometric auth, then decrypts and returns the secret saved
  /// under [key].
  Future<String> readSecret({
    required String key,
    required String reason,
    required String negativeButtonText,
  }) => FlutterJkBiometricPlatform.instance.readSecret(
    key: key,
    reason: reason,
    negativeButtonText: negativeButtonText,
  );

  /// Whether a secret is currently saved under [key].
  Future<bool> hasSecret({required String key}) =>
      FlutterJkBiometricPlatform.instance.hasSecret(key: key);

  /// Deletes the secret saved under [key].
  Future<void> deleteSecret({required String key}) =>
      FlutterJkBiometricPlatform.instance.deleteSecret(key: key);
}
