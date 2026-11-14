import 'dart:async';
import 'dart:math';

import 'package:magic/magic.dart';

import '../encryption/magic_encrypter.dart';

/// The Encryption Facade.
///
/// The `Crypt` facade provides a simple way to encrypt and decrypt strings
/// using the AES-256-CBC cipher. It proxies calls to the underlying
/// [MagicEncrypter] service resolved from the container.
///
/// > Ciphertexts are **not authenticated**: there is no MAC, unlike Laravel's
/// > `Crypt`. A payload that decrypts is not thereby proven untampered. See
/// > [MagicEncrypter] for what that rules out.
///
/// ## Config-Based Encryption
///
/// Uses the `app.key` from your configuration:
/// ```dart
/// final secret = Crypt.encrypt('my-secret-value');
/// final value = Crypt.decrypt(secret);
/// ```
///
/// ## Device-Based Encryption
///
/// Uses a device-specific key stored securely in Vault:
/// ```dart
/// final secret = await Crypt.encryptWithDeviceKey('my-secret-value');
/// final value = await Crypt.decryptWithDeviceKey(secret);
/// ```
class Crypt {
  /// The Vault key for storing the device encryption key.
  static const String _deviceKeyName = 'magic:device_encryption_key';

  /// The device encrypter, shared as one in-flight [Future].
  ///
  /// Concurrent first calls await the same creation, so Vault ends up holding
  /// the one key every caller encrypted under. A failed creation is dropped so
  /// the next call retries.
  static Future<MagicEncrypter>? _deviceEncrypter;

  /// The singleton accessor for the config-based encrypter.
  static MagicEncrypter get _service => Magic.make<MagicEncrypter>('encrypter');

  // ---------------------------------------------------------------------------
  // Config-Based Encryption (uses app.key)
  // ---------------------------------------------------------------------------

  /// Encrypt a value using the config-based app key.
  ///
  /// Example:
  /// ```dart
  /// final secret = Crypt.encrypt('my-secret-value');
  /// ```
  static String encrypt(String value) {
    return _service.encrypt(value);
  }

  /// Decrypt a value using the config-based app key.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final value = Crypt.decrypt(encryptedPayload);
  /// } on MagicDecryptException {
  ///   // Handle error...
  /// }
  /// ```
  static String decrypt(String value) {
    return _service.decrypt(value);
  }

  // ---------------------------------------------------------------------------
  // Device-Based Encryption (uses Vault-stored key)
  // ---------------------------------------------------------------------------

  /// Encrypt a value using the device-specific key.
  ///
  /// The device key is automatically generated on first use and stored
  /// securely in Vault. This key is unique to each device installation.
  ///
  /// Example:
  /// ```dart
  /// final secret = await Crypt.encryptWithDeviceKey('sensitive-data');
  /// ```
  static Future<String> encryptWithDeviceKey(String value) async {
    final encrypter = await _getDeviceEncrypter();
    return encrypter.encrypt(value);
  }

  /// Decrypt a value using the device-specific key.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final value = await Crypt.decryptWithDeviceKey(encryptedPayload);
  /// } on MagicDecryptException {
  ///   // Handle error...
  /// }
  /// ```
  static Future<String> decryptWithDeviceKey(String value) async {
    final encrypter = await _getDeviceEncrypter();
    return encrypter.decrypt(value);
  }

  /// Check if a device key exists.
  ///
  /// Returns `true` if a device encryption key has been generated.
  static Future<bool> hasDeviceKey() async {
    final key = await Vault.get(_deviceKeyName);
    return key != null;
  }

  /// Generate a new device key.
  ///
  /// This will replace any existing device key. Data encrypted with the
  /// old key will not be recoverable.
  ///
  /// > **Warning**
  /// > Calling this will invalidate all previously encrypted device data.
  static Future<void> generateDeviceKey() async {
    final newKey = _generateRandomKey();
    await Vault.put(_deviceKeyName, newKey);
    _deviceEncrypter = Future<MagicEncrypter>.value(MagicEncrypter(newKey));
  }

  /// Clear the device key.
  ///
  /// Removes the device encryption key from Vault. Data encrypted with
  /// this key will no longer be recoverable.
  static Future<void> clearDeviceKey() async {
    await Vault.delete(_deviceKeyName);
    _deviceEncrypter = null;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Get or create the device encrypter.
  static Future<MagicEncrypter> _getDeviceEncrypter() {
    final cached = _deviceEncrypter;
    if (cached != null) return cached;

    final pending = _loadDeviceEncrypter();
    _deviceEncrypter = pending;

    // A failure is not cached. The identity check leaves an encrypter that
    // generateDeviceKey() installed in the meantime alone.
    unawaited(
      pending.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_deviceEncrypter, pending)) _deviceEncrypter = null;
        },
      ),
    );

    return pending;
  }

  /// Read the device key from Vault, generating and storing it on first use.
  static Future<MagicEncrypter> _loadDeviceEncrypter() async {
    var key = await Vault.get(_deviceKeyName);

    // Generate key on first use
    if (key == null) {
      key = _generateRandomKey();
      await Vault.put(_deviceKeyName, key);
    }

    return MagicEncrypter(key);
  }

  /// Generate a cryptographically secure 32-character random key.
  static String _generateRandomKey() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
