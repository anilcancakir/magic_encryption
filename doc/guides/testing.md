# Testing

Test code that calls `Crypt` without a device, a keychain or a mocking library.

- [Config-Key Mode](#config-key-mode)
- [Device-Key Mode](#device-key-mode)
- [Pinning the IV](#pinning-the-iv)
- [Related Documentation](#related-documentation)

<a name="config-key-mode"></a>
## Config-Key Mode

Bind an encrypter under the `encrypter` key, the one `EncryptionServiceProvider` binds in production, and `Crypt` uses it. Every `setUp()` resets the container, as every Magic test does.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton(
      'encrypter',
      () => MagicEncrypter('0123456789abcdef0123456789abcdef'),
    );
  });

  test('a value survives a round trip', () {
    expect(Crypt.decrypt(Crypt.encrypt('hello')), 'hello');
  });

  test('a malformed payload is refused', () {
    expect(
      () => Crypt.decrypt('not-a-payload'),
      throwsA(isA<MagicDecryptException>()),
    );
  });
}
```

To test the provider itself, boot Magic with `'app': {'key': '...', 'providers': [(app) => EncryptionServiceProvider(app)]}`; `Magic.init` reads path_provider, so mock its channel in `setUpAll`.

Do not assert that a payload from another key throws. About one wrong-key payload in 256 unpads cleanly and returns garbage, so assert instead that it never yields the plaintext.

<a name="device-key-mode"></a>
## Device-Key Mode

Swap the vault for core's fake with `Vault.fake()`. `Crypt` caches the device encrypter in a static field that `Magic.flush()` does not reset, so a key from an earlier test would outlive its fake vault: clear it in `tearDown`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Vault.fake();
  });

  tearDown(() async {
    await Crypt.clearDeviceKey();
  });

  test('the device key is created on first use', () async {
    expect(await Crypt.hasDeviceKey(), isFalse);

    final String secret = await Crypt.encryptWithDeviceKey('token');

    expect(await Crypt.hasDeviceKey(), isTrue);
    expect(await Crypt.decryptWithDeviceKey(secret), 'token');
  });
}
```

<a name="pinning-the-iv"></a>
## Pinning the IV

`MagicEncrypter.encrypt` takes an `iv:` of 16 bytes so a test can assert an exact payload. Leave it unset in production: a reused IV leaks equality of plaintext prefixes.

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_encryption/magic_encryption.dart';

void main() {
  test('the same key, value and IV give the same payload', () {
    final MagicEncrypter encrypter = MagicEncrypter('0123456789abcdef0123456789abcdef');
    final Uint8List iv = Uint8List(16);

    final String payload = encrypter.encrypt('hello', iv: iv);

    expect(payload.split(':').first, base64.encode(iv));
    expect(encrypter.encrypt('hello', iv: iv), payload);
  });
}
```

<a name="related-documentation"></a>
## Related Documentation

- [Crypt](../basics/crypt.md): the facade under test.
- [Device Key](../basics/device-key.md): the cached encrypter and the vault.
- [Wire Format](./wire-format.md): what a payload contains.
