# magic_encryption example

A Magic app with one text field and two buttons. `Encrypt` runs the text through `Crypt.encrypt` and shows the `base64(iv):base64(ciphertext)` payload; `Decrypt` runs that payload back through `Crypt.decrypt` and shows the plaintext, or the `MagicDecryptException` when you edit the payload first.

```bash
cd example
flutter create --platforms=web .
flutter run -d chrome
```

`flutter create` adds the platform folder once; it leaves `lib/` and `pubspec.yaml` as they are. The app key is a throwaway 32-character string in `lib/main.dart`, so the example runs on its own. In a real app run `dart run magic:dowel key:generate` and read `APP_KEY` from `.env` instead, and never commit the key.
