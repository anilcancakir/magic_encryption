# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.0.1] - 2026-11-14

### Added

- **First release.** AES-256-CBC encryption for Magic apps, moved out of `magic` core 0.1.0.
- `Crypt` facade: `encrypt` and `decrypt` with the app key (`APP_KEY`), and `encryptWithDeviceKey`, `decryptWithDeviceKey`, `hasDeviceKey`, `generateDeviceKey` and `clearDeviceKey` with a per-device key kept in `Vault`.
- `MagicEncrypter` (the cipher), `MagicDecryptException` and `EncryptionServiceProvider` (wiring).
- `key:generate` command, run as `dart run magic:dowel key:generate`, and a `dowel` plugin provider (`MagicEncryptionDowelProvider`) that `dart run magic:dowel plugin:install magic_encryption` registers.
- Built on `dowel` ^0.0.21 and `pointycastle` ^4.0.0. Requires Dart 3.13, Flutter 3.47 and `magic` ^0.1.0.
