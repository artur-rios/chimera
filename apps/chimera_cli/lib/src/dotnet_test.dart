import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/dotnet_test_workspace.dart';
import 'package:chimera_platform/native_commands.dart';

Future<int> runDotnetTest(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetTestService? service,
}) async {
  const catalog = MessageCatalog();
  String message(String key) => catalog.lookup(localeTag, key);
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('json', negatable: false);
  ArgResults parsed;
  try {
    parsed = parser.parse(args);
    if (parsed.rest.length > 1) throw const FormatException();
  } on FormatException {
    err.writeln(message('cli.dotnetTestUsage'));
    return 64;
  }
  if (parsed.flag('help')) {
    out.writeln(message('cli.dotnetTestUsage'));
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
                const DotnetTestService(
                  runner: NativeProcessRunner(),
                  workspace: NativeDotnetTestWorkspace(),
                ))
            .test(
              DotnetTestRequest(
                baseDirectory: parsed.rest.isEmpty ? null : parsed.rest.single,
              ),
              cancellation: token,
              onDiagnostic: parsed.flag('json') ? null : out.write,
            );
    if (result is ChimeraSuccess<DotnetTestOutput>) {
      if (parsed.flag('json')) {
        out.writeln(
          jsonEncode({
            'success': true,
            'resultsDirectory': result.value.resultsDirectory,
            'reportDirectory': result.value.reportDirectory,
            'projectsTested': result.value.projectsTested,
            'noTests': result.value.noTests,
            'exitCode': result.value.exitCode,
            'diagnostics': result.value.diagnostics,
          }),
        );
      } else {
        out.writeln(
          message(
            result.value.noTests ? 'dotnet.noTests' : 'dotnet.testSucceeded',
          ),
        );
        out.writeln(result.value.resultsDirectory);
        out.writeln(result.value.reportDirectory);
      }
      return 0;
    }
    final failure = result as ChimeraFailure<DotnetTestOutput>;
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
    if (failure.kind == FailureKind.access) return 74;
    final status = failure.details['exitCode'];
    return status is int && status > 0 && status <= 255 ? status : 1;
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
