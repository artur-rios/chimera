import 'dart:convert';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/native_scaffolding.dart';

Future<int> runDotnetProjectCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetProjectOperationService? service,
}) async {
  const catalog = MessageCatalog();
  final parser = ArgParser()
    ..addOption('name')
    ..addOption('parent', defaultsTo: '.')
    ..addFlag('minimal', negatable: false)
    ..addFlag('nuget', negatable: false)
    ..addFlag('json', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final options = parser.parse(args);
    if (options.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.dotnetProjectUsage'));
      return 0;
    }
    if (options.rest.isNotEmpty) {
      throw const FormatException();
    }
    final result =
        await (service ?? const DotnetProjectService(NativeScaffoldWriter()))
            .execute(
              DotnetProjectRequest(
                name: options.option('name') ?? '',
                parentDirectory: options.option('parent')!,
                minimal: options.flag('minimal'),
                nuget: options.flag('nuget'),
              ),
            );
    return result.fold<int>(
      onSuccess: (value) {
        out.writeln(
          options.flag('json')
              ? jsonEncode(value.toJson())
              : '${catalog.lookup(localeTag, 'scaffold.created')}: ${value.scaffold.createdPaths.single}\n${catalog.lookup(localeTag, value.mode == 'nuget' ? 'dotnetProject.nuget' : 'dotnetProject.minimal')}',
        );
        return 0;
      },
      onFailure: (failure) {
        err.writeln(catalog.lookup(localeTag, failure.messageKey));
        if (options.flag('json')) {
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
    err.writeln(catalog.lookup(localeTag, 'cli.dotnetProjectUsage'));
    return 64;
  } on Object {
    err.writeln(catalog.lookup(localeTag, 'error.scaffold.failed'));
    return 74;
  }
}
