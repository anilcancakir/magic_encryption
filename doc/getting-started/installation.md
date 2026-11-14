# Installation

Add `magic_encryption` to a Magic app, register its provider, create `APP_KEY` and check that `Crypt` answers.

- [Install](#install)
- [Requirements](#requirements)
- [Create the Key](#create-the-key)
- [Register the Provider](#register-the-provider)
- [Verify](#verify)
- [Related Documentation](#related-documentation)

<a name="install"></a>
## Install

```bash
flutter pub add magic_encryption
dart run magic:dowel plugin:install magic_encryption
```

The installer reads the package's `install.yaml` and injects `EncryptionServiceProvider` into the `providers` list of `lib/config/app.dart`. It publishes no config file: the provider reads the `app.key` that `magic:install` already wires from `APP_KEY`.

```dart
import 'package:magic_encryption/magic_encryption.dart';
```

The barrel is the only import; everything under `src/` is private.

<a name="requirements"></a>
## Requirements

| Requirement | Value |
|:------------|:------|
| Dart | `>=3.13.0` |
| Flutter | `>=3.47.0` |
| Magic | `^0.1.0`, installed and bootstrapped (`lib/config/app.dart` exists) |
| Dependencies | `pointycastle` for the cipher, pulled in automatically |
| Device-key mode | Core's `VaultServiceProvider`, because the key lives in `Vault` |

<a name="create-the-key"></a>
## Create the Key

```bash
dart run magic:dowel key:generate
```

The command writes `APP_KEY=base64:<32 random bytes>` to the project's `.env`, creating the file when it is missing. It replaces an `APP_KEY` line that is already there, and every value encrypted under the old key becomes unreadable. For that reason the installer does not run it: creating the key is your call. `--show` prints the line without touching `.env`.

Never commit `APP_KEY`. See [App Key](../basics/app-key.md) for the accepted formats.

<a name="register-the-provider"></a>
## Register the Provider

`plugin:install` does this for you. To do it by hand, add the provider to `lib/config/app.dart`:

```dart
import 'package:magic/magic.dart';
import 'package:magic_encryption/magic_encryption.dart';

final Map<String, dynamic> appConfig = {
  'app': {
    'key': env('APP_KEY'),
    'providers': [
      (app) => EncryptionServiceProvider(app),
    ],
  },
};
```

The provider is not auto-registered. Without it nothing binds the encrypter and `Crypt.encrypt` fails. Device-key mode alone does not need it, only `VaultServiceProvider`.

<a name="verify"></a>
## Verify

```dart
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  final String secret = Crypt.encrypt('hello');
  print(secret); // base64(iv):base64(ciphertext)
  print(Crypt.decrypt(secret)); // hello
}
```

Run it after `Magic.init` has completed. The two lines print a payload of two base64 halves joined by a colon, then `hello`. A payload differs on every run, because each call draws a fresh IV.

<a name="related-documentation"></a>
## Related Documentation

- [Crypt](../basics/crypt.md): encrypting and decrypting, and what fails.
- [App Key](../basics/app-key.md): key formats and `key:generate`.
- [Device Key](../basics/device-key.md): the key kept in `Vault`.
- [Wire Format](../guides/wire-format.md): the exact payload and its limits.
- [Testing](../guides/testing.md): testing code that calls `Crypt`.
