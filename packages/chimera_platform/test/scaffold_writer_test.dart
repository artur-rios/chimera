import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(
    () async =>
        parent = await Directory.systemTemp.createTemp('chimera-scaffold-'),
  );
  tearDown(() async => parent.delete(recursive: true));
  test(
    'GivenCanonicalSnapshot_WhenCreatedOffline_ThenEveryByteMatches',
    () async {
      final destination = '${parent.path}/new';
      final result = await ScaffoldService(const NativeScaffoldWriter())
          .execute(ScaffoldRequest(destination: destination));
      expect(result, isA<ChimeraSuccess<ScaffoldOutput>>());
      final projectTemplate = ScaffoldService(const NativeScaffoldWriter())
          .template;
      for (final entry in projectTemplate.files.entries) {
        expect(
          await File('$destination/${entry.key}').readAsBytes(),
          utf8.encode(entry.value),
        );
      }
      expect(
        Directory(destination)
            .listSync(recursive: true)
            .whereType<File>()
            .length,
        projectTemplate.files.length,
      );
    },
  );
  test(
    'GivenWriteFailure_WhenCreating_ThenOnlyOwnedPartialOutputIsRemoved',
    () async {
      final destination = '${parent.path}/new';
      final result = await ScaffoldService(
        NativeScaffoldWriter(
          writeFile: (file, bytes) async {
            throw const FileSystemException('denied');
          },
        ),
      ).execute(ScaffoldRequest(destination: destination));
      expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
      expect(await Directory(destination).exists(), isFalse);
    },
  );
  test(
    'GivenSymlinkDestination_WhenCreating_ThenOutsideTargetSurvives',
    () async {
      final outside = Directory('${parent.path}/outside')..createSync();
      final destination = '${parent.path}/linked';
      try {
        await Link(destination).create(outside.path);
      } on FileSystemException {
        if (Platform.isWindows) return;
        rethrow;
      }
      final result = await ScaffoldService(const NativeScaffoldWriter())
          .execute(ScaffoldRequest(destination: destination));
      expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
      expect(await outside.exists(), isTrue);
      expect(outside.listSync(), isEmpty);
    },
  );
  test('GivenConcurrentEmptyDestination_WhenCreating_ThenExistingDirectoryIsNotReplaced', () async {
    final destination = Directory('${parent.path}/existing')..createSync();
    final before = destination.statSync().changed;
    final result = await ScaffoldService(const NativeScaffoldWriter())
        .execute(ScaffoldRequest(destination: destination.path));
    expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
    expect(destination.statSync().changed, before);
    expect(destination.listSync(), isEmpty);
  });
  test('GivenCorruptTemplate_WhenCreating_ThenNoDestinationExists', () async {
    final destination = '${parent.path}/new';
    final bundle = TemplateBundle(
      version: 'v1',
      files: {'../escape': 'bad'},
      digests: {'../escape': 'bad'},
    );
    final result = await ScaffoldService(
      const NativeScaffoldWriter(),
      template: bundle,
    ).execute(ScaffoldRequest(destination: destination));
    expect((result as ChimeraFailure).code, 'scaffold-invalid-template');
    expect(await Directory(destination).exists(), isFalse);
  });
  test(
    'GivenUnsupportedTarget_WhenCreating_ThenTypedUnsupportedResult',
    () async {
      final result = await const UnsupportedScaffoldService().execute(
        const ScaffoldRequest(destination: 'new'),
      );
      expect((result as ChimeraFailure).code, 'scaffold-unsupported');
    },
  );
  test('GivenNestedDirectoryReplacedByLink_WhenRollbackRuns_ThenOutsideContentSurvives', () async {
    if (Platform.isWindows) return;
    final destination = '${parent.path}/new';
    final outside = Directory('${parent.path}/outside')..createSync();
    File('${outside.path}/.gitkeep').writeAsStringSync('external');
    final writer = NativeScaffoldWriter(
      writeFile: (file, bytes) async {
        if (file.path.endsWith('/src/.gitkeep')) {
          await file.delete();
          await file.parent.delete();
          await Link(file.parent.path).create(outside.path);
          throw const FileSystemException('directory changed');
        }
        await file.writeAsBytes(bytes);
      },
    );
    final result = await ScaffoldService(writer)
        .execute(ScaffoldRequest(destination: destination));
    expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
    expect(File('${outside.path}/.gitkeep').readAsStringSync(), 'external');
  });
}
