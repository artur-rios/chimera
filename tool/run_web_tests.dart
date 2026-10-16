import 'dart:io';

const _playwrightImage = 'mcr.microsoft.com/playwright:v1.64.1-noble';

Future<void> main() async {
  final repository = Directory.current.absolute;
  final guiDirectory = Directory(
    '${repository.path}${Platform.pathSeparator}apps'
    '${Platform.pathSeparator}chimera_gui',
  );
  final webTestsDirectory = Directory(
    '${repository.path}${Platform.pathSeparator}tests'
    '${Platform.pathSeparator}web',
  );

  await _run('flutter', <String>[
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn',
  ], workingDirectory: guiDirectory.path);

  if (Platform.isWindows) {
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
    return;
  }

  await _run('npm', <String>['ci'], workingDirectory: webTestsDirectory.path);
  await _run('npx', <String>[
    'playwright',
    'test',
  ], workingDirectory: webTestsDirectory.path);
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
