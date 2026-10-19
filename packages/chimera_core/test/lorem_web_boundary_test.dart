import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test('GivenJavaScriptAllocationAndIntegerBoundaries_WhenCompiledAndRun_ThenTypedExactResultsWithoutHugeAllocation', () async {
    final library = (await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_core/chimera_core.dart'),
    ))!;
    final source = File.fromUri(
      library.resolve('../test/fixtures/lorem_web_probe.dart'),
    );
    final config = File.fromUri(
      library.resolve('../../../.dart_tool/package_config.json'),
    );
    final directory = await Directory.systemTemp.createTemp(
      'lorem-js-boundary-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final output = '${directory.path}/probe.js';
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'js',
      '--packages=${config.path}',
      '-O1',
      source.path,
      '-o',
      output,
    ]);
    expect(
      compilation.exitCode,
      0,
      reason: '${compilation.stdout}\n${compilation.stderr}',
    );
    final run = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; globalThis.failAllocation = () => "x".repeat(2 ** 30); require(process.argv[1]);',
      output,
    ]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(jsonDecode(run.stdout as String), {
      'checks': 19,
      'status': 'passed',
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
