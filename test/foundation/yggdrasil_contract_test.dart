import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;
  late File catalog;
  late String python;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chimera-yggdrasil-contract-',
    );
    catalog = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}catalog.yaml',
    )..writeAsStringSync(_validCatalog);
    python = Platform.isWindows ? 'python' : 'python3';
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test(
    'GivenCompatibleCatalog_WhenValidated_ThenReleaseContractPasses',
    () async {
      final result = await _validate(python, catalog);

      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(result.stdout, contains('Yggdrasil Chimera release contract: OK'));
    },
  );

  test('GivenChangedChecksTriggersApprovalAndReleaseHandoff_WhenValidated_ThenEveryDriftIsReported', () async {
    catalog.writeAsStringSync(
      _validCatalog
          .replaceFirst(
            'trigger: branch\n    branches: release/*',
            'trigger: manual',
          )
          .replaceFirst('    approval: true\n', '    approval: false\n')
          .replaceFirst('        releaseArtifacts: true\n', '')
          .replaceFirst('          - native-linux\n', '')
          .replaceFirst('          - Native (windows)\n', ''),
    );

    final result = await _validate(python, catalog);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('homologation.trigger'));
    expect(result.stderr, contains('production.approval'));
    expect(result.stderr, contains('chimera.releaseArtifacts'));
    expect(result.stderr, contains('chimera.checks'));
    expect(result.stderr, contains('chimera.actionsChecks'));
  });

  test(
    'GivenGitHubJobNamesAsChecks_WhenValidated_ThenTheOldCheckNamesAreRejected',
    () async {
      catalog.writeAsStringSync(
        _validCatalog.replaceFirst(
          '          - analyze-and-test\n',
          '          - Analyze and test\n          - Cross-platform\n',
        ),
      );

      final result = await _validate(python, catalog);

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('chimera.checks'));
      expect(result.stderr, isNot(contains('chimera.actionsChecks')));
    },
  );
}

Future<ProcessResult> _validate(String python, File catalog) => Process.run(
  python,
  <String>['tool/validate_yggdrasil_contract.py', catalog.path],
);

const String _validCatalog = '''
owner: artur-rios
environments:
  - id: local
    name: Local
    trigger: manual
  - id: development
    name: Development
    trigger: branch
    branches: develop
    agent: vps
  - id: homologation
    name: Homologation
    trigger: branch
    branches: release/*
    agent: vps
  - id: production
    name: Production
    trigger: release
    agent: vps
    approval: true
systems:
  - id: chimera
    name: Chimera
    applications:
      - id: chimera
        name: Chimera web
        kind: web
        health: http://chimera:8080/healthz
        host: chimera
        releaseArtifacts: true
        checks:
          - analyze-and-test
          - browser-tests
          - native-linux
          - container
          - accessibility-performance
          - cleanup-contract
          - generated-library
          - evaluate-projects
          - version-contract
          - build-contract
          - minimal-library
        actionsChecks:
          - Safari
          - Native (windows)
          - Artifact cleanup (windows-latest)
          - Generated NuGet library (windows-latest)
          - .NET project evaluation (windows-latest)
          - Project version editing (windows-latest)
          - .NET build, coverage and process lifecycle (windows-latest)
          - Minimal library contracts (windows-latest)
          - Windows owned terminal lifecycle
        container: { service: web }
''';
