import 'dart:io';

import 'package:chimera_platform/transactional_file_writer.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File target;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('chimera-transaction-');
    target = File('${directory.path}/result.txt');
  });
  tearDown(() => directory.delete(recursive: true));

  List<String> names() =>
      directory.listSync().map((entry) => entry.uri.pathSegments.last).toList()
        ..sort();

  bool isBackup(File file) =>
      file.uri.pathSegments.last.startsWith('.chimera-backup-');

  test('GivenNoTarget_WhenWritten_ThenExactBytesAndNoSiblingsRemain', () async {
    await const TransactionalFileWriter().write(target.path, [0, 255, 10]);

    expect(await target.readAsBytes(), [0, 255, 10]);
    expect(names(), ['result.txt']);
  });

  test(
    'GivenExistingTarget_WhenWritten_ThenItIsReplacedAndNoBackupRemains',
    () async {
      await target.writeAsString('previous');

      await const TransactionalFileWriter().write(target.path, [1, 2]);

      expect(await target.readAsBytes(), [1, 2]);
      expect(names(), ['result.txt']);
    },
  );

  test(
    'GivenEmptyBytes_WhenWritten_ThenAnEmptyTargetReplacesThePrevious',
    () async {
      await target.writeAsString('previous');

      await const TransactionalFileWriter().write(target.path, const []);

      expect(await target.readAsBytes(), isEmpty);
      expect(names(), ['result.txt']);
    },
  );

  test('GivenFailingStageWriter_WhenWritten_ThenTargetIsUntouchedAndStageIsRemoved', () async {
    await target.writeAsString('previous');
    final writer = TransactionalFileWriter(
      writeStage: (path, bytes) async {
        await File(path).writeAsBytes([9]);
        throw const FileSystemException('disk full');
      },
    );

    await expectLater(
      writer.write(target.path, [1]),
      throwsA(isA<FileSystemException>()),
    );

    expect(await target.readAsString(), 'previous');
    expect(names(), ['result.txt']);
  });

  test('GivenStageWriterThatLeavesNoStage_WhenWritten_ThenItFailsBeforeTouchingTarget', () async {
    await target.writeAsString('previous');
    final writer = TransactionalFileWriter(
      writeStage: (path, bytes) => File(path).delete(),
    );

    await expectLater(
      writer.write(target.path, [1]),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.message,
          'message',
          'Output stage was not created',
        ),
      ),
    );

    expect(await target.readAsString(), 'previous');
    expect(names(), ['result.txt']);
  });

  test('GivenFailingBackupCopy_WhenWritten_ThenTargetIsUntouchedAndNoSiblingsRemain', () async {
    await target.writeAsString('previous');
    final writer = TransactionalFileWriter(
      operations: FileTransactionOperations(
        copy: (source, destination) async {
          await destination.writeAsString('partial');
          throw const FileSystemException('copy failed');
        },
      ),
    );

    await expectLater(
      writer.write(target.path, [1]),
      throwsA(isA<FileSystemException>()),
    );

    expect(await target.readAsString(), 'previous');
    expect(names(), ['result.txt']);
  });

  for (final existing in [false, true]) {
    test('GivenFailingReplacement${existing ? 'OfExistingTarget' : ''}'
        '_WhenWritten_ThenPriorStateIsRestoredAndTheErrorIsRethrown', () async {
      if (existing) await target.writeAsString('previous');
      final failure = const FileSystemException('rename failed');
      final writer = TransactionalFileWriter(
        operations: FileTransactionOperations(
          rename: (source, destinationPath) async {
            if (destinationPath == target.path && !isBackup(source)) {
              throw failure;
            }
            await source.rename(destinationPath);
          },
        ),
      );

      await expectLater(writer.write(target.path, [1]), throwsA(same(failure)));

      if (existing) {
        expect(await target.readAsString(), 'previous');
        expect(names(), ['result.txt']);
      } else {
        expect(await target.exists(), isFalse);
        expect(names(), isEmpty);
      }
    });
  }

  test(
    'GivenFailingBackupRemoval_WhenWritten_ThenPreviousBytesAreRestored',
    () async {
      await target.writeAsString('previous');
      final failure = const FileSystemException('backup is locked');
      final writer = TransactionalFileWriter(
        operations: FileTransactionOperations(
          delete: (file) async {
            if (isBackup(file)) throw failure;
            await file.delete();
          },
        ),
      );

      await expectLater(writer.write(target.path, [1]), throwsA(same(failure)));

      expect(await target.readAsString(), 'previous');
      expect(names(), ['result.txt']);
    },
  );

  test(
    'GivenTakenSiblingNames_WhenWritten_ThenTheNextFreeNameIsReserved',
    () async {
      final candidates = <String>[];
      final writer = TransactionalFileWriter(
        operations: FileTransactionOperations(
          tryReserve: (candidate) async {
            candidates.add(candidate.path);
            if (candidates.length < 3) return false;
            await candidate.create(exclusive: true);
            return true;
          },
        ),
      );

      await writer.write(target.path, [7]);

      expect(candidates, hasLength(3));
      expect(candidates.toSet(), hasLength(3));
      for (final path in candidates) {
        expect(File(path).parent.path, directory.path);
        expect(
          File(path).uri.pathSegments.last,
          matches(RegExp('^\\.chimera-stage-$pid-\\d+\$')),
        );
      }
      expect(await target.readAsBytes(), [7]);
      expect(names(), ['result.txt']);
    },
  );

  test(
    'GivenFailingReservation_WhenWritten_ThenTheErrorReturnsBeforeAnyWrite',
    () async {
      var stages = 0;
      final writer = TransactionalFileWriter(
        writeStage: (path, bytes) async => stages++,
        operations: FileTransactionOperations(
          tryReserve: (_) =>
              throw const FileSystemException('permission denied'),
        ),
      );

      await expectLater(
        writer.write(target.path, [1]),
        throwsA(isA<FileSystemException>()),
      );

      expect(stages, 0);
      expect(names(), isEmpty);
    },
  );
}
