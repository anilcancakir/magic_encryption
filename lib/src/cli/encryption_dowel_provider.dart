import 'package:dowel/dowel.dart';

import 'commands/key_generate_command.dart';

/// The dowel provider for Magic Encryption.
///
/// Named `<PascalCase package>DowelProvider` because that is the class the
/// dowel `plugin:install` command registers from `package:magic_encryption/cli.dart`.
class MagicEncryptionDowelProvider extends DowelServiceProvider {
  @override
  String get providerName => 'magic_encryption';

  @override
  List<DowelCommand> commands() => <DowelCommand>[KeyGenerateCommand()];
}
