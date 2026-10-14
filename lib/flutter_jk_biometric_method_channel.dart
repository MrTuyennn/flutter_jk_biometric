import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_jk_biometric_platform_interface.dart';
import 'src/biometric_availability.dart';
import 'src/flutter_jk_biometric_exception.dart';

class MethodChannelFlutterJkBiometric extends FlutterJkBiometricPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_jk_biometric');

  @override
  Future<BiometricAvailability> checkAvailability() async {
    final raw = await methodChannel.invokeMethod<String>('checkAvailability');
    return BiometricAvailability.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => BiometricAvailability.unknown,
    );
  }

  @override
  Future<void> saveSecret({
    required String key,
    required String secret,
    required String reason,
    required String negativeButtonText,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('saveSecret', {
        'key': key,
        'secret': secret,
        'reason': reason,
        'negativeButtonText': negativeButtonText,
      });
    } on PlatformException catch (e) {
      throw FlutterJkBiometricException(
        e.code,
        e.message ?? 'saveSecret failed',
      );
    }
  }

  @override
  Future<String> readSecret({
    required String key,
    required String reason,
    required String negativeButtonText,
  }) async {
    try {
      final secret = await methodChannel.invokeMethod<String>('readSecret', {
        'key': key,
        'reason': reason,
        'negativeButtonText': negativeButtonText,
      });
      if (secret == null) {
        throw const FlutterJkBiometricException(
          FlutterJkBiometricException.noData,
          'Native side returned null without throwing',
        );
      }
      return secret;
    } on PlatformException catch (e) {
      throw FlutterJkBiometricException(
        e.code,
        e.message ?? 'readSecret failed',
      );
    }
  }

  @override
  Future<bool> hasSecret({required String key}) async {
    final result = await methodChannel.invokeMethod<bool>('hasSecret', {
      'key': key,
    });
    return result ?? false;
  }

  @override
  Future<void> deleteSecret({required String key}) async {
    await methodChannel.invokeMethod<void>('deleteSecret', {'key': key});
  }
}
