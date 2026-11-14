<p align="center">
  <img src="https://raw.githubusercontent.com/anilcancakir/magic_encryption/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Encryption</h1>

<p align="center">
  <strong>Keep a value opaque at rest on the device.</strong><br/>
  AES-256-CBC for Magic apps: the <code>Crypt</code> facade encrypts with your <code>APP_KEY</code> or with a per-device key kept in <code>Vault</code>, and <code>key:generate</code> writes the key. Payloads are not authenticated and not Laravel-compatible.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_encryption"><img src="https://img.shields.io/pub/v/magic_encryption.svg" alt="pub package"></a>
  <a href="https://github.com/anilcancakir/magic_encryption/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/anilcancakir/magic_encryption/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://codecov.io/gh/anilcancakir/magic_encryption"><img src="https://codecov.io/gh/anilcancakir/magic_encryption/graph/badge.svg" alt="codecov"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/magic_encryption/score"><img src="https://img.shields.io/pub/points/magic_encryption" alt="pub points"></a>
</p>

<p align="center">
  <a href="https://anilcancakir.com/magic/docs/encryption">Documentation</a> ·
  <a href="https://pub.dev/packages/magic_encryption">pub.dev</a> ·
  <a href="https://github.com/anilcancakir/magic_encryption/issues">Issues</a>
</p>

## At a glance

| Fact | Value |
|---|---|
| Package | [`magic_encryption`](https://pub.dev/packages/magic_encryption) |
| Install | `flutter pub add magic_encryption`, then `dart run magic:dowel plugin:install magic_encryption` |
| Import | `package:magic_encryption/magic_encryption.dart` |
| Entry points | `Crypt` (facade), `EncryptionServiceProvider` (wiring), `MagicEncrypter` (the cipher), `MagicDecryptException`; `key:generate` (CLI) |
| Platforms | Config-key mode is pure Dart and runs wherever Flutter does. Device-key mode is as strong as `Vault`'s store on that platform (Keychain, Keystore; a weaker store on web). |
| Requires | Dart >=3.13, Flutter >=3.47, `magic` ^1.0.0 |
| Dependencies | `magic`, `pointycastle`; dowel runs `key:generate` |
| License | MIT |

## Install

```bash
flutter pub add magic_encryption
dart run magic:dowel plugin:install magic_encryption
```

The installer registers `EncryptionServiceProvider` in the `providers` list of `lib/config/app.dart`. It publishes no config: the provider reads the `app.key` that `magic:install` already wires from `APP_KEY`. Create the key once:

```bash
dart run magic:dowel key:generate
```

`key:generate` replaces any `APP_KEY` already in `.env`, and every value encrypted under the old key becomes unreadable. The installer does not run it for you, so it never overwrites a key by surprise. `--show` prints `APP_KEY=base64:...` without touching `.env`.

## Crypt

Encrypt and decrypt a string with the app key.

```dart
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  final String secret = Crypt.encrypt('my-secret-value');

  try {
    final String value = Crypt.decrypt(secret);
    print(value); // my-secret-value
  } on MagicDecryptException catch (error) {
    print('Not a payload this key can open: $error');
  }
}
```

| Member | Returns | Meaning |
|--------|---------|---------|
| `Crypt.encrypt(value)` | `String` | `base64(iv):base64(ciphertext)` with a fresh random IV, so one value never encrypts to the same payload twice. |
| `Crypt.decrypt(payload)` | `String` | The plaintext. Throws `MagicDecryptException` for a malformed payload or one that does not decrypt under this key. |

Failure modes:

| Situation | What happens |
|-----------|--------------|
| `Crypt.encrypt('')` | Throws `RangeError`: there is no block to pad. |
| `app.key` missing or empty | The first `Crypt` call throws an `Exception` that says the key is missing. Boot does not fail. |
| `app.key` the wrong size | The first `Crypt` call throws an `Exception`: a raw key must be 32 bytes of UTF-8 (32 characters for ASCII), a `base64:` key must decode to 32 bytes. |
| A payload of the wrong shape | `decrypt` throws `MagicDecryptException`. |
| A payload from another key | Almost always `MagicDecryptException`; about one in 256 passes unpadding by chance and returns garbage text. |

## Device key

Encrypt with a key generated on the device and kept in `Vault`, so a value stored locally cannot be opened elsewhere.

```dart
import 'package:magic_encryption/magic_encryption.dart';

Future<void> main() async {
  final String secret = await Crypt.encryptWithDeviceKey('my-user-token');
  final String value = await Crypt.decryptWithDeviceKey(secret);
  print(value); // my-user-token
}
```

| Member | Meaning |
|--------|---------|
| `Crypt.encryptWithDeviceKey(value)`, `Crypt.decryptWithDeviceKey(payload)` | Async, because the key comes from `Vault`. The key is created on first use. |
| `Crypt.hasDeviceKey()` | Whether a device key exists in `Vault`. |
| `Crypt.generateDeviceKey()` | Replaces the key. Everything encrypted under the old one is lost. |
| `Crypt.clearDeviceKey()` | Deletes the key from `Vault`. Everything encrypted under it is lost. |

Device-key mode needs core's `VaultServiceProvider` registered, and needs no `app.key`.

## What this does not give you

The payload has no MAC. A value that decrypts is not thereby proven untampered: CBC is malleable, and a decryption failure reported back to whoever supplied the payload is a padding oracle. Use `Crypt` to keep a value opaque at rest, and verify anything whose integrity matters (a token, an amount, an identity) on the server that issued it. `APP_KEY` is read from the `.env` asset, so it ships inside every build: config-key mode hides a value from someone without your binary, not from someone who unpacks it, and a key a server also trusts must never live there. For a secret kept on one device, use device-key mode.

The wire format is also not Laravel's. A Laravel payload is base64 of a JSON object with an HMAC; this one is `base64(iv):base64(ciphertext)`. The two cannot read each other's output. The format is fixed so ciphertext written by Magic 0.0.41 and earlier stays readable.

## For AI coding agents

Rules for an agent writing code against this package. Each one is a mistake that costs a user their data or their key.

| Do | Because |
|----|---------|
| Import only `package:magic_encryption/magic_encryption.dart` | Everything under `src/` is private. |
| Register `EncryptionServiceProvider` in `lib/config/app.dart` for `Crypt.encrypt` and `Crypt.decrypt` | It is not auto-registered, and without it the encrypter is never bound. |
| Set `APP_KEY` with `dart run magic:dowel key:generate` and never commit it | A raw key of 32 bytes of UTF-8 (32 characters for ASCII) or a `base64:` key of 32 bytes is accepted; anything else fails on first use. |
| Never run `key:generate` on an app with stored ciphertext | It replaces `APP_KEY`, and every `Crypt` value written under the old key becomes unreadable. |
| Treat `Crypt` as confidentiality only | There is no MAC. Verify integrity server-side. |
| Catch `MagicDecryptException` and do not echo it to the party that sent the payload | Distinguishable failures are what a padding oracle needs. |
| Guard against `''` before `Crypt.encrypt` | An empty string throws `RangeError`. |
| Register core's `VaultServiceProvider` for `*WithDeviceKey` | The device key lives in `Vault`. |
| In a test, call `Crypt.clearDeviceKey()` in `tearDown` | `Crypt` caches the device encrypter in a static field that `Magic.flush()` does not reset. |

## Dependencies

`magic` for the container, the `Config` and `Vault` facades and the service provider base class; `pointycastle` for AES-CBC with PKCS7 padding; dowel to run `key:generate` through `dart run magic:dowel`. The `key:generate` command lives in `package:magic_encryption/cli.dart`, which imports no UI toolkit so the command line runs as a plain Dart process.

## Links

- [Documentation](https://anilcancakir.com/magic/docs/encryption/getting-started/installation): installation, `Crypt`, the app key, the device key, the wire format and testing
- [API reference](https://pub.dev/documentation/magic_encryption/latest/)
- [llms.txt](llms.txt) and the [agent skill](skills/magic-encryption/SKILL.md) for AI coding agents: `npx skills add anilcancakir/magic_encryption`
- [Changelog](CHANGELOG.md)
- [Report an issue](https://github.com/anilcancakir/magic_encryption/issues)
- [Security policy](SECURITY.md)

## License

MIT, see [LICENSE](LICENSE). Built by [Anılcan Çakır](https://anilcancakir.com).
