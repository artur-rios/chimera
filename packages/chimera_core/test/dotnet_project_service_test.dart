import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

final class _Writer implements ScaffoldWriter {
  _Writer({this.result, this.error});

  final ChimeraResult<ScaffoldOutput>? result;
  final Object? error;
  final requests = <ScaffoldRequest>[];
  final templates = <TemplateBundle>[];

  @override
  Future<ChimeraResult<ScaffoldOutput>> write(
    ScaffoldRequest request,
    TemplateBundle template,
  ) async {
    requests.add(request);
    templates.add(template);
    if (error != null) throw error!;
    return result ??
        ChimeraSuccess(
          ScaffoldOutput(
            destination: request.destination,
            templateVersion: template.version,
            createdPaths: template.files.keys.toList(),
          ),
        );
  }
}

void main() {
  for (final nuget in [false, true]) {
    final mode = nuget ? 'nuget' : 'minimal';
    test(
      'Given${mode}Request_WhenExecuted_ThenItsProjectIsWrittenUnderTheParent',
      () async {
        final writer = _Writer();

        final result = await DotnetProjectService(writer).execute(
          DotnetProjectRequest(
            name: 'Sample',
            parentDirectory: 'work',
            nuget: nuget,
          ),
        );

        final output = (result as ChimeraSuccess<DotnetProjectOutput>).value;
        expect(writer.requests.single.destination, 'work/Sample');
        expect(writer.templates.single.files.keys, ['Sample.csproj']);
        expect(output.mode, mode);
        expect(output.toJson(), {
          'destination': 'work/Sample',
          'templateVersion': writer.templates.single.version,
          'createdPaths': ['Sample.csproj'],
          'mode': mode,
          'projectPath': 'Sample.csproj',
        });
      },
    );
  }

  test('GivenDefaultRequest_WhenExecuted_ThenMinimalProjectIsWrittenInTheCurrentDirectory', () async {
    final writer = _Writer();

    final result = await DotnetProjectService(writer)
        .execute(const DotnetProjectRequest(name: 'Sample'));

    expect(
      (result as ChimeraSuccess<DotnetProjectOutput>).value.mode,
      'minimal',
    );
    expect(writer.requests.single.destination, './Sample');
  });

  for (final name in ['_Sample', 'a', 'Sample.Core-1_x', 'A' * 100]) {
    test('GivenValidName${name.length}_WhenExecuted_ThenItIsWritten', () async {
      final writer = _Writer();

      final result = await DotnetProjectService(writer)
          .execute(DotnetProjectRequest(name: name));

      expect(result, isA<ChimeraSuccess<DotnetProjectOutput>>());
      expect(writer.requests.single.destination, './$name');
    });
  }

  for (final (label, request) in [
    ('NameOverLimit', DotnetProjectRequest(name: 'A' * 101)),
    ('NameStartingWithDigit', const DotnetProjectRequest(name: '1Sample')),
    ('NameStartingWithDot', const DotnetProjectRequest(name: '.Sample')),
    ('ReservedNameWithExtension', const DotnetProjectRequest(name: 'Com1.x')),
    (
      'BlankParent',
      const DotnetProjectRequest(name: 'S', parentDirectory: ' '),
    ),
    (
      'MinimalAndNuget',
      const DotnetProjectRequest(name: 'S', minimal: true, nuget: true),
    ),
  ]) {
    test(
      'Given${label}_WhenExecuted_ThenValidationFailsWithoutWriting',
      () async {
        final writer = _Writer();

        final result = await DotnetProjectService(writer).execute(request);

        final failure = result as ChimeraFailure<DotnetProjectOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'dotnet-project-invalid-options');
        expect(failure.messageKey, 'error.dotnetProject.validation');
        expect(writer.requests, isEmpty);
      },
    );
  }

  test(
    'GivenWriterFailure_WhenExecuted_ThenItsKindCodeKeyAndDetailsReturn',
    () async {
      final writer = _Writer(
        result: const ChimeraFailure(
          kind: FailureKind.access,
          code: 'scaffold-exists',
          messageKey: 'error.scaffold.exists',
          details: {'path': 'work/Sample'},
        ),
      );

      final result = await DotnetProjectService(writer)
          .execute(const DotnetProjectRequest(name: 'Sample'));

      final failure = result as ChimeraFailure<DotnetProjectOutput>;
      expect(failure.kind, FailureKind.access);
      expect(failure.code, 'scaffold-exists');
      expect(failure.messageKey, 'error.scaffold.exists');
      expect(failure.details, {'path': 'work/Sample'});
    },
  );

  test(
    'GivenThrowingWriter_WhenExecuted_ThenTypedScaffoldFailureReturns',
    () async {
      final writer = _Writer(error: StateError('PRIVATE'));

      final result = await DotnetProjectService(writer)
          .execute(const DotnetProjectRequest(name: 'Sample'));

      final failure = result as ChimeraFailure<DotnetProjectOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'scaffold-failed');
      expect('${failure.details}', isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenUnsupportedService_WhenExecuted_ThenUnsupportedValidationReturns',
    () async {
      final result = await const UnsupportedDotnetProjectService().execute(
        const DotnetProjectRequest(name: 'Sample'),
      );

      final failure = result as ChimeraFailure<DotnetProjectOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, 'dotnet-project-unsupported');
      expect(failure.messageKey, 'error.scaffold.unsupported');
    },
  );
}
