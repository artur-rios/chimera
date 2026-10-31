import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/validate_release_metadata.dart <file>',
    );
    exitCode = 64;
    return;
  }

  final decoded = jsonDecode(File(arguments.single).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    stderr.writeln('Release metadata must be a JSON object.');
    exitCode = 1;
    return;
  }

  final result = ReleaseMetadataValidator.validate(decoded);
  if (!result.isValid) {
    stderr.writeln(
      'Invalid release metadata fields: ${result.errors.join(', ')}',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('Release metadata: OK');
}
