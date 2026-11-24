import 'dart:io';

import 'package:chimera_platform/src/exclusive_directory.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chimera-exclusive-');
  });
  tearDown(() => root.delete(recursive: true));

  for (final name in ['plain', 'with space', 'Olá-🙂']) {
    test(
      'GivenNewPath${name.length}_WhenCreatedExclusively_ThenTheDirectoryExists',
      () {
        final path = '${root.path}${Platform.pathSeparator}$name';

        createDirectoryExclusively(path);

        expect(Directory(path).existsSync(), isTrue);
        expect(root.listSync().single.path, path);
      },
    );
  }

  test(
    'GivenNewPath_WhenCreatedExclusivelyOnPosix_ThenOnlyTheOwnerHasAccess',
    () {
      final path = '${root.path}/private';

      createDirectoryExclusively(path);

      // Created 0700: whatever the umask removes, group and others get none.
      expect(Directory(path).statSync().mode & 0x3f, 0);
    },
    skip: Platform.isWindows ? 'Windows directories have no POSIX mode' : false,
  );

  test(
    'GivenExistingDirectory_WhenCreatedExclusively_ThenItFailsNamingThePath',
    () {
      final path = '${root.path}${Platform.pathSeparator}taken';
      Directory(path).createSync();
      File('$path${Platform.pathSeparator}keep.txt').writeAsStringSync('kept');

      expect(
        () => createDirectoryExclusively(path),
        throwsA(isA<FileSystemException>().having((e) => e.path, 'path', path)),
      );
      expect(
        File('$path${Platform.pathSeparator}keep.txt').readAsStringSync(),
        'kept',
      );
    },
  );

  test('GivenExistingFile_WhenCreatedExclusively_ThenItFails', () {
    final path = '${root.path}${Platform.pathSeparator}file';
    File(path).writeAsStringSync('file');

    expect(
      () => createDirectoryExclusively(path),
      throwsA(isA<FileSystemException>()),
    );
    expect(File(path).readAsStringSync(), 'file');
  });

  test('GivenMissingParent_WhenCreatedExclusively_ThenNothingIsCreated', () {
    final sep = Platform.pathSeparator;
    final path = '${root.path}${sep}missing${sep}child';

    expect(
      () => createDirectoryExclusively(path),
      throwsA(isA<FileSystemException>()),
    );
    expect(root.listSync(), isEmpty);
  });
}
