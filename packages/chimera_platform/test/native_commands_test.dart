import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_commands.dart';
import 'package:chimera_platform/src/windows_process_helper.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chimera build ');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'GivenQuotedArguments_WhenNativeRun_ThenPreserveArgumentsWithoutShell',
    () async {
      final script = File('${root.path}/arguments.dart');
      await script.writeAsString(
        "import 'dart:convert'; void main(List<String> a) { print(jsonEncode(a)); }",
      );
      final arguments = [
        'space value',
        'quote"value',
        'trailing\\',
        '',
        r'$(echo unwanted)',
        r'one\"two',
      ];
      final result = await const NativeProcessRunner().run(
        NativeCommand(Platform.resolvedExecutable, [script.path, ...arguments]),
      );
      expect(result.exitCode, 0);
      expect(jsonDecode(result.diagnostics), arguments);
    },
  );
  test('GivenBootstrapProgress_WhenEncodedPowerShellRuns_ThenOnlyToolStreamsAndStatusRemain', () async {
    final executable = Platform.isWindows
        ? '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
        : 'pwsh';
    final bootstrap = windowsProcessHelper
        .split(' Add-Type -TypeDefinition')
        .first;
    // Reproduce module-preparation progress during the actual JSON bootstrap.
    // The fixed ownership/Win32 body is covered by the real native runner tests.
    final script =
        r'''
function ConvertFrom-Json {
 process {
  Write-Progress -Activity 'Preparing modules for first use' -Status 'loading'
  $_ | Microsoft.PowerShell.Utility\ConvertFrom-Json
 }
}
''' +
        bootstrap +
        r'''
 [Console]::Out.WriteLine($request.output)
 [Console]::Error.WriteLine($request.error)
 exit [int]$request.status
} catch {
 [Console]::Error.WriteLine('Bootstrap failed.')
 exit 127
}
''';
    Process process;
    try {
      process = await Process.start(executable, [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        base64Encode(
          script.codeUnits.expand((unit) => [unit & 255, unit >> 8]).toList(),
        ),
      ]);
    } on ProcessException {
      if (Platform.isWindows) rethrow;
      markTestSkipped('PowerShell unavailable');
      return;
    }
    final output = process.stdout.transform(utf8.decoder).join();
    final error = process.stderr.transform(utf8.decoder).join();
    process.stdin.writeln(
      jsonEncode({
        'output': 'tool standard output',
        'error': 'tool standard error',
        'status': 7,
      }),
    );
    await process.stdin.close();
    expect(await process.exitCode, 7);
    expect((await output).trim(), 'tool standard output');
    expect((await error).trim(), 'tool standard error');
  });
  test('GivenExitedParent_WhenDescendantSurvives_ThenTreeStillTerminates', () async {
    final descendant = File('${root.path}/descendant.dart');
    final parent = File('${root.path}/parent.dart');
    final marker = File('${root.path}/descendant-alive');
    await descendant.writeAsString(
      "import 'dart:async'; import 'dart:io'; void main(List<String> a) { Timer.periodic(Duration(milliseconds: 50), (_) { File(a[0]).writeAsStringSync('alive'); stdout.writeln('alive'); }); }",
    );
    await parent.writeAsString(
      "import 'dart:io'; Future<void> main(List<String> a) async { await Process.start(Platform.resolvedExecutable, a, mode: ProcessStartMode.inheritStdio); while (!await File(a.last).exists()) { await Future<void>.delayed(Duration(milliseconds: 20)); } exit(0); }",
    );
    final token = OperationCancellation();
    final running = const NativeProcessRunner().run(
      NativeCommand(Platform.resolvedExecutable, [
        parent.path,
        descendant.path,
        marker.path,
      ]),
      cancellation: token,
    );
    while (!await marker.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    token.cancel();
    final result = await running.timeout(const Duration(seconds: 15));
    // Windows also disposes the job at normal parent completion. Linux keeps
    // cancellation active while the descendant holds an inherited output pipe.
    expect(result.cancelled || result.exitCode == 0, isTrue);
    await marker.delete();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(await marker.exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));
  test('GivenNoOrMultipleSolutions_WhenDiscover_ThenTypedChoices', () async {
    const discovery = NativeProjectDiscovery();
    expect(
      (await discovery.find(
        root.path,
        extension: '.sln',
      ) as ChimeraFailure).code,
      'dotnet.noSolution',
    );
    await File('${root.path}/B.sln').writeAsString('');
    await File('${root.path}/A.sln').writeAsString('');
    final ambiguous =
        await discovery.find(root.path, extension: '.sln') as ChimeraFailure;
    expect(ambiguous.details['choices'], ['A.sln', 'B.sln']);
    expect(
      await discovery.find(root.path, extension: '.sln', selection: 'A.sln'),
      isA<ChimeraSuccess<String>>(),
    );
    expect(
      await discovery.find(
        root.path,
        extension: '.sln',
        selection: '../escape.sln',
      ),
      isA<ChimeraFailure<String>>(),
    );
  });
  test('GivenFileOrSymlinkEscape_WhenDiscover_ThenReject', () async {
    final file = File('${root.path}/project.sln');
    await file.writeAsString('');
    expect(
      await const NativeProjectDiscovery().find(file.path, extension: '.sln'),
      isA<ChimeraFailure<String>>(),
    );
    if (!Platform.isWindows) {
      await Link('${root.path}/escape.sln').create('/etc/passwd');
      expect(
        await const NativeProjectDiscovery().find(
          root.path,
          extension: '.sln',
          selection: 'escape.sln',
        ),
        isA<ChimeraFailure<String>>(),
      );
    }
  });
  test(
    'GivenRealChild_WhenFailure_ThenExitAndBoundedRedactedStreams',
    () async {
      final script = File('${root.path}/child.dart');
      await script.writeAsString(
        "import 'dart:io'; void main() { stdout.writeln('token=hidden https://user:pass@host/path?key=secret'); stderr.writeln('failure'); for(var i=0;i<100;i++) { stdout.writeln('diagnostic'); } exit(23); }",
      );
      final chunks = <String>[];
      final result =
          await const NativeProcessRunner(maxDiagnosticCharacters: 100).run(
            NativeCommand(Platform.resolvedExecutable, [script.path]),
            onDiagnostic: chunks.add,
          );
      expect(result.exitCode, 23);
      expect(result.diagnostics.length, lessThanOrEqualTo(100));
      expect(result.diagnostics, isNot(contains('hidden')));
      expect(result.diagnostics, isNot(contains('user:pass')));
      expect(chunks.join(), result.diagnostics);
    },
  );
  test('GivenMissingExecutable_WhenRun_ThenUnavailable', () async {
    final result = await const NativeProcessRunner().run(
      const NativeCommand('chimera-does-not-exist', []),
    );
    expect(result.unavailable, isTrue);
  });
  test('GivenCancelledOperation_WhenRun_ThenTreeStops', () async {
    final grandchild = File('${root.path}/grandchild.dart');
    final child = File('${root.path}/child.dart');
    final marker = File('${root.path}/still-running');
    await grandchild.writeAsString(
      "import 'dart:async'; import 'dart:io'; void main(List<String> a) { Timer.periodic(Duration(milliseconds: 50), (_) { File(a[0]).writeAsStringSync('alive'); }); }",
    );
    await child.writeAsString(
      "import 'dart:io'; Future<void> main(List<String> a) async { final p = await Process.start(Platform.resolvedExecutable, a); stdout.writeln('ready'); await p.exitCode; }",
    );
    final token = OperationCancellation();
    final ready = Completer<void>();
    final running = const NativeProcessRunner().run(
      NativeCommand(Platform.resolvedExecutable, [
        child.path,
        grandchild.path,
        marker.path,
      ]),
      cancellation: token,
      onDiagnostic: (_) {
        if (!ready.isCompleted) ready.complete();
      },
    );
    await ready.future.timeout(const Duration(seconds: 15));
    // Let the descendant write at least once before cancellation.
    while (!await marker.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    token.cancel();
    final result = await running.timeout(const Duration(seconds: 10));
    expect(result.cancelled, isTrue);
    await marker.delete();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(await marker.exists(), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
