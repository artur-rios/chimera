import 'dart:convert';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/native_scaffolding.dart';

Future<int> runProjectCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  ScaffoldOperationService? service,
}) async {
  const catalog = MessageCatalog();
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('json', negatable: false);
  try {
    if (args.isEmpty || args.first != 'from-template') {
      throw const FormatException();
    }
    final parsed = parser.parse(args.sublist(1));
    if (parsed.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.projectTemplateUsage'));
      return 0;
    }
    if (parsed.rest.length != 1) throw const FormatException();
    final result =
        await (service ?? ScaffoldService(const NativeScaffoldWriter()))
            .execute(ScaffoldRequest(destination: parsed.rest.single));
    return result.fold(
      onSuccess: (value) {
        out.writeln(
          parsed.flag('json')
              ? jsonEncode(value.toJson())
              : '${catalog.lookup(localeTag, 'scaffold.created')}: ${value.destination}\n${value.templateVersion}',
        );
        return 0;
      },
      onFailure: (failure) {
        err.writeln(catalog.lookup(localeTag, failure.messageKey));
        if (parsed.flag('json')) {
          out.writeln(
            jsonEncode({'error': failure.code, 'details': failure.details}),
          );
        }
        return failure.kind == FailureKind.validation
            ? 64
            : failure.kind == FailureKind.access
            ? 74
            : 70;
      },
    );
  } on FormatException {
    err.writeln(catalog.lookup(localeTag, 'cli.projectTemplateUsage'));
    return 64;
  } on Object {
    err.writeln(catalog.lookup(localeTag, 'error.scaffold.failed'));
    return 74;
  }
}
