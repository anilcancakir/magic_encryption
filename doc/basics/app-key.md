# App Key

The `app.key` that `Crypt.encrypt` and `Crypt.decrypt` use, the two formats it accepts, how `key:generate` writes it and what changing it costs.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [key:generate](#key-generate)
- [Changing the Key](#changing-the-key)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

```bash
dart run magic:dowel key:generate
```

```env
APP_KEY=base64:your-generated-key-here
```

`lib/config/app.dart` reads it as `'key': env('APP_KEY')`, and `EncryptionServiceProvider` builds the encrypter from `app.key` the first time `Crypt` is used.

<a name="quick-reference"></a>
## Quick Reference

| Format | Example shape | Rule |
|:-------|:--------------|:-----|
| `base64:` prefix | `base64:` plus the base64 of 32 bytes | Must decode to exactly 32 bytes. This is what `key:generate` writes. |
| Raw string | 32 bytes of UTF-8 | The UTF-8 bytes of the string are the AES key. ASCII characters take one byte each, so 32 ASCII characters are 32 bytes. |

Anything else fails with an `Exception` the first time `Crypt` is used, not at boot.

<a name="key-generate"></a>
## key:generate

| Option | Effect |
|:-------|:-------|
| none | Generates 32 random bytes, base64-encodes them and writes `APP_KEY=base64:...` to the project's `.env`. Replaces an existing `APP_KEY` line, adds one when absent, and creates `.env` when the file is missing. Prints a success line only, never the key, so it stays out of CI logs. |
| `--show` | Prints `APP_KEY=base64:...` and leaves `.env` alone. |

The command lives in `package:magic_encryption/cli.dart` and runs as a plain Dart process, with no Flutter engine behind it.

<a name="changing-the-key"></a>
## Changing the Key

The payload carries no key id, so there is no rotation. A new `APP_KEY` cannot open anything written under the old one: every stored `Crypt` value becomes unreadable (nearly always a `MagicDecryptException`). To migrate, decrypt with an encrypter built from the old key and encrypt again with the new one:

```dart
import 'package:magic_encryption/magic_encryption.dart';

String reencrypt(String payload, String oldAppKey) {
  final MagicEncrypter oldEncrypter = MagicEncrypter.fromAppKey(oldAppKey);

  return Crypt.encrypt(oldEncrypter.decrypt(payload));
}
```

Run the migration while the app still has the old key available, then retire it.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Running `key:generate` on an app that has stored ciphertext | It overwrites `APP_KEY` and orphans every value under the old key. Use `--show` to look, or migrate as above. |
| Committing `.env` or `APP_KEY` | Keep the key out of version control. |
| A raw key of 31 or 33 bytes | The key must be exactly 32 bytes of UTF-8, which is 32 characters when they are all ASCII. |
| A `base64:` key of 16 or 24 bytes | It must decode to 32 bytes; shorter AES keys are refused. |
| Non-ASCII characters in a raw key | One character can be several UTF-8 bytes, so 32 characters can be more than 32 bytes and the constructor refuses them. Use `key:generate`. |
| Expecting boot to catch a bad key | The encrypter is lazy: the error appears on the first `Crypt` call. |

<a name="related-documentation"></a>
## Related Documentation

- [Crypt](./crypt.md): using the key to encrypt and decrypt.
- [Device Key](./device-key.md): a key that is generated on the device instead.
- [Installation](../getting-started/installation.md): creating the key for the first time.
