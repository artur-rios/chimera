import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String branchPolicy;
  late String continuousIntegration;
  late String releaseArtifacts;

  setUpAll(() {
    branchPolicy = File('.github/workflows/branch-policy.yml')
        .readAsStringSync();
    continuousIntegration = File('.github/workflows/ci.yml').readAsStringSync();
    releaseArtifacts = File('.github/workflows/release-artifacts.yml')
        .readAsStringSync();
  });

  test('GivenPullRequest_WhenBranchPolicyRuns_ThenOnlyDocumentedBranchFlowsAreAccepted', () {
    expect(branchPolicy, contains('branches: [develop, main]'));
    expect(branchPolicy, contains(r'^(feature|fix)/'));
    expect(branchPolicy, contains(r'^release/[0-9]+\.[0-9]+\.[0-9]+$'));
    expect(branchPolicy, contains('git merge-base --is-ancestor'));
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
  });

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
