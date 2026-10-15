import 'package:flutter_jk_biometric/flutter_jk_biometric.dart';
import 'package:flutter_jk_biometric/flutter_jk_biometric_method_channel.dart';
import 'package:flutter_jk_biometric/flutter_jk_biometric_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterJkBiometricPlatform
    with MockPlatformInterfaceMixin
    implements FlutterJkBiometricPlatform {
  BiometricAvailability availability = BiometricAvailability.available;
  List<BiometricType> availableBiometrics = [BiometricType.fingerprint];
  bool hasSecretResult = false;
  bool stopAuthenticationResult = false;
  String? savedSecret;
  final List<String> calls = [];

  @override
  Future<BiometricAvailability> checkAvailability() async => availability;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      availableBiometrics;

  @override
  Future<void> saveSecret({
    required String key,
    required String secret,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) async {
    calls.add('saveSecret');
    savedSecret = secret;
  }

  @override
  Future<String> readSecret({
    required String key,
    required String reason,
    required String negativeButtonText,
    bool allowDeviceCredential = false,
  }) async {
    calls.add('readSecret');
    return savedSecret ??
        (throw const FlutterJkBiometricException(
          FlutterJkBiometricException.noData,
          'no secret',
        ));
  }

  @override
  Future<bool> hasSecret({required String key}) async => hasSecretResult;

  @override
  Future<void> deleteSecret({required String key}) async {
    calls.add('deleteSecret');
    savedSecret = null;
  }

  @override
  Future<bool> stopAuthentication() async {
    calls.add('stopAuthentication');
    return stopAuthenticationResult;
  }
}

void main() {
  final FlutterJkBiometricPlatform initialPlatform =
      FlutterJkBiometricPlatform.instance;

  test('$MethodChannelFlutterJkBiometric is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterJkBiometric>());
  });

  test('FlutterJkBiometric delegates to the current platform instance', () async {
    final fakePlatform = MockFlutterJkBiometricPlatform();
    FlutterJkBiometricPlatform.instance = fakePlatform;
    const vault = FlutterJkBiometric();

    expect(await vault.checkAvailability(), BiometricAvailability.available);
    expect(await vault.getAvailableBiometrics(), [BiometricType.fingerprint]);

    await vault.saveSecret(
      key: 'login',
      secret: 'p@ss',
      reason: 'Xác thực',
      negativeButtonText: 'Hủy',
    );
    expect(
      await vault.readSecret(
        key: 'login',
        reason: 'Xác thực',
        negativeButtonText: 'Hủy',
      ),
      'p@ss',
    );

    fakePlatform.hasSecretResult = true;
    expect(await vault.hasSecret(key: 'login'), isTrue);

    await vault.deleteSecret(key: 'login');

    fakePlatform.stopAuthenticationResult = true;
    expect(await vault.stopAuthentication(), isTrue);

    expect(fakePlatform.calls, [
      'saveSecret',
      'readSecret',
      'deleteSecret',
      'stopAuthentication',
    ]);
  });
}
