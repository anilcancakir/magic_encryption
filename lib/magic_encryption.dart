/// AES-256-CBC encryption for Magic apps.
///
/// `Crypt` encrypts with the configured `app.key` (bound by
/// [EncryptionServiceProvider]) or with a per-device key kept in `Vault`.
/// Payloads are `base64(iv):base64(ciphertext)` and are not authenticated; see
/// [MagicEncrypter].
library;

export 'src/facades/crypt.dart';
export 'src/encryption/encryption_service_provider.dart';
export 'src/encryption/exceptions.dart';
export 'src/encryption/magic_encrypter.dart';
