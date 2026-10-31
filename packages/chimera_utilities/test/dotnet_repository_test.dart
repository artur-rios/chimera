import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

const fields = <String, String>{
  'RootFolder': '/tmp/ExampleRepo',
  'SolutionName': 'Example.Solution',
  'ProjectName': 'Example.Library',
  'Author': 'Jane Doe',
  'Company': 'Example & Co',
  'Description': 'A <useful> library',
  'Version': '1.2.3-beta.1+build.7',
  'PackageId': 'Example.Library',
  'RepositoryUrl': 'https://example.com/repository',
};
void main() {
  test(
    'GivenKnownMetadata_WhenRendered_ThenMatchesIndependentGoldenFiles',
    () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
      );
      final fixture = File.fromUri(
        library!.resolve('../test/fixtures/dotnet_library/expected.json'),
      );
      final expected = jsonDecode(await fixture.readAsString());
      final actual = const DotnetRepositoryRenderer().renderNugetLibrary(
        DotnetRepositoryParameters.parse(fields: fields),
        year: 2026,
      );
      expect(actual.files, expected);
    },
  );
  test(
    'GivenPackableEdgeFixture_WhenParsed_ThenPreservesNugetIdentifier',
    () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_utilities/chimera_utilities.dart'),
      );
      final fixture = File.fromUri(
        library!.resolve(
          '../test/fixtures/dotnet_library/packable-edge-parameters.json',
        ),
      );
      final parameters = DotnetRepositoryParameters.parse(
        parametersJson: await fixture.readAsString(),
      );
      expect(parameters['PackageId'], '_Example.Library_Pack-1');
      expect(
        const DotnetRepositoryRenderer()
            .renderNugetLibrary(parameters, year: 2026)
            .files['src/Example.Library.csproj'],
        contains('<PackageId>_Example.Library_Pack-1</PackageId>'),
      );
    },
  );
  test(
    'GivenEquivalentFlagsAndJson_WhenParsed_ThenRenderIdenticalRepositories',
    () {
      final flags = DotnetRepositoryParameters.parse(fields: fields);
      final json = DotnetRepositoryParameters.parse(
        parametersJson: jsonEncode(fields),
      );
      final renderer = const DotnetRepositoryRenderer();
      final a = renderer.renderNugetLibrary(flags, year: 2026);
      final b = renderer.renderNugetLibrary(json, year: 2026);
      expect(a.isValid, isTrue);
      expect(a.files, b.files);
      expect(
        a.files.keys,
        containsAll([
          '.editorconfig',
          '.gitignore',
          '.wakatime-project',
          'LICENSE',
          'README.md',
          'src/Example.Solution.sln',
          'src/Example.Library.csproj',
          'tests/Example.Library.Tests.csproj',
          'docs/.gitkeep',
        ]),
      );
      expect(
        a.files['src/Example.Library.csproj'],
        contains('<Company>Example &amp; Co</Company>'),
      );
      expect(
        a.files['src/Example.Library.csproj'],
        contains('A &lt;useful&gt; library'),
      );
      expect(
        a.files['src/Example.Solution.sln'],
        contains('..\\tests\\Example.Library.Tests.csproj'),
      );
    },
  );
  test('GivenInvalidNugetIdGrammar_WhenParsed_ThenRejectsPackageId', () {
    for (final packageId in [
      '.',
      '-',
      '.Example',
      '-Example',
      'Example.',
      'Example-',
      'Example..Library',
      'Example--Library',
      'Example.-Library',
      'Example-.Library',
      'A' * 101,
    ]) {
      expect(
        () => DotnetRepositoryParameters.parse(
          fields: {...fields, 'PackageId': packageId},
        ),
        throwsA(
          isA<DotnetParameterException>().having(
            (error) => error.fields,
            'fields',
            contains('PackageId'),
          ),
        ),
        reason: packageId,
      );
    }
  });
  test(
    'GivenNugetWordGroups_WhenParsed_ThenPreservesValidUnderscoreAndNumericIds',
    () {
      for (final packageId in [
        '_',
        '_Example.Library_Pack-1',
        'Example__Library',
        '123',
        'Example_',
        'A' * 100,
      ]) {
        expect(
          DotnetRepositoryParameters.parse(
            fields: {...fields, 'PackageId': packageId},
          )['PackageId'],
          packageId,
        );
      }
    },
  );
  test(
    'GivenSpecialCSharpKeywordSegment_WhenParsed_ThenRejectsProjectName',
    () {
      for (final keyword in [
        '__arglist',
        '__makeref',
        '__reftype',
        '__refvalue',
      ]) {
        for (final projectName in [keyword, 'Example.$keyword.Library']) {
          expect(
            () => DotnetRepositoryParameters.parse(
              fields: {...fields, 'ProjectName': projectName},
            ),
            throwsA(
              isA<DotnetParameterException>().having(
                (error) => error.fields,
                'fields',
                contains('ProjectName'),
              ),
            ),
            reason: projectName,
          );
        }
      }
    },
  );
  test('GivenInvalidMetadata_WhenParsed_ThenReturnsOnlyFieldIdentifiers', () {
    final invalid = {
      'RootFolder': '..',
      'ProjectName': '../Escape',
      'SolutionName': 'CON',
      'Author': r'$(Shell)',
      'Company': '',
      'Description': 'bad\nline',
      'Version': '01.2.3',
      'PackageId': 'bad/id',
      'RepositoryUrl': 'https://user:pass@example.com/private',
    };
    expect(
      () => DotnetRepositoryParameters.parse(fields: {...fields, ...invalid}),
      throwsA(
        isA<DotnetParameterException>().having(
          (e) => e.fields,
          'fields',
          containsAll(invalid.keys),
        ),
      ),
    );
  });
  test('GivenMixedModesEvenEmptyFlag_WhenParsed_ThenRejectsMode', () {
    expect(
      () => DotnetRepositoryParameters.parse(
        fields: {'Author': ''},
        parametersJson: jsonEncode(fields),
      ),
      throwsA(
        isA<DotnetParameterException>().having((e) => e.fields, 'fields', [
          'inputMode',
        ]),
      ),
    );
  });
  for (final json in [
    '[]',
    '{',
    '{"RootFolder":3}',
    '{"Unknown":"x"}',
    'null',
  ]) {
    test(
      'GivenMalformedOrWrongShapeJson_WhenParsed_ThenFailsWithoutCoercion:$json',
      () {
        expect(
          () => DotnetRepositoryParameters.parse(parametersJson: json),
          throwsA(isA<DotnetParameterException>()),
        );
      },
    );
  }
  test(
    'GivenMinimalParameters_WhenCommonParserUsed_ThenMetadataIsNotRequired',
    () {
      final minimal = Map<String, String>.from(fields)
        ..removeWhere(
          (key, value) => [
            'Company',
            'Version',
            'PackageId',
            'RepositoryUrl',
          ].contains(key),
        );
      expect(
        DotnetRepositoryParameters.parse(
          fields: minimal,
          nuget: false,
        ).projectName,
        'Example.Library',
      );
    },
  );
  test(
    'GivenCSharpKeywordOrUnbuildableVersion_WhenParsed_ThenIdentifiesField',
    () {
      for (final invalid in [
        {'ProjectName': 'class'},
        {'Version': '99999.0.0'},
        {'RootFolder': 'repo '},
      ]) {
        expect(
          () =>
              DotnetRepositoryParameters.parse(fields: {...fields, ...invalid}),
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
  test(
    'GivenReadmeHeadingInDescription_WhenRendered_ThenPreservesLiteralMetadata',
    () {
      final parameters = DotnetRepositoryParameters.parse(
        fields: {
          ...fields,
          'Description': 'Literal ## Build, test and publish description',
        },
      );
      expect(
        const DotnetRepositoryRenderer()
            .renderNugetLibrary(parameters, year: 2026)
            .files['README.md'],
        contains('Literal ## Build, test and publish description'),
      );
    },
  );
  test('GivenInvalidXmlCodepoint_WhenParsed_ThenReportsMetadataField', () {
    for (final description in ['bad\uFFFF', 'bad\uD800']) {
      expect(
        () => DotnetRepositoryParameters.parse(
          fields: {...fields, 'Description': description},
        ),
        throwsA(
          isA<DotnetParameterException>().having(
            (error) => error.fields,
            'fields',
            contains('Description'),
          ),
        ),
      );
    }
  });
  test('GivenPlaceholderLikeMetadata_WhenRendered_ThenDoesNotRecursivelySubstitute', () {
    final parameters = DotnetRepositoryParameters.parse(
      fields: {...fields, 'Description': '__AUTHOR__ is literal'},
    );
    expect(
      const DotnetRepositoryRenderer()
          .renderNugetLibrary(parameters, year: 2026)
          .files['src/Example.Library.csproj'],
      contains('__AUTHOR__ is literal'),
    );
  });
}
