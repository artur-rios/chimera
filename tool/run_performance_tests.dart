import 'dart:io';

Future<void> main() async {
  final repository = Directory.current.absolute.path;
  const dart = 'dart';
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';

  await _run(dart, const <String>[
    'test',
    'tests/performance',
  ], workingDirectory: repository);
  await _run(dart, const <String>[
    'test',
    'test/performance',
  ], workingDirectory: '$repository/apps/chimera_cli');
  await _run(flutter, const <String>[
    'test',
    'test/performance',
  ], workingDirectory: '$repository/apps/chimera_gui');
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Test process failed.',
      result,
    );
  }
}
