import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

String fixturePath(
  String first, [
  String? second,
  String? third,
  String? fourth,
  String? fifth,
]) => [
  first,
  second,
  third,
  fourth,
  fifth,
].whereType<String>().join(Platform.pathSeparator);

void main() {
  late Directory parent;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('chimera minimal cli ');
  });
  tearDown(() async {
    await parent.delete(recursive: true);
  });
  test('GivenMalformedParameters_WhenCliJsonRequested_ThenFieldErrorWithoutOutputTree', () async {
    final file = File(fixturePath(parent.path, 'bad.json'));
    await file.writeAsString('{');
    final out = StringBuffer();
    expect(
      await runChimera(
        ['dotnet', 'init-min', '--parameters', file.path, '--json'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      ),
      64,
    );
    final result = jsonDecode(out.toString()) as Map;
    expect(result['error'], 'dotnet-minimal-validation');
    expect((result['details'] as Map)['fields'], ['parametersJson']);
    expect(await parent.list().length, 1);
  });
  test('GivenFlags_WhenCliScaffolds_ThenJsonContainsAllCreatedPaths', () async {
    final out = StringBuffer();
    final status = await runChimera(
      [
        'dotnet',
        'init-min',
        '--root',
        fixturePath(parent.path, 'repo'),
        '--solution',
        'Example',
        '--project',
        'Example.Library',
        '--author',
        'Jane Doe',
        '--description',
        'Minimal library',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );
    expect(status, 0);
    final value = jsonDecode(out.toString()) as Map;
    expect(value['createdPaths'], hasLength(10));
  });
  test('GivenParametersFile_WhenCliScaffolds_ThenSameRepositoryAndLocalizedSuccess', () async {
    final parameters = File(fixturePath(parent.path, 'parameters.json'));
    await parameters.writeAsString(
      jsonEncode({
        'RootFolder': fixturePath(parent.path, 'repo'),
        'SolutionName': 'Example',
        'ProjectName': 'Example.Library',
        'Author': 'Jane Doe',
        'Description': 'Minimal library',
      }),
    );
    final out = StringBuffer();
    expect(
      await runChimera(
        ['dotnet', 'init-min', '--parameters', parameters.path],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('Repositório mínimo criado'));
    expect(
      await File(
        fixturePath(
          parent.path,
          'repo',
          'src',
          'Example.Library',
          'Example.Library.csproj',
        ),
      ).exists(),
      true,
    );
  });
  test('GivenMixedModesOrBadFlags_WhenCli_ThenNothingCreated', () async {
    for (final args in [
      ['--parameters', 'missing.json', '--root', 'repo'],
      ['--unknown'],
      ['extra'],
      ['--root'],
    ]) {
      expect(
        await runChimera(
          ['dotnet', 'init-min', ...args],
          localeTag: 'en',
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
    }
    expect(await parent.list().length, 0);
  });
  test('GivenMissingParameterFile_WhenCli_ThenAccessFailure', () async {
    expect(
      await runChimera(
        [
          'dotnet',
          'init-min',
          '--parameters',
          fixturePath(parent.path, 'missing.json'),
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      ),
      74,
    );
  });
}
