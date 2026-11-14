import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_encryption/magic_encryption.dart';

/// A vault whose reads answer a few turns of the event loop late, so two
/// callers that start together both read before either one has written.
class _SlowReadVault extends FakeVaultService {
  /// How many `put` calls reached the vault.
  int puts = 0;

  /// When set, the next `put` throws it once, then the vault behaves again.
  Object? failNextPut;

  @override
  Future<String?> get(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return super.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    puts++;
    final error = failNextPut;
    if (error != null) {
      failNextPut = null;
      throw error;
    }
    return super.put(key, value);
  }
}

void main() {
  group('Crypt device key', () {
    late _SlowReadVault vault;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      vault = _SlowReadVault();
      Magic.app.setInstance('vault', vault);
    });

    tearDown(() async {
      await Crypt.clearDeviceKey();
    });

    test('concurrent first calls share one generated key', () async {
      final payloads = await Future.wait([
        Crypt.encryptWithDeviceKey('first'),
        Crypt.encryptWithDeviceKey('second'),
      ]);

      expect(vault.puts, 1);
      expect(await Crypt.decryptWithDeviceKey(payloads[0]), 'first');
      expect(await Crypt.decryptWithDeviceKey(payloads[1]), 'second');
    });

    test('both payloads open under the key Vault holds', () async {
      final payloads = await Future.wait([
        Crypt.encryptWithDeviceKey('first'),
        Crypt.encryptWithDeviceKey('second'),
      ]);

      // A restart has no cached encrypter, only the key Vault kept.
      final storedKey = await vault.get('magic:device_encryption_key');
      final restarted = MagicEncrypter(storedKey!);

      expect(restarted.decrypt(payloads[0]), 'first');
      expect(restarted.decrypt(payloads[1]), 'second');
    });

    test('a failed first creation is not cached', () async {
      vault.failNextPut = StateError('keychain unavailable');

      await expectLater(
        Crypt.encryptWithDeviceKey('first'),
        throwsA(isA<StateError>()),
      );

      final payload = await Crypt.encryptWithDeviceKey('second');

      expect(await Crypt.decryptWithDeviceKey(payload), 'second');
    });

    test('generateDeviceKey replaces the shared key', () async {
      await Crypt.encryptWithDeviceKey('value');
      final before = await vault.get('magic:device_encryption_key');

      await Crypt.generateDeviceKey();
      final payload = await Crypt.encryptWithDeviceKey('value');
      final after = await vault.get('magic:device_encryption_key');

      expect(after, isNot(before));
      expect(await Crypt.decryptWithDeviceKey(payload), 'value');
    });

    test('clearDeviceKey makes the next call create a new key', () async {
      await Crypt.encryptWithDeviceKey('value');
      await Crypt.clearDeviceKey();

      expect(await Crypt.hasDeviceKey(), isFalse);

      await Crypt.encryptWithDeviceKey('value');

      expect(await Crypt.hasDeviceKey(), isTrue);
    });
  });
}
