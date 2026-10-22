import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

const values = {
  'RootFolder': 'new',
  'SolutionName': 'Example',
  'ProjectName': 'Example.Library',
  'Author': 'Jane Doe',
  'Company': 'Example Co',
  'Description': 'Example library',
  'Version': '1.0.0',
  'PackageId': 'Example.Library',
  'RepositoryUrl': 'https://example.com/repository',
};
void main() {
  test(
    'GivenLibraryHelp_WhenInvoked_ThenDocumentsExclusiveInputModes',
    () async {
      final out = StringBuffer();
      expect(
        await runChimera(
          ['dotnet', 'init-lib', '--help'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
        ),
        0,
      );
      expect(out.toString(), contains('--parameters'));
      expect(out.toString(), contains('--package-id'));
    },
  );
  test(
    'GivenAllFlags_WhenInvoked_ThenSharedServiceReceivesCanonicalParameters',
    () async {
      final service = Service();
      final out = StringBuffer();
      final code = await runChimera(
        [
          'dotnet',
          'init-lib',
          '--root=new',
          '--solution=Example',
          '--project=Example.Library',
          '--author=Jane Doe',
          '--company=Example Co',
          '--description=Example library',
          '--version=1.0.0',
          '--package-id=Example.Library',
          '--repository-url=https://example.com/repository',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        dotnetLibraryScaffoldService: service,
      );
      expect(code, 0);
      expect(service.request!.fields, values);
      expect(
        (jsonDecode(out.toString()) as Map<String, dynamic>)['createdPaths'],
        ['src/Example.sln'],
      );
    },
  );
  test(
    'GivenParameterFile_WhenInvoked_ThenPassesOnlyJsonToSharedService',
    () async {
      final service = Service();
      final code = await runChimera(
        ['dotnet', 'init-lib', '--parameters=params.json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
        readFile: (path) async => jsonEncode(values),
        dotnetLibraryScaffoldService: service,
      );
      expect(code, 0);
      expect(service.request!.fields, isEmpty);
      expect(jsonDecode(service.request!.parametersJson!), values);
    },
  );
  test(
    'GivenMixedInputModes_WhenInvoked_ThenFailsBeforeReadingOrWriting',
    () async {
      var read = false;
      final service = Service();
      final code = await runChimera(
        ['dotnet', 'init-lib', '--parameters=params.json', '--author='],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
        readFile: (path) async {
          read = true;
          return '{}';
        },
        dotnetLibraryScaffoldService: service,
      );
      expect(code, 64);
      expect(read, isFalse);
      expect(service.request, isNull);
    },
  );
  test(
    'GivenInaccessibleParameters_WhenInvoked_ThenReturnsAccessFailure',
    () async {
      final service = Service();
      final err = StringBuffer();
      final code = await runChimera(
        ['dotnet', 'init-lib', '--parameters=private.json'],
        localeTag: 'pt-BR',
        out: StringBuffer(),
        err: err,
        readFile: (path) async =>
            throw const FileSystemException('sensitive path'),
        dotnetLibraryScaffoldService: service,
      );
      expect(code, 74);
      expect(err.toString(), isNot(contains('sensitive')));
      expect(service.request, isNull);
    },
  );
  for (final locale in ['en', 'pt-BR']) {
    test('GivenMissingMetadata_WhenInvokedIn$locale'
        '_ThenReportsFieldLevelErrors', () async {
      final err = StringBuffer();
      final out = StringBuffer();
      final code = await runChimera(
        ['dotnet', 'init-lib', '--root=new', '--json'],
        localeTag: locale,
        out: out,
        err: err,
      );
      expect(code, 64);
      expect(
        ((jsonDecode(out.toString()) as Map<String, dynamic>)['details']
            as Map<String, dynamic>)['fields'],
        contains('Author'),
      );
      expect(err.toString(), isNot(contains('error.dotnetScaffold')));
    });
  }
}

class Service implements DotnetScaffoldOperationService {
  DotnetScaffoldRequest? request;
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    DotnetScaffoldRequest value,
  ) async {
    request = value;
    return const ChimeraSuccess(
      ScaffoldOutput(
        destination: 'new',
        templateVersion: 'v1',
        createdPaths: ['src/Example.sln'],
      ),
    );
  }
}
