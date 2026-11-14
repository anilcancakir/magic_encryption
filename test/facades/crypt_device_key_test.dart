import 'dart:async';

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

/// A vault whose every call waits on a gate the test opens, so the test picks
/// the order in which reads and writes land.
class _GatedVault extends FakeVaultService {
  static const String _deviceKey = 'magic:device_encryption_key';

  final List<Completer<void>> _pending = [];

  /// While `false`, calls pass straight through without waiting.
  bool gating = true;

  /// How many `get` calls reached the vault.
  int gets = 0;

  /// When set, the next `put` throws it once after its gate opens.
  Object? failNextPut;

  /// The stored device key, read without a gate or a call count.
  Future<String?> storedKey() => super.get(_deviceKey);

  /// Let the event loop run until every started call is parked on a gate.
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  /// Open the gates one at a time in the order the calls arrived, letting the
  /// event loop settle after each, until no call is waiting.
  Future<void> releaseAll() async {
    await pump();
    while (_pending.isNotEmpty) {
      _pending.removeAt(0).complete();
      await pump();
    }
  }

  Future<void> _wait() async {
    if (!gating) return;
    final gate = Completer<void>();
    _pending.add(gate);
    await gate.future;
  }

  @override
  Future<String?> get(String key) async {
    gets++;
    await _wait();
    return super.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    await _wait();
    final error = failNextPut;
    if (error != null) {
      failNextPut = null;
      throw error;
    }
    return super.put(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _wait();
    return super.remove(key);
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

  group('Crypt device key ordering', () {
    late _GatedVault vault;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      vault = _GatedVault();
      Magic.app.setInstance('vault', vault);
    });

    tearDown(() async {
      vault.gating = false;
      await Crypt.clearDeviceKey();
    });

    test('generateDeviceKey waits for a creation in flight', () async {
      final creating = Crypt.encryptWithDeviceKey('first');
      await vault.pump();

      final replacing = Crypt.generateDeviceKey();
      await vault.releaseAll();
      await Future.wait([creating, replacing]);

      // The cache and Vault must agree, or a restart loses this payload.
      final payload = await Crypt.encryptWithDeviceKey('after');
      final restarted = MagicEncrypter((await vault.storedKey())!);

      expect(restarted.decrypt(payload), 'after');
    });

    test('clearDeviceKey is not undone by a creation in flight', () async {
      final creating = Crypt.encryptWithDeviceKey('first');
      await vault.pump();

      final clearing = Crypt.clearDeviceKey();
      await vault.releaseAll();
      await Future.wait([creating, clearing]);
      vault.gating = false;

      expect(await Crypt.hasDeviceKey(), isFalse);
    });

    test(
      'a creation that fails mid-flight leaves the new key cached',
      () async {
        vault.failNextPut = StateError('keychain unavailable');

        final creating = expectLater(
          Crypt.encryptWithDeviceKey('first'),
          throwsA(isA<StateError>()),
        );
        await vault.pump();

        final replacing = Crypt.generateDeviceKey();
        await vault.releaseAll();
        await Future.wait([creating, replacing]);
        vault.gating = false;

        // The failed creation must not evict the encrypter generateDeviceKey
        // installed: a cache hit reads nothing from Vault.
        final getsBefore = vault.gets;
        final payload = await Crypt.encryptWithDeviceKey('after');
        final restarted = MagicEncrypter((await vault.storedKey())!);

        expect(vault.gets, getsBefore);
        expect(restarted.decrypt(payload), 'after');
      },
    );
  });
}
