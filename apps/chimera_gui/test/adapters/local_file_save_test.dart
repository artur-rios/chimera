import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_gui/local_file_save.dart';
import 'package:chimera_platform/transactional_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'chimera-local-save-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  test('GivenPathOnlyChooser_WhenLocalFileSaved_ThenMetadataBeforeExactTransaction', () async {
    var calls = 0;
    final path = '${directory.path}/output.bin';
    expect(
      await saveLocalFile(
        'output.bin',
        Uint8List.fromList([0, 255, 10]),
        'application/octet-stream',
        extensions: const ['bin'],
        chooseLocation: (name, extensions) async {
          calls++;
          expect(name, 'output.bin');
          expect(extensions, ['bin']);
          return path;
        },
      ),
      isTrue,
    );
    expect(calls, 1);
    expect(await File(path).readAsBytes(), [0, 255, 10]);
    expect(directory.listSync().length, 1);
  });
  test(
    'GivenCanceledChooser_WhenLocalSaveRequested_ThenNoTransactionOrArtifacts',
    () async {
      var writes = 0;
      expect(
        await saveLocalFile(
          'output.bin',
          Uint8List(0),
          'application/octet-stream',
          chooseLocation: (_, _) async => null,
          writeTransaction: (_, _) async {
            writes++;
          },
        ),
        isFalse,
      );
      expect(writes, 0);
      expect(directory.listSync(), isEmpty);
    },
  );
  for (final failure in ['partial', 'replace']) {
    test(
      'Given${failure}IoFailure_WhenLocalFileSaved_ThenExistingBytesAndNoPartialArtifacts',
      () async {
        final target = File('${directory.path}/output.bin');
        await target.writeAsBytes([7, 8, 9]);
        final writer = TransactionalFileWriter(
          writeStage: failure == 'partial'
              ? (path, bytes) async {
                  await File(path).writeAsBytes([bytes.first]);
                  throw const FileSystemException('PRIVATE');
                }
              : null,
          operations: FileTransactionOperations(
            rename: failure == 'replace'
                ? (source, path) async {
                    if (source.path.contains('.chimera-stage-')) {
                      throw const FileSystemException('PRIVATE');
                    }
                    await source.rename(path);
                  }
                : null,
          ),
        );
        await expectLater(
          saveLocalFile(
            'output.bin',
            Uint8List.fromList([1, 2]),
            'application/octet-stream',
            chooseLocation: (_, _) async => target.path,
            writeTransaction: writer.write,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(await target.readAsBytes(), [7, 8, 9]);
        expect(directory.listSync().length, 1);
      },
    );
  }
}
