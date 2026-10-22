import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

import 'support/windows_short_path.dart';

void main() {
  test(
    'GivenNativeShortPath_WhenBufferGrows_ThenExactUnicodePathIsReturned',
    () {
      const path = r'C:\Projects with spaces\Δ project.csproj';
      const alias = r'C:\PROJEC~1\PROJEC~1.CSP';
      var calls = 0;
      final result = queryWindowsShortPath(
        path,
        getShortPath: (input, output, capacity) {
          expect(input.toDartString(), path);
          calls++;
          if (capacity == 0) {
            expect(output, nullptr);
            return 4;
          }
          if (capacity < alias.length + 1) return alias.length + 1;
          output.cast<Uint16>().asTypedList(capacity)
            ..setAll(0, alias.codeUnits)
            ..[alias.length] = 0;
          return alias.length;
        },
        getLastError: () =>
            fail('No Windows error should be queried on success.'),
      );
      expect(result, alias);
      expect(calls, 3);
    },
  );

  test(
    'GivenWindowsUnicodeAndShellCharacters_WhenQueried_ThenSameFileIsReturned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera Δ & % alias-',
      );
      try {
        final file = await File(
          '${directory.path}/Application Ω & % sample.csproj',
        ).create();
        final alias = windowsShortPath(file.path);
        expect(FileSystemEntity.identicalSync(alias, file.path), isTrue);
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'GivenNativeShortPathFailure_WhenQueried_ThenErrorAndInputAreReported',
    () {
      for (final failAt in [1, 2]) {
        var calls = 0;
        expect(
          () => queryWindowsShortPath(
            r'C:\missing project.csproj',
            getShortPath: (_, _, _) => ++calls == failAt ? 0 : 128,
            getLastError: () => 123,
          ),
          throwsA(
            isA<FileSystemException>()
                .having((error) => error.osError?.errorCode, 'error code', 123)
                .having(
                  (error) => error.path,
                  'input path',
                  r'C:\missing project.csproj',
                ),
          ),
        );
      }
    },
  );
}
