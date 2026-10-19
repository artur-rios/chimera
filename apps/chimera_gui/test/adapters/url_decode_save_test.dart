import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_gui/url_decode_page.dart';
import 'package:chimera_platform/transactional_file_writer.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

final class _SavePathPlatform extends FileSelectorPlatform {
  _SavePathPlatform(this.path);
  final String? path;
  int calls = 0;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    SaveDialogOptions options = const SaveDialogOptions(),
    List<XTypeGroup>? acceptedTypeGroups,
  }) async {
    calls++;
    expect(options.suggestedName, 'chimera-url-decoded.txt');
    expect(acceptedTypeGroups!.single.extensions, ['txt']);
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'chimera-save-boundary-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  test('GivenDefaultUrlDecodeSaver_WhenNativePathSelected_ThenExactDecodedTextReplacesOnlyAfterStaging', () async {
    final target = File('${directory.path}/decoded.txt');
    await target.writeAsString('previous');
    final platform = _SavePathPlatform(target.path);
    final previous = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = platform;
    addTearDown(() => FileSelectorPlatform.instance = previous);
    expect(
      await saveUrlDecodeFile(
        'chimera-url-decoded.txt',
        Uint8List.fromList([97, 98, 99, 10]),
        'text/plain; charset=utf-8',
      ),
      isTrue,
    );
    expect(await target.readAsBytes(), [97, 98, 99, 10]);
    expect(platform.calls, 1);
    expect(directory.listSync().length, 1);
  });
  test('GivenDefaultUrlDecodeSaveCanceled_WhenDialogReturns_ThenNoWriteOrArtifacts', () async {
    final platform = _SavePathPlatform(null);
    final previous = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = platform;
    addTearDown(() => FileSelectorPlatform.instance = previous);
    expect(
      await saveUrlDecodeFile(
        'chimera-url-decoded.txt',
        Uint8List.fromList([1]),
        'text/plain',
      ),
      isFalse,
    );
    expect(directory.listSync(), isEmpty);
  });
  for (final existing in [false, true]) {
    for (final failure in ['partial', 'replace', 'backup', 'reserve']) {
      if (!existing && failure == 'backup') continue;
      test(
        'Given${existing}Target${failure}Failure_WhenDefaultUrlDecodeSaved_ThenOriginalBytesAndNoPartialArtifacts',
        () async {
          final target = File('${directory.path}/decoded.txt');
          if (existing) await target.writeAsBytes([8, 9, 10]);
          final platform = _SavePathPlatform(target.path);
          final previous = FileSelectorPlatform.instance;
          FileSelectorPlatform.instance = platform;
          addTearDown(() => FileSelectorPlatform.instance = previous);
          var reached = false;
          Never fail() {
            reached = true;
            throw const FileSystemException('PRIVATE', 'PRIVATE');
          }

          final writer = TransactionalFileWriter(
            writeStage: failure == 'partial'
                ? (path, bytes) async {
                    await File(path).writeAsBytes([bytes.first]);
                    fail();
                  }
                : null,
            operations: FileTransactionOperations(
              tryReserve: failure == 'reserve'
                  ? (candidate) async => fail()
                  : null,
              copy: failure == 'backup'
                  ? (source, destination) async {
                      await destination.writeAsBytes([8]);
                      fail();
                    }
                  : null,
              rename: failure == 'replace'
                  ? (source, path) async {
                      if (source.path.contains('.chimera-stage-')) fail();
                      await source.rename(path);
                    }
                  : null,
            ),
          );
          await expectLater(
            saveUrlDecodeFile(
              'chimera-url-decoded.txt',
              Uint8List.fromList([1, 2, 3]),
              'text/plain',
              writeTransaction: writer.write,
            ),
            throwsA(isA<FileSystemException>()),
          );
          expect(reached, isTrue);
          expect(await target.exists(), existing);
          if (existing) expect(await target.readAsBytes(), [8, 9, 10]);
          expect(directory.listSync().length, existing ? 1 : 0);
        },
      );
    }
  }
  test(
    'GivenPathChooser_WhenSaveRuns_ThenChooserReceivesMetadataOnlyBeforeWriter',
    () async {
      var calls = 0;
      expect(
        await saveUrlDecodeFile(
          'private.txt',
          Uint8List.fromList([1, 2]),
          'text/plain',
          chooseLocation: (name, extensions) async {
            calls++;
            expect(name, 'private.txt');
            expect(extensions, ['txt']);
            return '${directory.path}/result.txt';
          },
          writeTransaction: (path, bytes) async {
            expect(calls, 1);
            expect(bytes, [1, 2]);
            await const TransactionalFileWriter().write(path, bytes);
          },
        ),
        isTrue,
      );
      expect(await File('${directory.path}/result.txt').readAsBytes(), [1, 2]);
    },
  );
}
