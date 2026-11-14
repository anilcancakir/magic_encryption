/// The CLI surface of `magic_encryption`, kept apart from the runtime barrel.
///
/// The dowel dispatcher is a pure Dart process with no engine behind it, so
/// nothing reachable from here may import the UI toolkit or this package's
/// runtime barrel: only `dart:` libraries and the dowel barrel. The rule is
/// asserted in `test/cli/encryption_dowel_provider_test.dart`.
library;

export 'src/cli/encryption_dowel_provider.dart';
