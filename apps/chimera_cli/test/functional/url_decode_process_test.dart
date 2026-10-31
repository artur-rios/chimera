// Covers the compilation in setUpAll, which a loaded agent can take past the
// default 30 seconds.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  late String executable;
  setUpAll(() async {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_cli/chimera_cli.dart'),
    );
    final entryPoint = library!.resolve('../bin/chimera.dart').toFilePath();
    final buildDirectory = await Directory.systemTemp.createTemp(
      'chimera-url-cli-',
    );
    addTearDown(() => buildDirectory.delete(recursive: true));
    executable =
        '${buildDirectory.path}/chimera${Platform.isWindows ? '.exe' : ''}';
    // Compile once: each test then runs the executable instead of compiling
    // the CLI from source within its own deadline.
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      entryPoint,
      '-o',
      executable,
    ]);
    expect(compilation.exitCode, 0, reason: compilation.stderr.toString());
  });

  for (final source in ['arguments', 'stdin', 'file']) {
    for (final json in [false, true]) {
      test(
        'GivenExecutable$source${json}_WhenUrlDecoded_ThenExactUnicodeIsSaved',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'chimera-url-process-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final input = File('${directory.path}/input.txt');
          final output = File('${directory.path}/output.txt');
          const encoded = '\uFEFFOlá+%20%F0%9F%99%82%2520\r\n';
          const expected = '\uFEFFOlá+ 🙂%20\r\n';
          await input.writeAsString(encoded, flush: true);
          await output.writeAsString('old bytes', flush: true);
          final process = await Process.start(executable, [
            'url',
            'decode',
            if (source == 'arguments') '--input=$encoded',
            if (source == 'stdin') '--stdin',
            if (source == 'file') '--file=${input.path}',
            '--output=${output.path}',
            if (json) '--json',
          ]);
          final stdoutResult = utf8.decoder.bind(process.stdout).join();
          final stderrResult = utf8.decoder.bind(process.stderr).join();
          if (source == 'stdin') process.stdin.add(utf8.encode(encoded));
          await process.stdin.close();
          expect(await process.exitCode, 0);
          expect(
            await stdoutResult,
            json
                ? '${jsonEncode({'decoded': expected})}\n'
                : 'URL decoded text saved.\n',
          );
          expect(await stderrResult, isEmpty);
          // readAsString strips a leading BOM; byte comparison preserves it.
          expect(await output.readAsBytes(), utf8.encode(expected));
          expect(
            await directory.list().map((entry) => entry.uri).toList(),
            unorderedEquals([input.uri, output.uri]),
          );
        },
      );
    }
  }
  for (final bytes in [
    utf8.encode('private-%GG'),
    [0xc3, 0x28],
  ]) {
    test('GivenMalformedExecutableStdin$bytes'
        '_WhenUrlDecoded_ThenNoOutputFileIsCreated', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-url-invalid-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = File('${directory.path}/output.txt');
      final process = await Process.start(executable, [
        'url',
        'decode',
        '--stdin',
        '--output=${output.path}',
        '--json',
      ]);
      final out = utf8.decoder.bind(process.stdout).join();
      final err = utf8.decoder.bind(process.stderr).join();
      process.stdin.add(bytes);
      await process.stdin.close();
      expect(await process.exitCode, 64);
      expect(await out, isEmpty);
      final message = await err;
      expect(
        ((jsonDecode(message) as Map)['error'] as Map)['code'],
        'url-decode.malformed-input',
      );
      expect(message, isNot(contains('private')));
      expect(await output.exists(), isFalse);
      expect(await directory.list().toList(), isEmpty);
    });
  }
}
