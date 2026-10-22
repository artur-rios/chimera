import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/native_scaffolding.dart';

const minimalLibraryOptions = <String, String>{
  'root': 'RootFolder',
  'solution': 'SolutionName',
  'project': 'ProjectName',
  'author': 'Author',
  'description': 'Description',
};
Future<int> runMinimalLibraryCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetScaffoldOperationService? service,
}) async {
  const catalog = MessageCatalog();
  var jsonOutput = args.contains('--json');
  int failure(
    String code,
    String messageKey, {
    FailureKind kind = FailureKind.validation,
    Map<String, Object?> details = const {},
  }) {
    err.writeln(catalog.lookup(localeTag, messageKey));
    if (jsonOutput) {
      out.writeln(jsonEncode({'error': code, 'details': details}));
    }
    return kind == FailureKind.validation
        ? 64
        : kind == FailureKind.access
        ? 74
        : 70;
  }

  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('json', negatable: false)
    ..addOption('parameters');
  for (final flag in minimalLibraryOptions.keys) {
    parser.addOption(flag);
  }
  try {
    final parsed = parser.parse(args);
    jsonOutput = parsed.flag('json');
    if (parsed.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.dotnetInitMinUsage'));
      return 0;
    }
    if (parsed.rest.isNotEmpty) {
      throw const FormatException();
    }
    final fields = <String, String>{
      for (final entry in minimalLibraryOptions.entries)
        if (parsed.wasParsed(entry.key)) entry.value: parsed.option(entry.key)!,
    };
    if (parsed.wasParsed('parameters') && fields.isNotEmpty) {
      return failure(
        'dotnet-minimal-validation',
        'error.dotnetMinimal.validation',
        details: {
          'fields': ['inputMode'],
        },
      );
    }
    String? parametersJson;
    if (parsed.wasParsed('parameters')) {
      final file = File(parsed.option('parameters')!);
      final bytes = <int>[];
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > 262144) {
          return failure(
            'dotnet-minimal-validation',
            'error.dotnetMinimal.validation',
            details: {
              'fields': ['parametersJson'],
            },
          );
        }
        bytes.addAll(chunk);
      }
      try {
        parametersJson = utf8.decode(bytes);
      } on FormatException {
        return failure(
          'dotnet-minimal-validation',
          'error.dotnetMinimal.validation',
          details: {
            'fields': ['parametersJson'],
          },
        );
      }
    }
    final result =
        await (service ??
                MinimalLibraryScaffoldService(const NativeScaffoldWriter()))
            .execute(
              DotnetScaffoldRequest(
                fields: fields,
                parametersJson: parametersJson,
              ),
            );
    return result.fold<int>(
      onSuccess: (value) {
        out.writeln(
          jsonOutput
              ? jsonEncode(value.toJson())
              : '${catalog.lookup(localeTag, 'dotnetMinimal.created')}: ${value.destination}\n${value.templateVersion}\n${value.createdPaths.join('\n')}',
        );
        return 0;
      },
      onFailure: (value) => failure(
        value.code,
        value.messageKey,
        kind: value.kind,
        details: value.details,
      ),
    );
  } on FileSystemException {
    return failure(
      'dotnet-minimal-parameters-read',
      'error.dotnetMinimal.parametersRead',
      kind: FailureKind.access,
    );
  } on FormatException {
    return failure(
      'dotnet-minimal-validation',
      'cli.dotnetInitMinUsage',
      details: {
        'fields': ['arguments'],
      },
    );
  } on Object {
    return failure(
      'dotnet-minimal-failed',
      'error.scaffold.failed',
      kind: FailureKind.processing,
    );
  }
}
