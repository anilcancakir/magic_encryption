import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_encryption/magic_encryption.dart';

import 'golden_payloads.dart';

/// Pins the wire format byte for byte, so a change of cipher backend cannot
/// silently orphan `e:` ciphertext already written to disk.
///
/// Every payload here is a committed literal from `golden_payloads.dart`; none
/// is recomputed from the code under test.
void main() {
  group('golden payloads', () {
    for (final golden in goldenCases) {
      group(golden.name, () {
        test('decrypts to the recorded plaintext', () {
          final encrypter = MagicEncrypter.fromAppKey(golden.key);

          expect(encrypter.decrypt(golden.payload), golden.plaintext);
        });

        test('encrypts to the recorded payload under the recorded IV', () {
          final encrypter = MagicEncrypter.fromAppKey(golden.key);

          expect(
            encrypter.encrypt(golden.plaintext, iv: base64.decode(golden.iv)),
            golden.payload,
          );
        });
      });
    }
  });

  group('encrypt', () {
    final encrypter = MagicEncrypter.fromAppKey(goldenRawKey);

    test('uses a fresh random IV by default', () {
      final first = encrypter.encrypt('same');
      final second = encrypter.encrypt('same');

      expect(first, isNot(second));
      expect(base64.decode(first.split(':').first), hasLength(16));
    });

    test('refuses the empty string with a RangeError', () {
      expect(() => encrypter.encrypt(''), throwsRangeError);
    });
  });

  group('decrypt refuses a malformed payload', () {
    final encrypter = MagicEncrypter.fromAppKey(goldenRawKey);

    test('empty payload', () {
      expect(
        () => encrypter.decrypt(malformedEmptyPayload),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('empty ciphertext', () {
      expect(
        () => encrypter.decrypt(malformedEmptyCiphertext),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('ciphertext that is not a whole number of blocks (15 bytes)', () {
      expect(
        () => encrypter.decrypt(malformedShortCiphertext),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('IV that is not 16 bytes (8 bytes)', () {
      expect(
        () => encrypter.decrypt(malformedShortIv),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('invalid PKCS7 padding', () {
      expect(
        () => encrypter.decrypt(malformedBadPadding),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('invalid base64', () {
      expect(
        () => encrypter.decrypt(malformedBadBase64),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('three colon-separated parts', () {
      expect(
        () => encrypter.decrypt(malformedThreeParts),
        throwsA(isA<MagicDecryptException>()),
      );
    });
  });
}
