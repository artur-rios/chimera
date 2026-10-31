import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runChimera(
    arguments,
    localeTag: 'en',
    out: stdout,
    err: stderr,
  );
}
