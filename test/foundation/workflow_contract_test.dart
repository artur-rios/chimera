import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String branchPolicy;
  late String continuousIntegration;
  late String releaseArtifacts;

  setUpAll(() {
    branchPolicy = _readNormalized('.github/workflows/branch-policy.yml');
    continuousIntegration = _readNormalized('.github/workflows/ci.yml');
    releaseArtifacts = _readNormalized(
      '.github/workflows/release-artifacts.yml',
    );
  });

  test('GivenPullRequest_WhenBranchPolicyRuns_ThenOnlyDocumentedBranchFlowsAreAccepted', () {
    expect(branchPolicy, contains('branches: [develop, main]'));
    expect(branchPolicy, contains(r'^(feature|fix)/'));
    expect(branchPolicy, contains(r'^release/[0-9]+\.[0-9]+\.[0-9]+$'));
    expect(branchPolicy, contains('git merge-base --is-ancestor'));
    expect(
      branchPolicy,
      contains(
        'dart tool/check_branch_origin.dart origin/main origin/develop '
        '"\$HEAD_SHA"',
      ),
    );
    expect(
      branchPolicy,
      isNot(contains('dart run tool/check_branch_origin.dart')),
    );
    expect(branchPolicy, contains('name: branch-policy'));
  });

  test('GivenCiWorkflow_WhenChecksRun_ThenCatalogCheckNamesRemainStable', () {
    for (final checkName in <String>[
      'Analyze and test',
      'Cross-platform',
      'Container',
      'Accessibility and performance',
    ]) {
      expect(continuousIntegration, contains('name: $checkName'));
    }
  });

  test(
    'GivenCiWorkflow_WhenWebTestsRun_ThenEverySupportedBrowserIsCovered',
    () {
      expect(
        continuousIntegration,
        contains('browser: [chromium, firefox, webkit]'),
      );
      expect(continuousIntegration, contains('tests/web'));
      expect(continuousIntegration, contains('name: Safari'));
      expect(continuousIntegration, contains('runs-on: macos-latest'));
      expect(continuousIntegration, contains('safaridriver'));
      expect(continuousIntegration, contains('tests/web/safari_smoke.dart'));
    },
  );

  test('GivenCiWorkflow_WhenNativeBuildsRun_ThenWindowsAndLinuxAreCovered', () {
    expect(continuousIntegration, contains('os: windows-latest'));
    expect(continuousIntegration, contains('target: windows'));
    expect(continuousIntegration, contains('os: ubuntu-latest'));
    expect(continuousIntegration, contains('target: linux'));
    expect(
      continuousIntegration,
      contains('working-directory: apps/chimera_gui'),
      reason: 'Flutter integration tests must run from the GUI package.',
    );
    expect(
      continuousIntegration,
      contains('flutter test integration_test -d windows'),
    );
    expect(
      continuousIntegration,
      contains('flutter test integration_test -d linux'),
    );
    expect(
      continuousIntegration,
      contains(
        'New-Item -ItemType Directory -Force build/cli/windows | Out-Null',
      ),
      reason: 'The Windows AOT compiler does not create parent directories.',
    );
    expect(
      continuousIntegration,
      contains('mkdir -p build/cli/linux'),
      reason: 'The Linux AOT compiler does not create parent directories.',
    );
  });

  test(
    'GivenReleaseWorkflow_WhenPackagingRuns_ThenVerificationCompletesFirst',
    () {
      expect(releaseArtifacts, contains('name: Verify before packaging'));
      expect(releaseArtifacts, contains('needs: verify'));
      expect(releaseArtifacts, contains('tool/package_windows.ps1'));
      expect(releaseArtifacts, contains('tool/package_linux.sh'));
    },
  );

  test('GivenReleaseWorkflow_WhenArtifactsArePublished_ThenIntegrityAndMetadataAreIncluded', () {
    expect(releaseArtifacts, contains('tool/write_checksums.dart'));
    expect(releaseArtifacts, contains('.sha256'));
    expect(releaseArtifacts, contains('.release.json'));
    expect(releaseArtifacts, contains('actions/upload-artifact@'));
  });

  test('GivenCiWorkflow_WhenEvidenceIsProduced_ThenItIsPreserved', () {
    expect(continuousIntegration, contains('accessibility-review'));
    expect(continuousIntegration, contains('acceptance_thresholds.json'));
    expect(continuousIntegration, contains('actions/upload-artifact@'));
    expect(continuousIntegration, contains('dart test --coverage='));
    expect(continuousIntegration, contains('flutter test --coverage'));
    expect(continuousIntegration, contains('test-and-coverage-evidence'));
    expect(
      continuousIntegration,
      contains('accessibility-and-performance-evidence'),
    );
  });

  test(
    'GivenReleaseWorkflow_WhenPermissionsAreScoped_ThenOnlyPublisherCanWrite',
    () {
      expect(releaseArtifacts, contains('permissions:\n  contents: read'));
      expect(
        releaseArtifacts,
        contains(
          'publish:\n    name: Attach native artifacts\n    permissions:\n      contents: write',
        ),
      );
    },
  );

  test('GivenJenkinsEntryPoint_WhenLoaded_ThenChimeraStackIsSelected', () {
    final jenkinsfile = File('Jenkinsfile').readAsStringSync();

    expect(jenkinsfile, contains("yggdrasilPipeline(stack: 'chimera')"));
  });

  test('GivenWorkflowFiles_WhenParsed_ThenEachDocumentIsValidYaml', () {
    expect(() => loadYaml(branchPolicy), returnsNormally);
    expect(() => loadYaml(continuousIntegration), returnsNormally);
    expect(() => loadYaml(releaseArtifacts), returnsNormally);
  });
}

String _readNormalized(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
