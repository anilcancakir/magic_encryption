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
  /// the one key every caller encrypted under. [generateDeviceKey] and
  /// [clearDeviceKey] queue behind it, so the last Vault write is also the
  /// last cache write. A failed step is dropped so the next call retries, and
  /// a cleared key resolves to `null`.
  static Future<MagicEncrypter?>? _deviceEncrypter;

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
  static Future<void> generateDeviceKey() {
    final newKey = _generateRandomKey();

    return _changeDeviceKey(() async {
      await Vault.put(_deviceKeyName, newKey);
      return MagicEncrypter(newKey);
    });
  }

  /// Clear the device key.
  ///
  /// Removes the device encryption key from Vault. Data encrypted with
  /// this key will no longer be recoverable.
  static Future<void> clearDeviceKey() {
    return _changeDeviceKey(() async {
      await Vault.delete(_deviceKeyName);
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Run a Vault write behind whatever device-key work is already in flight.
  ///
  /// The cache is assigned synchronously, so a later call queues behind this
  /// change instead of racing it. The previous work's outcome is ignored here:
  /// its own callers already see its error. A [change] that returns `null`
  /// leaves no encrypter cached.
  static Future<void> _changeDeviceKey(
    Future<MagicEncrypter?> Function() change,
  ) {
    final previous = _deviceEncrypter;
    final next = _afterPrevious(previous, change);
    _deviceEncrypter = next;

    return next.then<void>(
      (encrypter) {
        if (encrypter == null && identical(_deviceEncrypter, next)) {
          _deviceEncrypter = null;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_deviceEncrypter, next)) _deviceEncrypter = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  /// Wait for [previous] to settle, then run [change].
  static Future<MagicEncrypter?> _afterPrevious(
    Future<MagicEncrypter?>? previous,
    Future<MagicEncrypter?> Function() change,
  ) async {
    await previous?.then<void>((_) {}, onError: (Object _) {});

    return change();
  }

  /// Get or create the device encrypter.
  static Future<MagicEncrypter> _getDeviceEncrypter() async {
    final cached = _deviceEncrypter;
    if (cached == null) return _createDeviceEncrypter();

    // A cleared key resolves to null: start over against the empty Vault.
    return await cached ?? _getDeviceEncrypter();
  }

  /// Start the one shared creation and cache it until it settles.
  static Future<MagicEncrypter> _createDeviceEncrypter() {
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
