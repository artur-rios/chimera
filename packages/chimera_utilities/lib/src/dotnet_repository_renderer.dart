import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'dotnet_repository_parameters.dart';
import 'dotnet_repository_templates.dart';
import 'project_template.dart';

final class DotnetRepositoryRenderer {
  const DotnetRepositoryRenderer();
  static const templateVersion =
      'dotnet-tools-7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998-chimera-v1';

  TemplateBundle renderNugetLibrary(
    DotnetRepositoryParameters parameters, {
    required int year,
  }) {
    if (year < 2026 || year > 9999) throw ArgumentError('Invalid license year');
    final project = parameters.projectName;
    final solution = parameters.solutionName;
    final projectGuid = _guid('project:$project');
    final testsGuid = _guid('tests:$project');
    final readmeTemplate = dotnetReadme.replaceFirst(
      '## Build, test and publish',
      '''## Versioning

Semantic Versioning (SemVer). Breaking changes increment the major version;
new compatible features increment the minor version; fixes increment the patch.

## Build, test and publish''',
    );
    final readme = _replace(readmeTemplate, {
      'SOLUTION_NAME': solution,
      'DESCRIPTION': parameters['Description'],
    });
    final library = _replace(
      dotnetNugetProject.replaceFirst(
        '<Company>__AUTHOR__</Company>',
        '<Company>__COMPANY__</Company>',
      ),
      {
        'AUTHOR': _xml(parameters['Author']),
        'COMPANY': _xml(parameters['Company']),
        'DESCRIPTION': _xml(parameters['Description']),
        'PACKAGE_ID': parameters['PackageId'],
        'VERSION': parameters['Version'],
        'REPOSITORY_URL': _xml(parameters['RepositoryUrl']),
      },
    );
    final testsProject = _replace(dotnetTestsProject, {'PROJECT_NAME': project})
        .replaceFirst(
          'Include="coverlet.collector" Version="*"',
          'Include="coverlet.collector" Version="6.0.4"',
        )
        .replaceFirst(
          'Include="Microsoft.NET.Test.Sdk" Version="*"',
          'Include="Microsoft.NET.Test.Sdk" Version="17.14.1"',
        )
        .replaceFirst(
          'Include="xunit" Version="*"',
          'Include="xunit" Version="2.9.3"',
        )
        .replaceFirst(
          'Include="xunit.runner.visualstudio" Version="*"',
          'Include="xunit.runner.visualstudio" Version="3.1.5"',
        )
        .replaceFirst(
          '<IsPackable>false</IsPackable>',
          '<IsPackable>false</IsPackable>\n    <IsTestProject>true</IsTestProject>\n    <ImplicitUsings>enable</ImplicitUsings>\n    <Nullable>enable</Nullable>',
        );
    var sln = _replace(dotnetSolution, {
      'PROJECT_NAME': project,
      'PROJECT_GUID': projectGuid,
      'SOLUTION_NAME': solution,
    });
    sln = sln.replaceFirst('"$project\\$project.csproj"', '"$project.csproj"');
    sln = sln.replaceFirst(
      'EndProject\nGlobal',
      'EndProject\nProject("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "$project.Tests", "..\\tests\\$project.Tests.csproj", "{$testsGuid}"\nEndProject\nGlobal',
    );
    final testConfigurations = ['Debug', 'Release']
        .expand(
          (configuration) => [
            '\t\t{$testsGuid}.$configuration|Any CPU.ActiveCfg = $configuration|Any CPU',
            '\t\t{$testsGuid}.$configuration|Any CPU.Build.0 = $configuration|Any CPU',
          ],
        )
        .join('\n');
    sln = sln.replaceFirst(
      '{$projectGuid}.Release|Any CPU.Build.0 = Release|Any CPU',
      '{$projectGuid}.Release|Any CPU.Build.0 = Release|Any CPU\n$testConfigurations',
    );
    final files = <String, String>{
      '.editorconfig': dotnetEditorconfig,
      '.gitignore': dotnetGitignore,
      '.wakatime-project': '$project\n',
      'LICENSE': _replace(dotnetLicense, {'YEAR': '$year'}),
      'README.md': readme,
      'src/$solution.sln': sln,
      'src/$project.csproj': library,
      'src/Library.cs':
          'namespace $project;\n\n/// <summary>A sample library entry point.</summary>\npublic static class Library\n{\n    /// <summary>Returns a greeting.</summary>\n    public static string Greeting() => "Hello World";\n}\n',
      'tests/$project.Tests.csproj': testsProject,
      'tests/LibraryTests.cs':
          'namespace $project.Tests;\n\npublic sealed class LibraryTests\n{\n    [Fact]\n    public void GivenLibrary_WhenGreetingRequested_ThenReturnsHelloWorld()\n    {\n        Assert.Equal("Hello World", global::$project.Library.Greeting());\n    }\n}\n',
      'docs/.gitkeep': '',
    };
    // The complete immutable bundle is checked before the shared writer runs.
    return TemplateBundle(
      version: templateVersion,
      files: files,
      digests: {
        for (final entry in files.entries)
          entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
      },
    );
  }

  String _replace(String template, Map<String, String> values) =>
      template.replaceAllMapped(
        RegExp(r'__([A-Z_]+)__'),
        (match) => values[match.group(1)] ?? match.group(0)!,
      );
  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  String _guid(String key) {
    final value = sha256
        .convert(utf8.encode(key))
        .toString()
        .substring(0, 32)
        .toUpperCase();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }
}
