# Device Key

Encrypt with a key generated on the device and kept in `Vault`, so a value stored locally cannot be opened anywhere else.

- [Basic Usage](#basic-usage)
- [Quick Reference](#quick-reference)
- [How the Key Is Made](#how-the-key-is-made)
- [Lifecycle](#lifecycle)
- [Gotchas](#gotchas)
- [Related Documentation](#related-documentation)

<a name="basic-usage"></a>
## Basic Usage

```dart
import 'package:magic_encryption/magic_encryption.dart';

Future<void> main() async {
  final String secret = await Crypt.encryptWithDeviceKey('my-user-token');
  final String value = await Crypt.decryptWithDeviceKey(secret);
  print(value); // my-user-token
}
```

Register core's `VaultServiceProvider` in `providers`. Device-key mode reads and writes the key through the `Vault` facade and needs no `app.key`, so it works without `EncryptionServiceProvider` and without `APP_KEY`.

<a name="quick-reference"></a>
## Quick Reference

| Member | Returns | Meaning |
|:-------|:--------|:--------|
| `Crypt.encryptWithDeviceKey(value)` | `Future<String>` | Encrypts under the device key, creating it on first use. |
| `Crypt.decryptWithDeviceKey(payload)` | `Future<String>` | Decrypts under the device key. Throws `MagicDecryptException` like `Crypt.decrypt`. |
| `Crypt.hasDeviceKey()` | `Future<bool>` | Whether `Vault` holds a device key. Never creates one. |
| `Crypt.generateDeviceKey()` | `Future<void>` | Replaces the key. Everything encrypted under the old one is lost. |
| `Crypt.clearDeviceKey()` | `Future<void>` | Deletes the key from `Vault`. Everything encrypted under it is lost. |

The payload is the same `base64(iv):base64(ciphertext)` as [Crypt](./crypt.md), and the same limits apply: no MAC, and `encryptWithDeviceKey('')` throws `RangeError`.

<a name="how-the-key-is-made"></a>
## How the Key Is Made

On first use the key is read from `Vault` under the name `magic:device_encryption_key`. When it is absent, 32 characters are drawn from `A-Z`, `a-z` and `0-9` with a secure random source and stored there. The encrypter built from it is then cached in memory for the life of the process.

How safe the key is depends on `Vault`'s store on that platform: the Keychain on iOS and macOS, the Keystore on Android, and a weaker store on web.

<a name="lifecycle"></a>
## Lifecycle

- The key lives as long as the install's secure storage does. Clearing app data or uninstalling the app removes it, and the ciphertext it protected cannot be opened afterwards.
- `generateDeviceKey()` and `clearDeviceKey()` both update the in-memory cache as well as `Vault`, so the next call uses the new state at once.
- The key never leaves the device, so a payload encrypted here cannot be decrypted by a server or another install. Use [Crypt](./crypt.md) with a shared `APP_KEY` for that.

<a name="gotchas"></a>
## Gotchas

| Mistake | Fix |
|:--------|:----|
| Forgetting `VaultServiceProvider` | Register core's provider; the key is stored through `Vault`. |
| Calling `generateDeviceKey()` to "refresh" the key | It orphans every existing value. Call it only when the data is disposable. |
| Decrypting a `Crypt.encrypt` payload with the device key, or the other way round | The two modes use different keys; keep each value with the mode that wrote it. |
| Treating the device key as backed up | It is lost with the secure storage. Keep nothing here that you cannot recreate. |
| Reaching for device-key mode to share data with a server | The server cannot read it; use `Crypt` with `APP_KEY` instead. |
| Leaking the cached key between tests | Call `Crypt.clearDeviceKey()` in `tearDown`; see [Testing](../guides/testing.md). |

<a name="related-documentation"></a>
## Related Documentation

- [Crypt](./crypt.md): encrypting with the app key.
- [App Key](./app-key.md): where `APP_KEY` comes from.
- [Testing](../guides/testing.md): a fake vault and the cached encrypter.
