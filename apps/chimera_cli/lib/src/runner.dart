import 'package:args/args.dart';
import 'package:chimera_l10n/chimera_l10n.dart';

Future<int> runChimera(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
}) async {
  const catalog = MessageCatalog();
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);

  try {
    final parsed = parser.parse(args);
    if (parsed.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.usage'));
      return 0;
    }

    if (parsed.rest.isEmpty) {
      err.writeln(catalog.lookup(localeTag, 'cli.noCommand'));
      return 64;
    }

    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  } on FormatException {
    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  }
}
