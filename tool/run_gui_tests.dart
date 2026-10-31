import 'dart:io';

import 'run_native_gui_tests.dart';

Future<void> main() async {
  final device =
      Platform.environment['CHIMERA_GUI_DEVICE'] ??
      (Platform.isWindows ? 'windows' : 'linux');
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';

  final widgetExitCode = await _run(flutter, const <String>['test', 'test']);
  if (widgetExitCode != 0) {
    exitCode = widgetExitCode;
    return;
  }

  exitCode = await runNativeGuiTests(device: device);
}

Future<int> _run(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: 'apps/chimera_gui',
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}
