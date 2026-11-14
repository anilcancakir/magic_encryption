import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dowel/dowel.dart';

/// Generate a new application key for the Flutter Magic app.
class KeyGenerateCommand extends DowelCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'key:generate';

  @override
  String get description => 'Generate a new application key';

  @override
  void configure(ArgParser parser) {
    parser.addFlag(
      'show',
      help: 'Display the key instead of modifying the .env file',
      negatable: false,
    );
  }

  @override
  Future<int> handle(DowelContext ctx) async {
    // 1. Generate a random 32-byte key and base64 encode it.
    final key = _generateKey();
    final keyWithPrefix = 'base64:$key';

    // 2. If --show flag is present, only output the key.
    if (ctx.input.hasOption('show')) {
      ctx.output.info('APP_KEY=$keyWithPrefix');
      return 0;
    }

    // 3. Find project root and target .env file.
    final root = FileHelper.findProjectRoot();
    final envFile = File('$root/.env');

    // 4. Update or create .env file with the new key.
    _writeToEnv(envFile, keyWithPrefix);

    // 5. Output a success message; the key stays out of stdout and CI logs.
    ctx.output.success('Application key set successfully in .env.');
    return 0;
  }

  /// A `.env` line that sets `APP_KEY`, with or without a leading `export`.
  static final RegExp _appKeyLine = RegExp(r'^\s*(?:export\s+)?APP_KEY=');

  /// Write the key to the environment file.
  ///
  /// The new content goes to a sibling temporary file that is then renamed
  /// over `.env`, so a crash never leaves a truncated file behind.
  void _writeToEnv(File envFile, String key) {
    final content = envFile.existsSync() ? envFile.readAsStringSync() : '';
    final lines = content.split('\n');
    final index = lines.indexWhere(_appKeyLine.hasMatch);

    // 1. Replace the existing line, or append after exactly one newline.
    final String updated;
    if (index >= 0) {
      lines[index] = 'APP_KEY=$key';
      updated = lines.join('\n');
    } else {
      final separator = content.isEmpty || content.endsWith('\n') ? '' : '\n';
      updated = '$content${separator}APP_KEY=$key';
    }

    // 2. Keep the file well-formed: one trailing newline.
    final body = updated.endsWith('\n') ? updated : '$updated\n';

    // 3. Swap it in atomically.
    final temp = File('${envFile.path}.tmp');
    temp.writeAsStringSync(body);
    temp.renameSync(envFile.path);
  }

  /// Generate a secure random 32-byte key base64 encoded.
  String _generateKey() {
    final rng = Random.secure();
    final bytes = List.generate(32, (_) => rng.nextInt(256));
    return base64.encode(bytes);
  }
}
