import 'package:flutter_jk_biometric/flutter_jk_biometric.dart';
import 'package:flutter_jk_biometric/flutter_jk_biometric_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterJkBiometric();
  const channel = MethodChannel('flutter_jk_biometric');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('checkAvailability maps the native string to the enum', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'notEnrolled');

    expect(
      await platform.checkAvailability(),
      BiometricAvailability.notEnrolled,
    );
  });

  test(
    'checkAvailability falls back to unknown for an unrecognized value',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'something_new');

      expect(await platform.checkAvailability(), BiometricAvailability.unknown);
    },
  );

  test('saveSecret forwards the arguments as-is', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return null;
        });

    await platform.saveSecret(
      key: 'login',
      secret: 'p@ss',
      reason: 'Xác thực',
      negativeButtonText: 'Hủy',
    );

    expect(captured?.method, 'saveSecret');
    expect(captured?.arguments, {
      'key': 'login',
      'secret': 'p@ss',
      'reason': 'Xác thực',
      'negativeButtonText': 'Hủy',
      'allowDeviceCredential': false,
    });
  });

  test('saveSecret forwards allowDeviceCredential when set', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return null;
        });

    await platform.saveSecret(
      key: 'login',
      secret: 'p@ss',
      reason: 'Xác thực',
      negativeButtonText: 'Hủy',
      allowDeviceCredential: true,
    );

    expect(captured?.arguments['allowDeviceCredential'], isTrue);
  });

  test(
    'readSecret rethrows a PlatformException as a FlutterJkBiometricException',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: FlutterJkBiometricException.userCancelled,
              message: 'cancelled',
            );
          });

      await expectLater(
        platform.readSecret(
          key: 'login',
          reason: 'Xác thực',
          negativeButtonText: 'Hủy',
        ),
        throwsA(
          isA<FlutterJkBiometricException>().having(
            (e) => e.isUserCancelled,
            'isUserCancelled',
            isTrue,
          ),
        ),
      );
    },
  );

  test('hasSecret defaults to false when the platform returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await platform.hasSecret(key: 'login'), isFalse);
  });

  test('getAvailableBiometrics maps native strings to the enum', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => ['fingerprint', 'something_new'],
        );

    expect(await platform.getAvailableBiometrics(), [
      BiometricType.fingerprint,
      BiometricType.unknown,
    ]);
  });

  test('stopAuthentication defaults to false when the platform returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await platform.stopAuthentication(), isFalse);
  });
}
