import 'dart:io';

const _playwrightImage = 'mcr.microsoft.com/playwright:v1.64.1-noble';

Future<void> main() async {
  final repository = Directory.current.absolute;
  final guiDirectory = Directory(
    '${repository.path}${Platform.pathSeparator}apps'
    '${Platform.pathSeparator}chimera_gui',
  );
  await _run('flutter', <String>[
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn',
  ], workingDirectory: guiDirectory.path);

  await _run('docker', <String>[
    'run',
    '--rm',
    '--ipc=host',
    '--volume',
    '${repository.path}:/work',
    '--mount',
    'type=volume,target=/work/tests/web/node_modules',
    '--workdir',
    '/work/tests/web',
    _playwrightImage,
    'bash',
    '-lc',
    'npm ci && npx playwright test',
  ]);
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
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
      'Command failed with exit code $result.',
      result,
    );
  }
}
