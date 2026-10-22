import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/dotnet_tag.dart';
import 'package:chimera_platform/native_commands.dart';

Future<int> runDotnetTag(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetTagOperationService? service,
}) async {
  const catalog = MessageCatalog();
  final parser = ArgParser()
    ..addOption('project')
    ..addFlag('push', negatable: false)
    ..addOption('remote', defaultsTo: 'origin')
    ..addFlag('json', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  StreamSubscription<ProcessSignal>? signal;
  try {
    final options = parser.parse(args);
    if (options.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.dotnetTagUsage'));
      return 0;
    }
    if (options.rest.isNotEmpty) throw const FormatException();
    final cancellation = OperationCancellation();
    signal = ProcessSignal.sigint.watch().listen((_) => cancellation.cancel());
    final result =
        await (service ??
                DotnetTagService(
                  projects: NativeDotnetTagProjectGateway(),
                  runner: const NativeProcessRunner(),
                ))
            .execute(
              DotnetTagRequest(
                project: options.option('project'),
                push: options.flag('push'),
                remote: options.option('remote')!,
              ),
              cancellation: cancellation,
            );
    return result.fold<int>(
      onSuccess: (value) {
        out.writeln(
          options.flag('json')
              ? jsonEncode(value.toJson())
              : '${catalog.lookup(localeTag, value.pushed ? 'dotnetTag.pushed' : 'dotnetTag.created')}: ${value.tag}',
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
        if (failure.code == 'dotnetTag.conflict') return 73;
        if (failure.code == 'dotnetTag.cancelled') return 130;
        return failure.kind == FailureKind.validation
            ? 64
            : failure.kind == FailureKind.resource
            ? 69
            : 70;
      },
    );
  } on FormatException {
    err.writeln(catalog.lookup(localeTag, 'cli.dotnetTagUsage'));
    return 64;
  } on Object {
    err.writeln(catalog.lookup(localeTag, 'error.dotnetTag.command'));
    return 70;
  } finally {
    await signal?.cancel();
  }
}
