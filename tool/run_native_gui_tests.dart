import 'dart:io';

typedef NativeGuiProcessRunner = Future<int> Function(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
});

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/run_native_gui_tests.dart windows|linux',
    );
    exitCode = 64;
    return;
  }
  exitCode = await runNativeGuiTests(device: arguments.single);
}

/// Launch each discovered integration file in a fresh Flutter tool process.
///
/// Flutter's desktop integration runner can fail its second app launch when
/// multiple files share one invocation (flutter/flutter-intellij#8484). Keep
/// every file, use deterministic order, and return the first failing exit code.
Future<int> runNativeGuiTests({
  required String device,
  String guiDirectory = 'apps/chimera_gui',
  NativeGuiProcessRunner? runProcess,
}) async {
  if (device != 'windows' && device != 'linux') {
    stderr.writeln('The native GUI device must be windows or linux.');
    return 64;
  }
  final gui = Directory(guiDirectory).absolute;
  final integration = Directory(
    '${gui.path}${Platform.pathSeparator}integration_test',
  );
  if (!integration.existsSync()) {
    stderr.writeln('The native GUI integration test directory is missing.');
    return 66;
  }
  final paths =
      integration
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('_test.dart'))
          .map(
            (file) => file.path
                .substring(gui.path.length + 1)
                .replaceAll(Platform.pathSeparator, '/'),
          )
          .toList()
        ..sort();
  if (paths.isEmpty) {
    stderr.writeln('No native GUI integration test files were found.');
    return 66;
  }
  final launch = runProcess ?? _runFlutter;
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  for (final path in paths) {
    final result = await launch(flutter, [
      'test',
      path,
      '-d',
      device,
    ], workingDirectory: gui.path);
    if (result != 0) return result;
  }
  return 0;
}

Future<int> _runFlutter(
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
  return process.exitCode;
}
