import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_jk_biometric_method_channel.dart';
import 'src/biometric_availability.dart';
import 'src/biometric_type.dart';

abstract class FlutterJkBiometricPlatform extends PlatformInterface {
  /// Constructs a FlutterJkBiometricPlatform.
  FlutterJkBiometricPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterJkBiometricPlatform _instance = MethodChannelFlutterJkBiometric();

  /// The default instance of [FlutterJkBiometricPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterJkBiometric].
  static FlutterJkBiometricPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterJkBiometricPlatform] when
  /// they register themselves.
  static set instance(FlutterJkBiometricPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<BiometricAvailability> checkAvailability() {
    throw UnimplementedError('checkAvailability() has not been implemented.');
  }

  Future<List<BiometricType>> getAvailableBiometrics() {
    throw UnimplementedError(
      'getAvailableBiometrics() has not been implemented.',
    );
  }

  Future<void> saveSecret({
    required String key,
    required String secret,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) {
    throw UnimplementedError('saveSecret() has not been implemented.');
  }

  Future<String> readSecret({
    required String key,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) {
    throw UnimplementedError('readSecret() has not been implemented.');
  }

  Future<bool> hasSecret({required String key}) {
    throw UnimplementedError('hasSecret() has not been implemented.');
  }

  Future<void> deleteSecret({required String key}) {
    throw UnimplementedError('deleteSecret() has not been implemented.');
  }

  Future<bool> stopAuthentication() {
    throw UnimplementedError('stopAuthentication() has not been implemented.');
  }
}
