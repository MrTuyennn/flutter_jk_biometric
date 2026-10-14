package com.jk.flutter_jk_biometric

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val CHANNEL_NAME = "flutter_jk_biometric"
private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
private const val KEY_ALIAS_PREFIX = "com.jk.flutter_jk_biometric."
private const val PREFS_NAME = "com.jk.flutter_jk_biometric.prefs"
private const val GCM_TAG_LENGTH_BITS = 128

class FlutterJkBiometricPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    private var activity: FragmentActivity? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkAvailability" -> result.success(checkAvailability().name)
            "saveSecret" -> saveSecret(call, result)
            "readSecret" -> readSecret(call, result)
            "hasSecret" -> result.success(hasSecret(call.requireArg("key")))
            "deleteSecret" -> {
                deleteSecret(call.requireArg("key"))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun MethodCall.requireArg(name: String): String =
        argument<String>(name) ?: throw IllegalArgumentException("Missing required arg \"$name\"")

    private enum class Availability { available, noHardware, notEnrolled, unknown }

    private fun checkAvailability(): Availability {
        val manager = BiometricManager.from(applicationContext)
        return when (manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> Availability.available
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED,
            -> Availability.noHardware
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> Availability.notEnrolled
            else -> Availability.unknown
        }
    }

    private fun prefs(): SharedPreferences =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    private fun aliasFor(key: String) = "$KEY_ALIAS_PREFIX$key"

    private fun ciphertextPrefKey(key: String) = "$key.ciphertext"

    private fun ivPrefKey(key: String) = "$key.iv"

    private fun hasSecret(key: String): Boolean = prefs().contains(ciphertextPrefKey(key))

    private fun deleteSecret(key: String) {
        runCatching { keyStore().deleteEntry(aliasFor(key)) }
        prefs().edit()
            .remove(ciphertextPrefKey(key))
            .remove(ivPrefKey(key))
            .apply()
    }

    /** Creates the key on first use; returns the existing one otherwise. */
    private fun getOrCreateSecretKey(alias: String): SecretKey {
        (keyStore().getKey(alias, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        val specBuilder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            specBuilder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            specBuilder.setUserAuthenticationValidityDurationSeconds(-1)
            @Suppress("DEPRECATION")
            specBuilder.setInvalidatedByBiometricEnrollment(true)
        }

        generator.init(specBuilder.build())
        return generator.generateKey()
    }

    private fun saveSecret(call: MethodCall, result: Result) {
        val key = call.requireArg("key")
        val secret = call.requireArg("secret")
        val reason = call.requireArg("reason")
        val negativeButtonText = call.requireArg("negativeButtonText")
        val host = activity ?: return result.error(
            "NO_ACTIVITY",
            "No foreground activity to show the biometric prompt",
            null,
        )

        val cipher = try {
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey(aliasFor(key)))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            deleteSecret(key)
            return result.error("KEY_INVALIDATED", e.message, null)
        } catch (e: Exception) {
            return result.error("SYSTEM_ERROR", e.message, null)
        }

        authenticate(
            host = host,
            reason = reason,
            negativeButtonText = negativeButtonText,
            cryptoObject = BiometricPrompt.CryptoObject(cipher),
            onSuccess = { authenticatedCipher ->
                try {
                    val encrypted = authenticatedCipher.doFinal(secret.toByteArray(Charsets.UTF_8))
                    prefs().edit()
                        .putString(ciphertextPrefKey(key), encrypted.toBase64())
                        .putString(ivPrefKey(key), authenticatedCipher.iv.toBase64())
                        .apply()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SYSTEM_ERROR", e.message, null)
                }
            },
            onError = { code, message -> result.error(code, message, null) },
        )
    }

    private fun readSecret(call: MethodCall, result: Result) {
        val key = call.requireArg("key")
        val reason = call.requireArg("reason")
        val negativeButtonText = call.requireArg("negativeButtonText")

        val ciphertextB64 = prefs().getString(ciphertextPrefKey(key), null)
        val ivB64 = prefs().getString(ivPrefKey(key), null)
        if (ciphertextB64 == null || ivB64 == null) {
            return result.error("NO_DATA", "No secret saved for key \"$key\"", null)
        }

        val host = activity ?: return result.error(
            "NO_ACTIVITY",
            "No foreground activity to show the biometric prompt",
            null,
        )

        val cipher = try {
            val secretKey = keyStore().getKey(aliasFor(key), null) as? SecretKey
                ?: throw KeyPermanentlyInvalidatedException("Vault key for \"$key\" is missing")
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_LENGTH_BITS, ivB64.fromBase64()))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            deleteSecret(key)
            return result.error("KEY_INVALIDATED", e.message, null)
        } catch (e: Exception) {
            return result.error("SYSTEM_ERROR", e.message, null)
        }

        authenticate(
            host = host,
            reason = reason,
            negativeButtonText = negativeButtonText,
            cryptoObject = BiometricPrompt.CryptoObject(cipher),
            onSuccess = { authenticatedCipher ->
                try {
                    val plaintext = authenticatedCipher.doFinal(ciphertextB64.fromBase64())
                    result.success(String(plaintext, Charsets.UTF_8))
                } catch (e: Exception) {
                    result.error("SYSTEM_ERROR", e.message, null)
                }
            },
            onError = { code, message -> result.error(code, message, null) },
        )
    }

    private fun authenticate(
        host: FragmentActivity,
        reason: String,
        negativeButtonText: String,
        cryptoObject: BiometricPrompt.CryptoObject,
        onSuccess: (Cipher) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        val prompt = BiometricPrompt(
            host,
            ContextCompat.getMainExecutor(applicationContext),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    val cipher = result.cryptoObject?.cipher
                    if (cipher == null) {
                        onError("SYSTEM_ERROR", "Missing crypto object after authentication")
                    } else {
                        onSuccess(cipher)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val code = when (errorCode) {
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_CANCELED,
                        -> "USER_CANCELLED"
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT,
                        -> "LOCKED_OUT"
                        else -> "SYSTEM_ERROR"
                    }
                    onError(code, errString.toString())
                }

                // A single failed biometric read (e.g. finger not recognized) isn't
                // terminal — androidx.biometric keeps the prompt open for a retry.
                override fun onAuthenticationFailed() = Unit
            },
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(reason)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText(negativeButtonText)
            .build()

        prompt.authenticate(promptInfo, cryptoObject)
    }

    private fun ByteArray.toBase64(): String = Base64.encodeToString(this, Base64.NO_WRAP)

    private fun String.fromBase64(): ByteArray = Base64.decode(this, Base64.NO_WRAP)
}
