import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

const minimalFields = {
  'RootFolder': 'ExampleRepo',
  'SolutionName': 'Example.Solution',
  'ProjectName': 'Example.Library',
  'Author': 'Jane Doe',
  'Description': 'A minimal library',
};
void main() {
  test(
    'GivenPinnedMinimalTemplates_WhenRendered_ThenMatchesIndependentGolden',
    () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
      );
      final fixture = File.fromUri(
        library!.resolve('../test/fixtures/dotnet_minimal/expected.json'),
      );
      final bundle = const DotnetRepositoryRenderer().renderMinimalLibrary(
        DotnetRepositoryParameters.parse(fields: minimalFields, nuget: false),
        year: 2026,
      );
      expect(bundle.files, jsonDecode(await fixture.readAsString()));
      expect(bundle.isValid, true);
    },
  );
  test('GivenFlagsOrJson_WhenMinimalRendered_ThenIdenticalOutputWithIntentionalOmissions', () {
    final renderer = const DotnetRepositoryRenderer();
    final flags = renderer.renderMinimalLibrary(
      DotnetRepositoryParameters.parse(fields: minimalFields, nuget: false),
      year: 2026,
    );
    final json = renderer.renderMinimalLibrary(
      DotnetRepositoryParameters.parse(
        parametersJson: jsonEncode(minimalFields),
        nuget: false,
      ),
      year: 2026,
    );
    expect(flags.files, json.files);
    expect(flags.files.keys.where((key) => key.endsWith('.csproj')), [
      'src/Example.Library/Example.Library.csproj',
    ]);
    final project = flags.files['src/Example.Library/Example.Library.csproj']!;
    for (final metadata in [
      'PackageId',
      'Version',
      'Authors',
      'Company',
      'RepositoryUrl',
      'PackageReference',
      'GeneratePackageOnBuild',
    ]) {
      expect(project, isNot(contains('<$metadata')));
    }
    expect(flags.files['tests/.gitkeep'], '');
    expect(flags.files['docs/.gitkeep'], '');
    expect(flags.files['src/README.md'], contains('(../LICENSE)'));
  });
  test(
    'GivenMixedInputOrInvalidCommonFields_WhenMinimalParsed_ThenFieldErrors',
    () {
      expect(
        () => DotnetRepositoryParameters.parse(
          fields: minimalFields,
          parametersJson: jsonEncode(minimalFields),
          nuget: false,
        ),
        throwsA(
          isA<DotnetParameterException>().having((e) => e.fields, 'fields', [
            'inputMode',
          ]),
        ),
      );
      for (final invalid in [
        {'ProjectName': '../escape'},
        {'ProjectName': '__arglist'},
        {'ProjectName': 'Example.__refvalue'},
        {'SolutionName': 'CON'},
        {'Author': ''},
        {'Description': 'bad\nline'},
      ]) {
        expect(
          () => DotnetRepositoryParameters.parse(
            fields: {...minimalFields, ...invalid},
            nuget: false,
          ),
          throwsA(
            isA<DotnetParameterException>().having(
              (e) => e.fields,
              'fields',
              contains(invalid.keys.single),
            ),
          ),
        );
      }
    },
  );
}
