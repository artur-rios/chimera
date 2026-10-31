import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

const fields = {
  'RootFolder': 'ExampleRepo',
  'SolutionName': 'Example.Solution',
  'ProjectName': 'Example.Library',
  'Author': 'Jane Doe',
  'Description': 'Minimal library',
};

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

void main() {
  test(
    'GivenInvalidRenderedBundle_WhenScaffolded_ThenRejectBeforeWriting',
    () async {
      final writer = Writer();
      final result = await MinimalLibraryScaffoldService(
        writer,
        renderTemplate: (_, _) => TemplateBundle(
          version: 'broken',
          files: {'../escape': 'x'},
          digests: {'../escape': 'x'},
        ),
      ).execute(const DotnetScaffoldRequest(fields: fields));
      expect(result, isA<ChimeraFailure<ScaffoldOutput>>());
      expect(writer.calls, 0);
    },
  );
  test('GivenMixedRequestOrMalformedJson_WhenScaffolded_ThenNoWrite', () async {
    final writer = Writer();
    for (final request in [
      const DotnetScaffoldRequest(parametersJson: '{'),
      DotnetScaffoldRequest(
        fields: const {'Author': ''},
        parametersJson: jsonEncode(fields),
      ),
    ]) {
      final result = await MinimalLibraryScaffoldService(
        writer,
      ).execute(request) as ChimeraFailure<ScaffoldOutput>;
      expect(result.kind, FailureKind.validation);
      expect(result.details.keys, ['fields']);
    }
    expect(writer.calls, 0);
  });
  test(
    'GivenMinimalFlagsAndJson_WhenScaffolded_ThenUseSharedWriterAndSameOutput',
    () async {
      final writer = Writer();
      final service = MinimalLibraryScaffoldService(
        writer,
        currentYear: () => 2026,
      );
      final flags = await service.execute(
        const DotnetScaffoldRequest(fields: fields),
      );
      final json = await service.execute(
        DotnetScaffoldRequest(parametersJson: jsonEncode(fields)),
      );
      expect(writer.calls, 2);
      expect(
        (flags as ChimeraSuccess<ScaffoldOutput>).value.createdPaths,
        (json as ChimeraSuccess<ScaffoldOutput>).value.createdPaths,
      );
      expect(writer.bundle!.isValid, true);
    },
  );
  test(
    'GivenInvalidInput_WhenScaffolded_ThenNoWriterCallsAndFieldOnlyFailure',
    () async {
      final writer = Writer();
      final result = await MinimalLibraryScaffoldService(writer).execute(
        const DotnetScaffoldRequest(fields: {'RootFolder': 'new'}),
      ) as ChimeraFailure<ScaffoldOutput>;
      expect(
        result.details['fields'],
        containsAll(['Author', 'ProjectName', 'Description']),
      );
      expect(writer.calls, 0);
    },
  );
  test(
    'GivenRenderingFailure_WhenScaffolded_ThenNoWriteAndNoSensitiveDetails',
    () async {
      final writer = Writer();
      final result =
          await MinimalLibraryScaffoldService(
                writer,
                renderTemplate: (_, _) => throw StateError('sensitive'),
              ).execute(const DotnetScaffoldRequest(fields: fields))
              as ChimeraFailure<ScaffoldOutput>;
      expect(result.code, 'dotnet-minimal-render-failed');
      expect(result.details, isEmpty);
      expect(writer.calls, 0);
    },
  );
}
