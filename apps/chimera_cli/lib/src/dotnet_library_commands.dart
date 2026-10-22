import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/native_scaffolding.dart';

const dotnetRepositoryFlagFields = {
  'root': 'RootFolder',
  'solution': 'SolutionName',
  'project': 'ProjectName',
  'author': 'Author',
  'company': 'Company',
  'description': 'Description',
  'version': 'Version',
  'package-id': 'PackageId',
  'repository-url': 'RepositoryUrl',
};

Future<int> runDotnetLibraryCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetScaffoldOperationService? service,
  Future<String> Function(String path)? readFile,
}) async {
  const catalog = MessageCatalog();
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('json', negatable: false)
    ..addOption('parameters');
  for (final flag in dotnetRepositoryFlagFields.keys) {
    parser.addOption(
      flag,
      aliases: switch (flag) {
        'package-id' => ['packageId'],
        'repository-url' => ['repositoryUrl'],
        _ => const [],
      },
    );
  }
  try {
    final parsed = parser.parse(args);
    if (parsed.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.dotnetLibraryUsage'));
      return 0;
    }
    if (parsed.rest.isNotEmpty) throw const FormatException();
    final fields = <String, String>{
      for (final entry in dotnetRepositoryFlagFields.entries)
        if (parsed.wasParsed(entry.key)) entry.value: parsed.option(entry.key)!,
    };
    if (parsed.wasParsed('parameters') && fields.isNotEmpty) {
      err.writeln(catalog.lookup(localeTag, 'error.dotnetScaffold.mixedMode'));
      return 64;
    }
    String? parameters;
    if (parsed.wasParsed('parameters')) {
      try {
        final path = parsed.option('parameters')!;
        if (readFile != null) {
          parameters = await readFile(path);
        } else {
          final file = File(path);
          if (await file.length() > 65536) throw const FormatException();
          parameters = await file.readAsString();
        }
      } on Object {
        err.writeln(
          catalog.lookup(localeTag, 'error.dotnetScaffold.inputAccess'),
        );
        return 74;
      }
    }
    final result =
        await (service ??
                NugetLibraryScaffoldService(const NativeScaffoldWriter()))
            .execute(
              DotnetScaffoldRequest(fields: fields, parametersJson: parameters),
            );
    return result.fold<int>(
      onSuccess: (output) {
        out.writeln(
          parsed.flag('json')
              ? jsonEncode(output.toJson())
              : '${catalog.lookup(localeTag, 'dotnetScaffold.created')}: ${output.destination}\n${output.templateVersion}\n${output.createdPaths.join('\n')}',
        );
        return 0;
      },
      onFailure: (failure) {
        err.writeln(catalog.lookup(localeTag, failure.messageKey));
        final fields = failure.details['fields'];
        if (fields is List) {
          for (final field in fields.whereType<String>()) {
            err.writeln(
              catalog.lookup(localeTag, 'dotnetScaffold.field.$field'),
            );
          }
        }
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
    err.writeln(catalog.lookup(localeTag, 'cli.dotnetLibraryUsage'));
    return 64;
  } on Object {
    err.writeln(catalog.lookup(localeTag, 'error.scaffold.failed'));
    return 74;
  }
}
