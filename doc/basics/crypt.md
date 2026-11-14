# Crypt

Encrypt and decrypt strings with the app key through the `Crypt` facade, and know what fails.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [Failure Modes](#failure-modes)
- [What It Does Not Guarantee](#what-it-does-not-guarantee)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

```dart
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  final String secret = Crypt.encrypt('my-secret-value');

  try {
    final String value = Crypt.decrypt(secret);
    print(value); // my-secret-value
  } on MagicDecryptException catch (error) {
    print('Could not decrypt: $error');
  }
}
```

`Crypt` resolves the `encrypter` binding that `EncryptionServiceProvider` registers in `boot()`, so call it after `Magic.init`. Both methods are synchronous and take and return a `String`.

<a name="quick-reference"></a>
## Quick Reference

| Member | Returns | Meaning |
|:-------|:--------|:--------|
| `Crypt.encrypt(value)` | `String` | `base64(iv):base64(ciphertext)`. A fresh random IV per call, so the same value never produces the same payload twice. |
| `Crypt.decrypt(payload)` | `String` | The plaintext. Throws `MagicDecryptException` when the payload is malformed or does not decrypt under the key. |
| `MagicDecryptException` | exception | `message` holds the reason; `toString()` prints `MagicDecryptException: <message>`. |

The key is `app.key`, normally `APP_KEY` from `.env`. To encrypt with a key that lives on the device instead, see [Device Key](./device-key.md).

<a name="failure-modes"></a>
## Failure Modes

| Situation | What happens |
|:----------|:-------------|
| `Crypt.encrypt('')` | Throws `RangeError`: there is no block to pad. Guard against the empty string. |
| `app.key` missing or empty | `boot()` succeeds. The first `Crypt` call throws an `Exception` saying the app key is missing. |
| `app.key` of the wrong size | Throws an `Exception` on the first `Crypt` call, not at boot. A raw key must be 32 bytes of UTF-8 (32 characters for ASCII); a `base64:` key must decode to 32 bytes. |
| A `base64:` key that is not valid base64 | Throws an `Exception` on the first `Crypt` call. |
| A payload without exactly one `:` | `decrypt` throws `MagicDecryptException` (`Invalid payload format`). |
| A payload with a bad IV, partial block or broken padding | `decrypt` throws `MagicDecryptException` (`Decryption failed: ...`). |
| A payload from another key | Almost always `MagicDecryptException`. Roughly one in 256 happens to unpad cleanly and returns garbage text instead of throwing. |
| Decrypted bytes that are not valid UTF-8 | Decode to U+FFFD replacement characters rather than throwing. |

<a name="what-it-does-not-guarantee"></a>
## What It Does Not Guarantee

The payload has no MAC. A value that decrypts is not thereby proven untampered: CBC is malleable, so someone who can edit a stored payload can flip bits of the first plaintext block and decryption still succeeds. A decryption failure shown to whoever supplied the payload is a padding oracle.

Use `Crypt` to keep a value opaque at rest on the device. Verify anything whose integrity matters (a token, an amount, an identity) on the server that issued it. See [Wire Format](../guides/wire-format.md) for the exact format.

The app key is not a secret from someone who holds your app. `APP_KEY` is loaded from the `.env` asset, so it ships inside every build, and anyone who unpacks the build can read it. Config-key mode hides a value from people without the binary. Never put a key that a server also trusts in `APP_KEY`; for a secret kept on one device, prefer [Device Key](./device-key.md).

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Calling `Crypt` before `EncryptionServiceProvider` is registered | Add it to `providers` in `lib/config/app.dart`; it is not auto-registered. |
| Calling `Crypt` before `Magic.init` completes | `await Magic.init(...)` first. |
| Encrypting an empty string | Check for `''` first; it throws `RangeError`. |
| Treating a successful decrypt as proof of integrity | There is no MAC. Verify integrity on the server. |
| Showing `MagicDecryptException` to the party that sent the payload | Log it, answer with one generic error. |
| Expecting Laravel to read the payload | The format is not Laravel's; see [Wire Format](../guides/wire-format.md). |
| Sharing `APP_KEY` with a server so it can read or write payloads | The key ships inside the build, so it is not secret from anyone with the app. Exchange data through the transport. |
| Encrypting a `Map` or a `List` | `Crypt` takes a `String`; encode with `jsonEncode` first and decode after `decrypt`. |

<a name="related-documentation"></a>
## Related Documentation

- [App Key](./app-key.md): the formats `app.key` accepts and `key:generate`.
- [Device Key](./device-key.md): encrypting with a key kept in `Vault`.
- [Wire Format](../guides/wire-format.md): the payload byte by byte.
- [Testing](../guides/testing.md): testing code that calls `Crypt`.
