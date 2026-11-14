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

  /// A `.env` line that sets `APP_KEY`: group 1 is the leading whitespace and
  /// optional `export`, and the match runs up to the end of the value, so a
  /// trailing carriage return is not part of it.
  static final RegExp _appKeyLine = RegExp(r'^(\s*(?:export\s+)?)APP_KEY=.*');

  /// Write the key to the environment file.
  ///
  /// The file is written in place, so its permissions and a symlink at its
  /// path survive. A crash mid-write can leave it truncated.
  void _writeToEnv(File envFile, String key) {
    final content = envFile.existsSync() ? envFile.readAsStringSync() : '';
    final lines = content.split('\n');
    final index = lines.indexWhere(_appKeyLine.hasMatch);

    // 1. Replace the value on the existing line (keeping any `export`), or
    //    append after exactly one newline.
    final String updated;
    if (index >= 0) {
      lines[index] = lines[index].replaceFirstMapped(
        _appKeyLine,
        (match) => '${match[1]}APP_KEY=$key',
      );
      updated = lines.join('\n');
    } else {
      final separator = content.isEmpty || content.endsWith('\n') ? '' : '\n';
      updated = '$content${separator}APP_KEY=$key';
    }

    // 2. Keep the file well-formed: one trailing newline.
    final body = updated.endsWith('\n') ? updated : '$updated\n';

    // 3. Write in place and flush, so the mode and any symlink are kept.
    envFile.writeAsStringSync(body, flush: true);
  }

  /// Generate a secure random 32-byte key base64 encoded.
  String _generateKey() {
    final rng = Random.secure();
    final bytes = List.generate(32, (_) => rng.nextInt(256));
    return base64.encode(bytes);
  }
}
