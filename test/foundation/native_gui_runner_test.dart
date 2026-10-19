import 'dart:io';

import 'package:test/test.dart';

import '../../tool/run_native_gui_tests.dart';

void main() {
  late Directory gui;
  setUp(() async {
    gui = await Directory.systemTemp.createTemp('chimera-native-runner-');
    await Directory('${gui.path}/integration_test').create();
  });
  tearDown(() async => gui.delete(recursive: true));
  Future<void> fixture(String name) async {
    final file = File('${gui.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsString('// Tool discovery fixture; not a Flutter test.');
  }

  for (final device in ['windows', 'linux']) {
    test(
      'GivenNestedArbitraryFiles${device}_WhenNativeSuiteRuns_ThenEveryTestUsesSeparateOrderedFlutterProcess',
      () async {
        await fixture('integration_test/zeta_test.dart');
        await fixture('integration_test/nested/alpha_test.dart');
        await fixture('integration_test/notes.dart');
        await fixture('outside_test.dart');
        await fixture('integration_test/nested/ignore_test.txt');
        final commands = <List<String>>[];
        final result = await runNativeGuiTests(
          device: device,
          guiDirectory: gui.path,
          runProcess:
              (executable, arguments, {required workingDirectory}) async {
                expect(
                  executable,
                  Platform.isWindows ? 'flutter.bat' : 'flutter',
                );
                expect(workingDirectory, gui.absolute.path);
                commands.add(arguments);
                return 0;
              },
        );
        expect(result, 0);
        expect(commands, [
          ['test', 'integration_test/nested/alpha_test.dart', '-d', device],
          ['test', 'integration_test/zeta_test.dart', '-d', device],
        ]);
      },
    );
  }
  for (final failedIndex in [0, 1]) {
    test(
      'GivenFailureAt${failedIndex}NativeFile_WhenSuiteRuns_ThenOriginalExitPropagatesAndLaterTestsDoNotLaunch',
      () async {
        for (final name in ['first', 'second', 'third']) {
          await fixture('integration_test/${name}_test.dart');
        }
        var calls = 0;
        final result = await runNativeGuiTests(
          device: 'linux',
          guiDirectory: gui.path,
          runProcess: (_, _, {required workingDirectory}) async =>
              calls++ == failedIndex ? 23 : 0,
        );
        expect(result, 23);
        expect(calls, failedIndex + 1);
      },
    );
  }
  test(
    'GivenNoIntegrationFiles_WhenNativeSuiteRuns_ThenCannotSilentlyPass',
    () async {
      var calls = 0;
      expect(
        await runNativeGuiTests(
          device: 'linux',
          guiDirectory: gui.path,
          runProcess: (_, _, {required workingDirectory}) async {
            calls++;
            return 0;
          },
        ),
        66,
      );
      expect(calls, 0);
    },
  );
  test('GivenMissingIntegrationDirectory_WhenNativeSuiteRuns_ThenCannotSilentlySkipCoverage', () async {
    await Directory('${gui.path}/integration_test').delete();
    var calls = 0;
    expect(
      await runNativeGuiTests(
        device: 'linux',
        guiDirectory: gui.path,
        runProcess: (_, _, {required workingDirectory}) async {
          calls++;
          return 0;
        },
      ),
      66,
    );
    expect(calls, 0);
  });
  test(
    'GivenUnsupportedNativeDevice_WhenSuiteRuns_ThenRejectsBeforeLaunch',
    () async {
      await fixture('integration_test/available_test.dart');
      var calls = 0;
      expect(
        await runNativeGuiTests(
          device: 'android',
          guiDirectory: gui.path,
          runProcess: (_, _, {required workingDirectory}) async {
            calls++;
            return 0;
          },
        ),
        64,
      );
      expect(calls, 0);
    },
  );
}
