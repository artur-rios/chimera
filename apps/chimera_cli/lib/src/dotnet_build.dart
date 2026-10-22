import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/native_commands.dart';

Future<int> runDotnetBuild(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetBuildService? service,
}) async {
  const catalog = MessageCatalog();
  String message(String key) => catalog.lookup(localeTag, key);
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('json', negatable: false)
    ..addFlag('no-restore', negatable: false, aliases: ['noRestore'])
    ..addOption('solution')
    ..addOption('configuration', allowed: ['Debug', 'Release']);
  ArgResults parsed;
  try {
    parsed = parser.parse(args);
    if (parsed.rest.length > 1) throw const FormatException();
  } on FormatException {
    err.writeln(message('error.dotnet.validation'));
    return 64;
  }
  if (parsed.flag('help')) {
    out.writeln(message('cli.dotnetBuildUsage'));
    return 0;
  }
  final token = OperationCancellation();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in [
    ProcessSignal.sigint,
    if (!Platform.isWindows) ProcessSignal.sigterm,
  ]) {
    subscriptions.add(signal.watch().listen((_) => token.cancel()));
  }
  try {
    final result =
        await (service ??
                const DotnetBuildService(
                  runner: NativeProcessRunner(),
                  discovery: NativeProjectDiscovery(),
                ))
            .build(
              DotnetBuildRequest(
                sourceDirectory: parsed.rest.isEmpty
                    ? './src'
                    : parsed.rest.single,
                solution: parsed.option('solution'),
                configuration: parsed.option('configuration'),
                noRestore: parsed.flag('no-restore'),
              ),
              cancellation: token,
              onDiagnostic: parsed.flag('json') ? null : out.write,
            );
    if (result is ChimeraSuccess<DotnetBuildOutput>) {
      if (parsed.flag('json')) {
        out.writeln(
          jsonEncode({
            'success': true,
            'solution': result.value.solution,
            'configurations': result.value.configurations,
            'exitCode': result.value.exitCode,
            'diagnostics': result.value.diagnostics,
          }),
        );
      } else {
        out.writeln(message('dotnet.succeeded'));
      }
      return 0;
    }
    final failure = result as ChimeraFailure<DotnetBuildOutput>;
    if (parsed.flag('json')) {
      out.writeln(
        jsonEncode({
          'success': false,
          'code': failure.code,
          ...failure.details,
        }),
      );
    } else {
      err.writeln(message(failure.messageKey));
      final choices = failure.details['choices'];
      if (choices is List && choices.isNotEmpty) {
        err.writeln(choices.join(', '));
      }
    }
    if (failure.code == 'dotnet.cancelled') return 130;
    if (failure.kind == FailureKind.validation) return 64;
    final status = failure.details['exitCode'];
    return status is int && status > 0 && status <= 255 ? status : 1;
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
