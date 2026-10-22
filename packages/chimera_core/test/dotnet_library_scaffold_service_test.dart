import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

const libraryFields = <String, String>{
  'RootFolder': 'ExampleRepo',
  'SolutionName': 'Example',
  'ProjectName': 'Example.Library',
  'Author': 'Jane Doe',
  'Company': 'Example Co',
  'Description': 'A library',
  'Version': '1.0.0',
  'PackageId': 'Example.Library',
  'RepositoryUrl': 'https://example.com/repository',
};
void main() {
  test(
    'GivenMissingFields_WhenScaffolding_ThenDoesNotWriteAndIdentifiesFields',
    () async {
      final writer = Writer();
      final result = await NugetLibraryScaffoldService(writer)
          .execute(const DotnetScaffoldRequest(fields: {'RootFolder': 'new'}));
      expect((result as ChimeraFailure).code, 'dotnet-scaffold-validation');
      expect(
        (result as ChimeraFailure).details['fields'],
        containsAll(['Author', 'ProjectName', 'Version']),
      );
      expect(writer.calls, 0);
    },
  );
  test(
    'GivenValidMetadata_WhenScaffolding_ThenUsesSharedWriterAndReportsAllPaths',
    () async {
      final writer = Writer();
      final result = await NugetLibraryScaffoldService(
        writer,
        currentYear: () => 2026,
      ).execute(const DotnetScaffoldRequest(fields: libraryFields));
      expect(result, isA<ChimeraSuccess<ScaffoldOutput>>());
      expect(writer.calls, 1);
      expect(writer.bundle!.isValid, isTrue);
      expect(
        (result as ChimeraSuccess<ScaffoldOutput>).value.createdPaths,
        contains('src/Example.sln'),
      );
    },
  );
  test(
    'GivenRenderingFailure_WhenScaffolding_ThenCreatesNothingAndRedactsFailure',
    () async {
      final writer = Writer();
      final service = NugetLibraryScaffoldService(
        writer,
        renderTemplate: (_, _) => throw StateError('sensitive'),
      );
      final result = await service.execute(
        const DotnetScaffoldRequest(fields: libraryFields),
      );
      expect((result as ChimeraFailure).code, 'dotnet-scaffold-render-failed');
      expect((result as ChimeraFailure).details, isEmpty);
      expect(writer.calls, 0);
    },
  );
  test('GivenInvalidRenderedBundle_WhenScaffolding_ThenSharedServiceRejectsBeforeWrite', () async {
    final writer = Writer();
    final result = await NugetLibraryScaffoldService(
      writer,
      renderTemplate: (_, _) => TemplateBundle(
        version: 'broken',
        files: {'../escape': 'x'},
        digests: {'../escape': 'x'},
      ),
    ).execute(const DotnetScaffoldRequest(fields: libraryFields));
    expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
    expect(writer.calls, 0);
  });
  test(
    'GivenUnsupportedSurface_WhenScaffolding_ThenReturnsTypedUnsupported',
    () async {
      expect(
        (await const UnsupportedDotnetScaffoldService().execute(
          const DotnetScaffoldRequest(fields: libraryFields),
        ) as ChimeraFailure).code,
        'scaffold-unsupported',
      );
    },
  );
}

class Writer implements ScaffoldWriter {
  int calls = 0;
  TemplateBundle? bundle;
  @override
  Future<ChimeraResult<ScaffoldOutput>> write(
    ScaffoldRequest request,
    TemplateBundle template,
  ) async {
    calls++;
    bundle = template;
    return ChimeraSuccess(
      ScaffoldOutput(
        destination: request.destination,
        templateVersion: template.version,
        createdPaths: template.files.keys.toList(),
      ),
    );
  }
}
