/// Committed literals recorded once from the `encrypt` 5.0.3 implementation of
/// `MagicEncrypter` (AES-256-CBC, PKCS7, key = raw UTF-8 bytes or the decoded
/// `base64:` bytes, payload `base64(iv):base64(ciphertext)`).
///
/// Never recompute these from the code under test: the point is that a later
/// cipher backend has to reproduce the exact same bytes. The empty string is
/// deliberately absent, since `encrypt('')` is a `RangeError` on this backend.
library;

/// A raw 32-character `app.key`; the UTF-8 bytes are the AES key.
const String goldenRawKey = '0123456789abcdef0123456789abcdef';

/// A `base64:`-prefixed `app.key` that decodes to 32 bytes.
const String goldenBase64Key =
    r'base64://z59vPw7ern5OHe29jV0s/MycbDwL26t7SxrquopaI=';

/// One recorded encryption: [key] and [iv] in, [payload] out.
class GoldenCase {
  const GoldenCase({
    required this.name,
    required this.key,
    required this.plaintext,
    required this.iv,
    required this.payload,
  });

  final String name;

  /// An `app.key` as accepted by `MagicEncrypter.fromAppKey`.
  final String key;

  final String plaintext;

  /// The 16-byte IV, base64 encoded; also the first half of [payload].
  final String iv;

  /// `base64(iv):base64(ciphertext)`.
  final String payload;
}

const List<GoldenCase> goldenCases = [
  GoldenCase(
    name: 'raw key, 1 character',
    key: goldenRawKey,
    plaintext: 'a',
    iv: r'AQgPFh0kKzI5QEdOVVxjag==',
    payload: r'AQgPFh0kKzI5QEdOVVxjag==:wBp/ghEEEPv2m/vKG0bGOw==',
  ),
  GoldenCase(
    name: 'raw key, 15 characters',
    key: goldenRawKey,
    plaintext: 'fifteen chars..',
    iv: r'ERgfJi00O0JJUFdeZWxzeg==',
    payload: r'ERgfJi00O0JJUFdeZWxzeg==:eW5QfYegRk45ue8oZb/G6w==',
  ),
  GoldenCase(
    name: 'raw key, 16 characters (full block, padding block added)',
    key: goldenRawKey,
    plaintext: 'sixteen chars...',
    iv: r'ISgvNj1ES1JZYGdudXyDig==',
    payload: r'ISgvNj1ES1JZYGdudXyDig==:dkMfyg5yLl3p9k3S3w+Xw7pujkbBUuwS7IIYJZ2DcqE=',
  ),
  GoldenCase(
    name: 'raw key, 17 characters',
    key: goldenRawKey,
    plaintext: 'seventeen chars..',
    iv: r'MTg/Rk1UW2JpcHd+hYyTmg==',
    payload: r'MTg/Rk1UW2JpcHd+hYyTmg==:PO1djEZBcVWvRUUkt2+QnGupAJkpqnDMA4cEszn6Uto=',
  ),
  GoldenCase(
    name: 'raw key, multibyte UTF-8',
    key: goldenRawKey,
    plaintext: 'héllo wörld ✓ 日本語 🚀',
    iv: r'QUhPVl1ka3J5gIeOlZyjqg==',
    payload: r'QUhPVl1ka3J5gIeOlZyjqg==:Mm2zq5jrb5WaXVEh+tk60+SqKKVHgumVsHIHkCWksVEjtVT9tsxeXssvEC2J+CZm',
  ),
  GoldenCase(
    name: 'base64 key, 1 character',
    key: goldenBase64Key,
    plaintext: 'a',
    iv: r'UVhfZm10e4KJkJeepayzug==',
    payload: r'UVhfZm10e4KJkJeepayzug==:K3YCXGSHk6WNEbnRTIbD7A==',
  ),
  GoldenCase(
    name: 'base64 key, 15 characters',
    key: goldenBase64Key,
    plaintext: 'fifteen chars..',
    iv: r'YWhvdn2Ei5KZoKeutbzDyg==',
    payload: r'YWhvdn2Ei5KZoKeutbzDyg==:eyiWwv2GRLOjrb9821LLWw==',
  ),
  GoldenCase(
    name: 'base64 key, 16 characters (full block, padding block added)',
    key: goldenBase64Key,
    plaintext: 'sixteen chars...',
    iv: r'cXh/ho2Um6KpsLe+xczT2g==',
    payload: r'cXh/ho2Um6KpsLe+xczT2g==:cuKKY1rwmApkn5bGQ3Mus7gy4QkrcGFqTu+zHaM65nQ=',
  ),
  GoldenCase(
    name: 'base64 key, 17 characters',
    key: goldenBase64Key,
    plaintext: 'seventeen chars..',
    iv: r'gYiPlp2kq7K5wMfO1dzj6g==',
    payload: r'gYiPlp2kq7K5wMfO1dzj6g==:x8/xKRWHCD7NtXaWF6YW0M9oxMxLkfGqZsa4aESKb5k=',
  ),
  GoldenCase(
    name: 'base64 key, multibyte UTF-8',
    key: goldenBase64Key,
    plaintext: 'héllo wörld ✓ 日本語 🚀',
    iv: r'kZifpq20u8LJ0Nfe5ezz+g==',
    payload: r'kZifpq20u8LJ0Nfe5ezz+g==:IutQwEU3KrAVsfwf6ndGPxMbCIGhYDsDduNF8yEoeCC2VXRHxnvPvObhAjGzRzyY',
  ),
];

/// Payloads that must be refused under [goldenRawKey].
const String malformedEmptyPayload = '';
const String malformedEmptyCiphertext = r'AQIDBAUGBwgJCgsMDQ4PEA==:';
const String malformedShortCiphertext =
    r'AQIDBAUGBwgJCgsMDQ4PEA==:AAECAwQFBgcICQoLDA0O';
const String malformedShortIv = r'AQIDBAUGBwg=:K2+nIdtKijBvl/7W3enH1g==';
const String malformedBadPadding =
    r'AQIDBAUGBwgJCgsMDQ4PEA==:AA0aJzRBTltodYKPnKm2ww==';
const String malformedBadBase64 = r'AQIDBAUGBwgJCgsMDQ4PEA==:***not-base64***';
const String malformedThreeParts =
    r'AQIDBAUGBwgJCgsMDQ4PEA==:K2+nIdtKijBvl/7W3enH1g==:AAAA';
