import Flutter
import LocalAuthentication
import Security
import UIKit

private let channelName = "flutter_jk_biometric"
private let keychainService = "com.jk.flutter_jk_biometric"
private let existsFlagPrefix = "com.jk.flutter_jk_biometric.exists."

public class FlutterJkBiometricPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = FlutterJkBiometricPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "checkAvailability":
      result(checkAvailability())

    case "saveSecret":
      guard let key = args?["key"] as? String,
        let secret = args?["secret"] as? String,
        let reason = args?["reason"] as? String
      else {
        result(invalidArgsError())
        return
      }
      saveSecret(key: key, secret: secret, reason: reason, result: result)

    case "readSecret":
      guard let key = args?["key"] as? String,
        let reason = args?["reason"] as? String
      else {
        result(invalidArgsError())
        return
      }
      readSecret(key: key, reason: reason, result: result)

    case "hasSecret":
      guard let key = args?["key"] as? String else {
        result(invalidArgsError())
        return
      }
      result(existsFlag(key))

    case "deleteSecret":
      guard let key = args?["key"] as? String else {
        result(invalidArgsError())
        return
      }
      deleteSecret(key: key)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func invalidArgsError() -> FlutterError {
    FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil)
  }

  private func checkAvailability() -> String {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      return "available"
    }
    switch (error as? LAError)?.code {
    case .biometryNotAvailable:
      return "noHardware"
    case .biometryNotEnrolled:
      return "notEnrolled"
    default:
      return "unknown"
    }
  }

  private func existsFlagKey(_ key: String) -> String { existsFlagPrefix + key }

  private func existsFlag(_ key: String) -> Bool {
    UserDefaults.standard.bool(forKey: existsFlagKey(key))
  }

  private func setExistsFlag(_ key: String, _ value: Bool) {
    UserDefaults.standard.set(value, forKey: existsFlagKey(key))
  }

  private func baseQuery(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: key,
    ]
  }

  /// Keychain writes to a `biometryCurrentSet`-protected item never trigger
  /// Face ID themselves, so we authenticate explicitly first — matching the
  /// read path, which always requires a fresh prompt.
  private func saveSecret(
    key: String, secret: String, reason: String, result: @escaping FlutterResult
  ) {
    let context = LAContext()
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
      success, error in
      DispatchQueue.main.async {
        guard success else {
          result(self.flutterError(forLAError: error))
          return
        }
        self.writeToKeychain(key: key, secret: secret, result: result)
      }
    }
  }

  private func writeToKeychain(key: String, secret: String, result: @escaping FlutterResult) {
    guard
      let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .biometryCurrentSet,
        nil
      )
    else {
      result(
        FlutterError(
          code: "SYSTEM_ERROR", message: "Could not create SecAccessControl", details: nil))
      return
    }

    // Access-control attributes can't be updated in place — drop any
    // previous item for this key before re-adding.
    SecItemDelete(baseQuery(key) as CFDictionary)

    var addQuery = baseQuery(key)
    addQuery[kSecValueData as String] = secret.data(using: .utf8)
    addQuery[kSecAttrAccessControl as String] = accessControl

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    if status == errSecSuccess {
      setExistsFlag(key, true)
      result(nil)
    } else {
      result(
        FlutterError(code: "SYSTEM_ERROR", message: "SecItemAdd failed (\(status))", details: nil))
    }
  }

  private func readSecret(key: String, reason: String, result: @escaping FlutterResult) {
    guard existsFlag(key) else {
      result(
        FlutterError(code: "NO_DATA", message: "No secret saved for key \"\(key)\"", details: nil))
      return
    }

    var query = baseQuery(key)
    query[kSecReturnData as String] = true
    // Deprecated since iOS 11 but still the only way to customize the
    // Face ID/Touch ID prompt text for a Keychain-triggered read — there is
    // no LAContext-based replacement for this specific case.
    query[kSecUseOperationPrompt as String] = reason

    DispatchQueue.global(qos: .userInitiated).async {
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      DispatchQueue.main.async {
        switch status {
        case errSecSuccess:
          guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
            result(
              FlutterError(
                code: "SYSTEM_ERROR", message: "Decoded secret was not valid UTF-8", details: nil))
            return
          }
          result(secret)

        case errSecItemNotFound:
          // We believed it existed but the Keychain disagrees — biometric
          // enrollment changed and iOS dropped the protected item.
          self.deleteSecret(key: key)
          result(
            FlutterError(
              code: "KEY_INVALIDATED",
              message: "Biometric enrollment changed, vault entry invalidated",
              details: nil
            ))

        case errSecUserCanceled:
          result(
            FlutterError(
              code: "USER_CANCELLED", message: "User cancelled biometric prompt", details: nil))

        default:
          result(
            FlutterError(
              code: "SYSTEM_ERROR", message: "SecItemCopyMatching failed (\(status))", details: nil)
          )
        }
      }
    }
  }

  private func deleteSecret(key: String) {
    SecItemDelete(baseQuery(key) as CFDictionary)
    setExistsFlag(key, false)
  }

  private func flutterError(forLAError error: Error?) -> FlutterError {
    guard let laError = error as? LAError else {
      return FlutterError(code: "SYSTEM_ERROR", message: error?.localizedDescription, details: nil)
    }
    switch laError.code {
    case .userCancel, .appCancel, .systemCancel:
      return FlutterError(
        code: "USER_CANCELLED", message: laError.localizedDescription, details: nil)
    case .biometryLockout:
      return FlutterError(code: "LOCKED_OUT", message: laError.localizedDescription, details: nil)
    default:
      return FlutterError(code: "SYSTEM_ERROR", message: laError.localizedDescription, details: nil)
    }
  }
}
