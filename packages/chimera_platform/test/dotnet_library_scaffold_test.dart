import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('chimera-nuget-test-');
  });
  tearDown(() async {
    await parent.delete(recursive: true);
  });
  Map<String, String> parameters(String destination) => {
    'RootFolder': destination,
    'SolutionName': 'Example',
    'ProjectName': 'Example.Library',
    'Author': 'Jane Doe',
    'Company': 'Example Co',
    'Description': 'Example library',
    'Version': '1.2.3',
    'PackageId': 'Example.Library',
    'RepositoryUrl': 'https://example.com/repository',
  };
  test(
    'GivenValidRepository_WhenCreatedOffline_ThenReportsEveryCreatedFile',
    () async {
      final destination = '${parent.path}/new';
      final result = await NugetLibraryScaffoldService(
        const NativeScaffoldWriter(),
      ).execute(DotnetScaffoldRequest(fields: parameters(destination)));
      expect(result, isA<ChimeraSuccess<ScaffoldOutput>>());
      final output = (result as ChimeraSuccess<ScaffoldOutput>).value;
      final actual = Directory(destination)
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      expect(output.createdPaths, unorderedEquals(actual));
      expect(actual, hasLength(11));
      expect(await File('$destination/src/Example.sln').exists(), isTrue);
    },
  );
  test(
    'GivenExistingDestination_WhenScaffolded_ThenPreservesAllContent',
    () async {
      final destination = Directory('${parent.path}/existing')..createSync();
      final sentinel = File('${destination.path}/sentinel')
        ..writeAsStringSync('keep');
      final result = await NugetLibraryScaffoldService(
        const NativeScaffoldWriter(),
      ).execute(DotnetScaffoldRequest(fields: parameters(destination.path)));
      expect((result as ChimeraFailure).kind, FailureKind.access);
      expect(sentinel.readAsStringSync(), 'keep');
      expect(destination.listSync(), hasLength(1));
    },
  );
  test(
    'GivenFailureAfterSeveralWrites_WhenScaffolded_ThenRollsBackOwnedTree',
    () async {
      var written = 0;
      final destination = '${parent.path}/new';
      final writer = NativeScaffoldWriter(
        writeFile: (file, bytes) async {
          if (++written == 8) throw const FileSystemException('simulated');
          await file.writeAsBytes(bytes);
        },
      );
      final result = await NugetLibraryScaffoldService(writer)
          .execute(DotnetScaffoldRequest(fields: parameters(destination)));
      expect((result as ChimeraFailure).kind, FailureKind.processing);
      expect(await Directory(destination).exists(), isFalse);
    },
  );
}
