import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart' show Timeout;

/// How long a suite waits for a program another suite is compiling.
///
/// `dart compile exe` of the CLI takes well over a minute on a busy CI agent;
/// the bound only turns a compiler that never finishes into a failure.
const Duration compilationBudget = Duration(minutes: 5);

/// The timeout of a test, or a setUpAll's group, that asks for a compiled
/// program: the compilation, or the wait for it, then the test itself.
const Timeout compilationTimeout = Timeout(Duration(minutes: 6));

/// The chimera executable, compiled from `bin/chimera.dart` once per test run.
///
/// Every functional suite that checks the native executable shares this one
/// build instead of compiling the CLI within its own deadline.
Future<String> compiledChimera() => _compiledOnce('chimera', (_) async {
  final library = (await Isolate.resolvePackageUri(
    Uri.parse('package:chimera_cli/chimera_cli.dart'),
  ))!;
  return File.fromUri(library.resolve('../bin/chimera.dart')).path;
});

/// The chimera executable for [locale]: `bin/chimera.dart` itself for `en`,
/// the locale the product entrypoint passes, else an entrypoint that passes
/// [locale] to the same `runChimera`, each compiled once per test run.
Future<String> compiledChimeraIn(String locale) => locale == 'en'
    ? compiledChimera()
    : compiledProgram(
        'chimera-$locale',
        "import 'dart:io';\n"
            "import 'package:chimera_cli/chimera_cli.dart';\n"
            'Future<void> main(List<String> arguments) async {\n'
            '  exitCode = await runChimera(arguments, '
            "localeTag: '$locale', out: stdout, err: stderr);\n"
            '}\n',
      );

/// [source], a Dart program that may import the workspace's packages,
/// compiled to a native executable once per test run under [name].
Future<String> compiledProgram(String name, String source) =>
    _compiledOnce(name, (directory) async {
      final entrypoint = File('${directory.path}/$name.dart');
      await entrypoint.writeAsString(source, flush: true);
      return entrypoint.path;
    });

/// `dart test` runs every suite in an isolate of one process, so the program
/// is kept in a directory of that process: the first suite to ask compiles
/// it, the others wait for the file, and the next run starts afresh.
Future<String> _compiledOnce(
  String name,
  Future<String> Function(Directory directory) entrypointIn,
) async {
  final directory = await _runDirectory();
  final suffix = Platform.isWindows ? '.exe' : '';
  final executable = File('${directory.path}/$name$suffix');
  final failure = File('${directory.path}/$name.failed');
  final lock = File('${directory.path}/$name.lock');
  try {
    await lock.create(exclusive: true);
  } on FileSystemException {
    return _awaitCompilation(executable, failure);
  }
  try {
    final entrypoint = await entrypointIn(directory);
    final staged = '${directory.path}/$name.staged$suffix';
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--packages=${Isolate.packageConfigSync!.toFilePath()}',
      entrypoint,
      '-o',
      staged,
    ]);
    if (compilation.exitCode != 0) {
      throw StateError(
        'dart compile exe $entrypoint exited ${compilation.exitCode}:\n'
        '${compilation.stdout}${compilation.stderr}',
      );
    }
    // The rename is atomic: a waiting suite never runs a partial file.
    await File(staged).rename(executable.path);
    return executable.path;
  } catch (error) {
    // The waiting suites fail with the cause instead of waiting it out.
    await failure.writeAsString('$error', flush: true);
    rethrow;
  }
}

Future<String> _awaitCompilation(File executable, File failure) async {
  final deadline = DateTime.now().add(compilationBudget);
  while (!await executable.exists()) {
    if (await failure.exists()) {
      throw StateError(await failure.readAsString());
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(
        'Another suite did not finish compiling ${executable.path}',
        compilationBudget,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return executable.path;
}

Future<Directory> _runDirectory() async {
  final directory = Directory('${Directory.systemTemp.path}/$_prefix$pid');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
    await _removeStaleRuns(directory);
  }
  return directory;
}

/// Directories of earlier runs: a run cannot remove its own when it ends, as
/// `dart test` has no hook after the last suite.
Future<void> _removeStaleRuns(Directory current) async {
  final cutoff = DateTime.now().subtract(const Duration(hours: 6));
  try {
    await for (final entry in Directory.systemTemp.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is Directory &&
          name.startsWith(_prefix) &&
          entry.path != current.path &&
          (await entry.stat()).modified.isBefore(cutoff)) {
        await entry.delete(recursive: true);
      }
    }
  } on FileSystemException {
    // Another run's directory, still in use or already gone: it is only
    // housekeeping, so the next run tries again.
  }
}

const String _prefix = 'chimera-test-programs-';
