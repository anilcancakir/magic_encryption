# Wire Format

The exact bytes `Crypt` and `MagicEncrypter` write, what they do not guarantee and how they differ from Laravel's `Crypt`.

- [Quick Reference](#quick-reference)
- [Reading a Payload](#reading-a-payload)
- [Not Authenticated](#not-authenticated)
- [Not Laravel](#not-laravel)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="quick-reference"></a>
## Quick Reference

| Part | Value |
|:-----|:------|
| Cipher | AES-256 in CBC mode with PKCS7 padding |
| Key | 32 bytes: the UTF-8 bytes of a 32-character string, or the decoded bytes of a `base64:` key |
| IV | 16 random bytes per call from a secure random source |
| Plaintext | The string, UTF-8 encoded |
| Payload | `base64(iv):base64(ciphertext)`, standard base64 with padding, one colon |

The format is fixed. It is the one Magic 0.0.41 and earlier wrote, so changing any part orphans every stored value.

<a name="reading-a-payload"></a>
## Reading a Payload

`MagicEncrypter` is the cipher behind both modes. Build one directly when you hold a key that is not `app.key`:

```dart
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  final MagicEncrypter encrypter = MagicEncrypter('0123456789abcdef0123456789abcdef');

  final String payload = encrypter.encrypt('hello');
  final List<String> parts = payload.split(':');

  print(parts.length); // 2: the base64 IV, then the base64 ciphertext
  print(encrypter.decrypt(payload)); // hello
}
```

`MagicEncrypter(String key)` throws an `Exception` unless the key is 32 characters. `MagicEncrypter.fromAppKey(String)` also accepts a `base64:` key and throws unless it decodes to 32 bytes. `decrypt` splits on `:`, base64-decodes both halves, decrypts and decodes UTF-8 with malformed bytes replaced by U+FFFD.

<a name="not-authenticated"></a>
## Not Authenticated

There is no MAC and no AEAD tag. Two consequences follow:

- CBC is malleable. Someone who can modify a stored payload can flip bits in the IV and flip the same bits in the first plaintext block, predictably. Decryption still succeeds and returns a value the attacker partly chose.
- A decryption failure is observable. A caller that reports it back to whoever supplied the payload builds a padding oracle.

So `Crypt` keeps a value opaque at rest on the device and is not evidence that the value is unmodified. Verify anything whose integrity matters on the server that issued it, which can hold a secret this layer cannot.

<a name="not-laravel"></a>
## Not Laravel

Laravel's `Crypt` writes base64 of a JSON object holding the IV, the value and an HMAC, and refuses a payload whose MAC does not verify. This package writes `base64(iv):base64(ciphertext)` with no MAC. The two cannot read each other's output, so do not send a Magic payload to a Laravel `Crypt::decrypt` or the other way round. Exchange data with a server through the transport, not through this cipher.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Passing a `Crypt` payload to Laravel's decrypter | It will not parse; the formats differ. |
| Relying on a failed decrypt to catch tampering | Most tampering still decrypts. Verify integrity on the server. |
| Pinning the IV in production | `MagicEncrypter.encrypt` has an `iv:` parameter for tests only; a reused IV leaks equality of plaintext prefixes. |
| Building a `MagicEncrypter` from a key that is not 32 characters | It throws; use `MagicEncrypter.fromAppKey` for a `base64:` key. |

<a name="related-documentation"></a>
## Related Documentation

- [Crypt](../basics/crypt.md): the facade and its failure modes.
- [App Key](../basics/app-key.md): producing and formatting the key.
- [Testing](./testing.md): pinning an IV to assert an exact payload.
