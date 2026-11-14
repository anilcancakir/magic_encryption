# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- Two device-key calls that start together on a first launch now share one generated key, so neither payload is lost after a restart.
- `key:generate` no longer prints the new key; it prints a success line, and `--show` still prints the key and leaves `.env` alone.
- A raw key is checked by its UTF-8 byte length, so a 32-character non-ASCII key is refused at construction instead of failing later in `encrypt` and `decrypt`.
- Error messages and doc comments now name the real command, `dart run magic:dowel key:generate`.
- `key:generate` keeps `.env` well-formed when it appends the key (one newline before it, a trailing newline), replaces an `export APP_KEY=` line, and writes through a temporary file and a rename.

## [1.0.0] - 2026-11-14

### Added

- **First release.** AES-256-CBC encryption for Magic apps, moved out of `magic` core.
- `Crypt` facade: `encrypt` and `decrypt` with the app key (`APP_KEY`), and `encryptWithDeviceKey`, `decryptWithDeviceKey`, `hasDeviceKey`, `generateDeviceKey` and `clearDeviceKey` with a per-device key kept in `Vault`.
- `MagicEncrypter` (the cipher), `MagicDecryptException` and `EncryptionServiceProvider` (wiring).
- `key:generate` command, run as `dart run magic:dowel key:generate`, and a `dowel` plugin provider (`MagicEncryptionDowelProvider`) that `dart run magic:dowel plugin:install magic_encryption` registers.
- Built on `dowel` ^1.0.0 and `pointycastle` ^4.0.0. Requires Dart 3.13, Flutter 3.47 and `magic` ^1.0.0.
