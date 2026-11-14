import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_encryption/magic_encryption.dart';

const Color _ink = Color(0xFF111827);
const Color _accent = Color(0xFF4F46E5);
const TextStyle _text = TextStyle(color: _ink, fontSize: 16);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configs: [
      {
        'app': {
          // A throwaway key so the example runs on its own. A real app reads
          // `env('APP_KEY')`, written by `dart run magic:dowel key:generate`.
          'key': '0123456789abcdef0123456789abcdef',
          'providers': [(app) => EncryptionServiceProvider(app)],
        },
      },
    ],
  );

  runApp(const ExampleApp());
}

/// One text field, an Encrypt button and a Decrypt button.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'magic_encryption example',
      color: _accent,
      textStyle: _text,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        );
      },
      home: const CryptPage(),
    );
  }
}

class CryptPage extends StatefulWidget {
  const CryptPage({super.key});

  @override
  State<CryptPage> createState() => _CryptPageState();
}

class _CryptPageState extends State<CryptPage> {
  final TextEditingController _input = TextEditingController(
    text: 'my-secret-value',
  );
  final FocusNode _focus = FocusNode();

  String _output = '';

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _encrypt() {
    // Crypt.encrypt throws RangeError for the empty string.
    if (_input.text.isEmpty) {
      setState(() => _output = 'Type something to encrypt.');
      return;
    }

    setState(() => _output = Crypt.encrypt(_input.text));
  }

  void _decrypt() {
    try {
      setState(() => _output = Crypt.decrypt(_input.text));
    } on MagicDecryptException catch (error) {
      setState(() => _output = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Text, or a payload to decrypt'),
            const SizedBox(height: 8),
            EditableText(
              controller: _input,
              focusNode: _focus,
              style: _text,
              cursorColor: _accent,
              backgroundCursorColor: _ink,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Button(label: 'Encrypt', onTap: _encrypt),
                const SizedBox(width: 8),
                _Button(label: 'Decrypt', onTap: _decrypt),
              ],
            ),
            const SizedBox(height: 16),
            Text(_output, style: _text),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _accent,
        child: Text(label, style: const TextStyle(color: Color(0xFFFFFFFF))),
      ),
    );
  }
}
