import Flutter
import LocalAuthentication
import Security
import UIKit

private let channelName = "flutter_jk_biometric"
private let keychainService = "com.jk.flutter_jk_biometric"
private let existsFlagPrefix = "com.jk.flutter_jk_biometric.exists."

public class FlutterJkBiometricPlugin: NSObject, FlutterPlugin {
  // Only one Face ID/Touch ID prompt should be on screen at a time.
  private var isAuthenticating = false
  // Tracked so stopAuthentication() can invalidate an in-flight evaluation.
  private var currentContext: LAContext?

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

    case "getAvailableBiometrics":
      result(getAvailableBiometrics())

    case "saveSecret":
      guard let key = args?["key"] as? String,
        let secret = args?["secret"] as? String,
        let reason = args?["reason"] as? String
      else {
        result(invalidArgsError())
        return
      }
      let allowDeviceCredential = args?["allowDeviceCredential"] as? Bool ?? false
      saveSecret(
        key: key, secret: secret, reason: reason, allowDeviceCredential: allowDeviceCredential,
        result: result)

    case "readSecret":
      guard let key = args?["key"] as? String,
        let reason = args?["reason"] as? String
      else {
        result(invalidArgsError())
        return
      }
      let allowDeviceCredential = args?["allowDeviceCredential"] as? Bool ?? false
      readSecret(
        key: key, reason: reason, allowDeviceCredential: allowDeviceCredential, result: result)

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

    case "stopAuthentication":
      result(stopAuthentication())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func invalidArgsError() -> FlutterError {
    FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil)
  }

  private func authInProgressError() -> FlutterError {
    FlutterError(
      code: "AUTH_IN_PROGRESS", message: "A biometric prompt is already in progress", details: nil)
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

  private func getAvailableBiometrics() -> [String] {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      return []
    }
    switch context.biometryType {
    case .faceID:
      return ["face"]
    case .touchID:
      return ["fingerprint"]
    default:
      return []
    }
  }

  private func policy(allowDeviceCredential: Bool) -> LAPolicy {
    allowDeviceCredential ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics
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

  /// Keychain writes to a biometry/passcode-protected item never trigger the
  /// prompt themselves, so we authenticate explicitly first — matching the
  /// read path, which always requires a fresh prompt.
  private func saveSecret(
    key: String, secret: String, reason: String, allowDeviceCredential: Bool,
    result: @escaping FlutterResult
  ) {
    guard !isAuthenticating else {
      result(authInProgressError())
      return
    }
    isAuthenticating = true

    let context = LAContext()
    currentContext = context
    context.evaluatePolicy(policy(allowDeviceCredential: allowDeviceCredential), localizedReason: reason) {
      success, error in
      DispatchQueue.main.async {
        self.isAuthenticating = false
        self.currentContext = nil
        guard success else {
          result(self.flutterError(forLAError: error))
          return
        }
        self.writeToKeychain(
          key: key, secret: secret, allowDeviceCredential: allowDeviceCredential, result: result)
      }
    }
  }

  private func writeToKeychain(
    key: String, secret: String, allowDeviceCredential: Bool, result: @escaping FlutterResult
  ) {
    // `.userPresence` accepts the device passcode as a fallback;
    // `.biometryCurrentSet` requires biometrics and is dropped by the OS if
    // enrollment changes (surfaced as KEY_INVALIDATED on the next read).
    let flags: SecAccessControlCreateFlags = allowDeviceCredential ? .userPresence : .biometryCurrentSet
    guard
      let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags,
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

  /// Authenticates via an explicit `LAContext` first, then passes that same
  /// (already-satisfied) context into the Keychain query via
  /// `kSecUseAuthenticationContext`. This is the supported way to control the
  /// prompt's text for a Keychain read — the alternative,
  /// `kSecUseOperationPrompt`, is deprecated since iOS 11 and in practice is
  /// ignored by Face ID on current iOS versions.
  private func readSecret(
    key: String, reason: String, allowDeviceCredential: Bool, result: @escaping FlutterResult
  ) {
    guard !isAuthenticating else {
      result(authInProgressError())
      return
    }
    guard existsFlag(key) else {
      result(
        FlutterError(code: "NO_DATA", message: "No secret saved for key \"\(key)\"", details: nil))
      return
    }

    isAuthenticating = true
    let context = LAContext()
    currentContext = context

    context.evaluatePolicy(policy(allowDeviceCredential: allowDeviceCredential), localizedReason: reason) {
      success, error in
      guard success else {
        DispatchQueue.main.async {
          self.isAuthenticating = false
          self.currentContext = nil
          result(self.flutterError(forLAError: error))
        }
        return
      }

      var query = self.baseQuery(key)
      query[kSecReturnData as String] = true
      query[kSecUseAuthenticationContext as String] = context

      DispatchQueue.global(qos: .userInitiated).async {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        DispatchQueue.main.async {
          self.isAuthenticating = false
          self.currentContext = nil
          switch status {
          case errSecSuccess:
            guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else {
              result(
                FlutterError(
                  code: "SYSTEM_ERROR", message: "Decoded secret was not valid UTF-8",
                  details: nil))
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
                code: "SYSTEM_ERROR", message: "SecItemCopyMatching failed (\(status))",
                details: nil))
          }
        }
      }
    }
  }

  private func deleteSecret(key: String) {
    SecItemDelete(baseQuery(key) as CFDictionary)
    setExistsFlag(key, false)
  }

  /// Invalidating the in-flight `LAContext` makes its `evaluatePolicy`
  /// completion handler fire immediately with `LAError.appCancel`, which the
  /// normal error path already maps to `USER_CANCELLED` — so the pending
  /// `saveSecret`/`readSecret` call still resolves instead of hanging.
  private func stopAuthentication() -> Bool {
    guard isAuthenticating, let context = currentContext else { return false }
    context.invalidate()
    currentContext = nil
    return true
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
      return FlutterError(
        code: "LOCKED_OUT_PERMANENTLY", message: laError.localizedDescription, details: nil)
    default:
      return FlutterError(code: "SYSTEM_ERROR", message: laError.localizedDescription, details: nil)
    }
  }
}
