import 'dart:io';

import 'package:dowel/dowel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_encryption/cli.dart';

void main() {
  group('key:generate', () {
    final keyLine = RegExp(r'APP_KEY=base64:[A-Za-z0-9+/]{43}=');

    late Directory project;
    late Directory originalCwd;
    late File envFile;
    late DowelCommand command;
    late BufferedOutput output;

    setUp(() {
      originalCwd = Directory.current;
      project = Directory.systemTemp.createTempSync('key_generate_');
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: app\n');
      envFile = File('${project.path}/.env');
      Directory.current = project.path;

      command = MagicEncryptionDowelProvider().commands().single;
      output = BufferedOutput();
    });

    tearDown(() {
      Directory.current = originalCwd;
      project.deleteSync(recursive: true);
    });

    Future<int> run({bool show = false}) {
      final input = MapInput(<String, dynamic>{if (show) 'show': true});

      return command.handle(DowelContext.bare(input, output));
    }

    test(
      'default run writes the key to .env and keeps it off stdout',
      () async {
        final code = await run();

        expect(code, 0);
        expect(envFile.readAsStringSync(), matches(keyLine));
        expect(output.content, isNot(contains('base64:')));
        expect(output.content, isNot(contains('APP_KEY')));
        expect(output.content, contains('.env'));
      },
    );

    test('--show prints the key and leaves .env alone', () async {
      envFile.writeAsStringSync('FOO=1\n');

      final code = await run(show: true);

      expect(code, 0);
      expect(output.content, matches(keyLine));
      expect(envFile.readAsStringSync(), 'FOO=1\n');
    });

    test('--show does not create a missing .env', () async {
      await run(show: true);

      expect(envFile.existsSync(), isFalse);
    });

    test('creates .env with a trailing newline when it is missing', () async {
      await run();

      final content = envFile.readAsStringSync();
      expect(content, matches(RegExp('^${keyLine.pattern}\n\$')));
    });

    test('appends after a .env that lacks a trailing newline', () async {
      envFile.writeAsStringSync('FOO=1');

      await run();

      expect(
        envFile.readAsStringSync(),
        matches(RegExp('^FOO=1\n${keyLine.pattern}\n\$')),
      );
    });

    test('appends after a .env that ends with a newline', () async {
      envFile.writeAsStringSync('FOO=1\nBAR=2\n');

      await run();

      expect(
        envFile.readAsStringSync(),
        matches(RegExp('^FOO=1\nBAR=2\n${keyLine.pattern}\n\$')),
      );
    });

    test('replaces an existing APP_KEY and keeps the other lines', () async {
      envFile.writeAsStringSync('FOO=1\nAPP_KEY=old\nBAR=2\n');

      await run();

      final content = envFile.readAsStringSync();
      expect(content, matches(RegExp('^FOO=1\n${keyLine.pattern}\nBAR=2\n\$')));
      expect(content, isNot(contains('old')));
    });

    test('replaces an exported APP_KEY instead of adding a second', () async {
      envFile.writeAsStringSync('FOO=1\nexport APP_KEY=old\n');

      await run();

      final content = envFile.readAsStringSync();
      expect(content, matches(RegExp('^FOO=1\n${keyLine.pattern}\n\$')));
      expect('APP_KEY'.allMatches(content), hasLength(1));
    });

    test('leaves no temporary file behind', () async {
      envFile.writeAsStringSync('FOO=1\n');

      await run();

      final names = project
          .listSync()
          .map((entity) => entity.uri.pathSegments.lastWhere((s) => s != ''))
          .toSet();
      expect(names, <String>{'.env', 'pubspec.yaml'});
    });
  });
}
