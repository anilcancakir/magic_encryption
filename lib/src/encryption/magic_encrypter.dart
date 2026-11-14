import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pointycastle/export.dart';

import 'exceptions.dart';

/// The Magic Encrypter Service.
///
/// A convenient interface for encrypting and decrypting text with AES-256-CBC.
///
/// The wire format is fixed and shared with the payloads Magic 0.0.41 and
/// earlier wrote: AES-CBC with PKCS7 padding, the key taken as raw bytes, a
/// random 16-byte IV per call, and `base64(iv):base64(ciphertext)` with the
/// plaintext UTF-8 encoded. Changing any part of it orphans every `e:` value
/// already stored on a device.
///
/// ## What this does NOT give you
///
/// Ciphertexts produced here are **not authenticated**. There is no MAC, and
/// this is where Magic diverges from Laravel's `Encrypter`, which appends an
/// HMAC-SHA256 over the IV and the ciphertext and refuses a payload whose MAC
/// does not verify.
///
/// Two consequences to design around, rather than assume away:
///
/// - **CBC is malleable.** Someone who can modify a stored payload can flip
///   bits in the IV and flip the corresponding bits of the first plaintext
///   block, predictably. Decryption will succeed and hand back a value the
///   attacker chose part of.
/// - **A decryption failure is observable**, so a caller that reports it back
///   to whoever supplied the payload builds a padding oracle.
///
/// So: use this to keep a value opaque at rest on the device, and do not use
/// it as evidence that a value has not been tampered with. Anything whose
/// integrity matters (a token, an amount, an identity) has to be verified by
/// the server that issued it, which is the layer that can hold a secret this
/// one cannot.
class MagicEncrypter {
  /// The AES key bytes; 32 of them for AES-256.
  final Uint8List _key;

  /// Create a new encrypter instance.
  ///
  /// The [key] must be 32 bytes once UTF-8 encoded to satisfy the AES-256
  /// requirement, and those bytes are the AES key. An ASCII key of 32
  /// characters qualifies; a non-ASCII character can take several bytes. If
  /// the key is invalid, this constructor will throw an exception to prevent
  /// insecure operations.
  MagicEncrypter(String key) : _key = utf8.encode(key) {
    if (_key.length != 32) {
      throw Exception(
        'App Key must be 32 bytes of UTF-8 for AES-256 (got ${_key.length}).',
      );
    }
  }

  /// Build an encrypter from already-resolved key bytes.
  MagicEncrypter._fromKey(this._key);

  /// Build an encrypter from a Laravel-style `app.key`.
  ///
  /// Accepts either a `base64:`-prefixed key (as produced by
  /// `dart run magic:dowel key:generate`, which base64-encodes 32 random
  /// bytes) or a raw string of 32 UTF-8 bytes. Throws when the resolved key is
  /// not 32 bytes, so the generator output and the encrypter stay compatible.
  factory MagicEncrypter.fromAppKey(String appKey) {
    if (appKey.startsWith('base64:')) {
      final Uint8List bytes;
      try {
        bytes = base64.decode(appKey.substring('base64:'.length));
      } on FormatException catch (e) {
        // base64.decode throws a terse low-level FormatException; rethrow with
        // an actionable message since every app key now flows through here.
        throw Exception(
          'App Key has a "base64:" prefix but the value is not valid base64 '
          '(${e.message}). Re-run `dart run magic:dowel key:generate`.',
        );
      }
      if (bytes.length != 32) {
        throw Exception(
          'App Key must decode to 32 bytes for AES-256 (got ${bytes.length}).',
        );
      }
      return MagicEncrypter._fromKey(bytes);
    }
    return MagicEncrypter(appKey);
  }

  /// Encrypt the given value.
  ///
  /// This method generates a fresh, secure random 16-byte IV (Initialization Vector)
  /// for each operation to ensure that the same value encrypted twice produces
  /// different ciphertexts.
  ///
  /// Returns a string in the format: `base64(iv):base64(encrypted_value)`.
  /// The empty string throws a [RangeError]: there is no block to pad.
  ///
  /// [iv] pins the 16 IV bytes so tests can assert the exact payload. Production
  /// code must leave it unset: a reused IV leaks equality of plaintext prefixes.
  String encrypt(String value, {@visibleForTesting Uint8List? iv}) {
    final ivBytes = iv ?? _randomIv();
    final encrypted = _cipher(
      forEncryption: true,
      iv: ivBytes,
    ).process(utf8.encode(value));

    return '${base64.encode(ivBytes)}:${base64.encode(encrypted)}';
  }

  /// Decrypt the given payload.
  ///
  /// The [payload] must be in the format `base64(iv):base64(value)`. A
  /// malformed payload, or one that does not decrypt under this key, throws
  /// [MagicDecryptException]. Bytes that are not valid UTF-8 decode to U+FFFD
  /// rather than throwing, as the 0.0.41 implementation did.
  ///
  /// There is no MAC check, so a payload that decrypts is NOT thereby proven
  /// untampered; see the class docs. Do not surface the failure to whoever
  /// supplied the payload, since distinguishable failures are what a padding
  /// oracle is built from.
  String decrypt(String payload) {
    try {
      final parts = payload.split(':');
      if (parts.length != 2) {
        throw MagicDecryptException('Invalid payload format');
      }

      final iv = base64.decode(parts[0]);
      final encrypted = base64.decode(parts[1]);
      final decrypted = _cipher(
        forEncryption: false,
        iv: iv,
      ).process(encrypted);

      return utf8.decode(decrypted, allowMalformed: true);
    } catch (e) {
      // Catch-all on purpose: pointycastle reports a bad IV length, a partial
      // block or broken padding as ArgumentError or RangeError, not Exception.
      if (e is MagicDecryptException) rethrow;
      throw MagicDecryptException('Decryption failed: ${e.toString()}');
    }
  }

  /// A fresh AES-CBC cipher with PKCS7 padding, initialised for one call.
  PaddedBlockCipher _cipher({
    required bool forEncryption,
    required Uint8List iv,
  }) {
    return PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        forEncryption,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV<KeyParameter>(KeyParameter(_key), iv),
          null,
        ),
      );
  }

  /// 16 bytes from the platform's secure random source.
  static Uint8List _randomIv() {
    final random = Random.secure();

    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }
}
