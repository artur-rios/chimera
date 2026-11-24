import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'GivenPendingTagOperation_WhenSigtermReceived_ThenCancellationReturns130',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-tag-signal-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var workspace = Directory.current.absolute;
      while (!File('${workspace.path}/.dart_tool/package_config.json')
          .existsSync()) {
        if (workspace.parent.path == workspace.path) {
          throw StateError('Workspace configuration missing');
        }
        workspace = workspace.parent;
      }
      final probe = File('${directory.path}/probe.dart');
      await probe.writeAsString(r'''
import 'dart:io';
import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
Future<void> main() async {
  exitCode=await runChimera(['dotnet','tag'],localeTag:'en',out:stdout,err:stderr,dotnetTagService:Pending());
}
class Pending implements DotnetTagOperationService {
  Future<ChimeraResult<DotnetTagOutput>> execute(DotnetTagRequest request,{OperationCancellation? cancellation}) async {
    stdout.writeln('READY');
    await cancellation!.whenCancelled;
    return const ChimeraFailure(kind:FailureKind.processing,code:'dotnetTag.cancelled',messageKey:'error.dotnetTag.cancelled');
  }
}
''');
      final process = await Process.start(Platform.resolvedExecutable, [
        '--packages=${workspace.path}/.dart_tool/package_config.json',
        probe.path,
      ]);
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final stderr = process.stderr.transform(utf8.decoder).join();
      final ready = Completer<void>();
      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line == 'READY' && !ready.isCompleted) ready.complete();
          });
      addTearDown(lines.cancel);
      // The probe compiles chimera_cli and chimera_core from source before it
      // prints READY, which takes well over 30 seconds on a busy CI agent. A
      // probe that exits first (a compile error, say) fails at once with its
      // stderr instead of waiting out the timeout.
      const readySignal = Object();
      final started =
          await Future.any<Object?>([
            ready.future.then((_) => readySignal),
            process.exitCode,
          ]).timeout(
            const Duration(minutes: 3),
            onTimeout: () async {
              process.kill(ProcessSignal.sigkill);
              fail(
                'The probe printed no READY within 3 minutes:\n'
                '${await stderr}',
              );
            },
          );
      if (!identical(started, readySignal)) {
        fail('The probe exited with $started before READY:\n${await stderr}');
      }
      process.kill(ProcessSignal.sigterm);
      expect(
        await process.exitCode.timeout(const Duration(seconds: 10)),
        130,
        reason: await stderr,
      );
    },
    skip: Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
