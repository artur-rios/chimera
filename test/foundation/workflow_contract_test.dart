import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String branchPolicy;
  late String continuousIntegration;
  late String releaseArtifacts;
  late String safariSmoke;

  setUpAll(() {
    branchPolicy = _readNormalized('.github/workflows/branch-policy.yml');
    continuousIntegration = _readNormalized('.github/workflows/ci.yml');
    releaseArtifacts = _readNormalized(
      '.github/workflows/release-artifacts.yml',
    );
    safariSmoke = _readNormalized('tests/web/safari_smoke.dart');
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

  test('GivenSafariFileInput_WhenBinarySmokeRuns_ThenItIsBoundedAndDoesNotUseTheHangingUploadEndpoint', () {
    expect(continuousIntegration, contains('timeout-minutes: 15'));
    expect(safariSmoke, contains('new DataTransfer()'));
    expect(safariSmoke, contains('new Uint8Array([0x00, 0xff])'));
    expect(safariSmoke, contains("new File([bytes], 'bytes.bin'"));
    expect(safariSmoke, isNot(contains('fileInput!.sendKeys')));
  });

  test('GivenSafariJwtMatrix_WhenInspectionRepeats_ThenOneBootstrappedPageIsReused', () {
    final createJwt = safariSmoke
        .split('Future<void> _createJwt(')
        .elementAt(1)
        .split('Future<String> _createAsymmetricJwt(')
        .first;
    final inspectJwt = safariSmoke
        .split('Future<void> _inspectJwt(')
        .elementAt(1)
        .split('Future<void> _encodeHtml(')
        .first;

    expect(safariSmoke, contains('Future<void> _openJwtInspectPage('));
    expect(
      RegExp(r'await _openJwtInspectPage\(driver\);').allMatches(createJwt),
      hasLength(1),
    );
    expect(inspectJwt, isNot(contains('driver.get(')));
    expect(inspectJwt, isNot(contains('_openJwtInspectPage(')));
  });

  test('GivenSafariHomeActions_WhenPreferencesAreReached_ThenEachTabUsesItsOwnCommand', () {
    expect(
      safariSmoke,
      isNot(contains('List<String>.filled(4, Keyboard.tab).join()')),
    );
    expect(
      safariSmoke,
      contains('focusOrigin: () => _focusPreferenceOrigin(driver)'),
    );
    expect(
      RegExp(r'final navigator = _preferenceFocusNavigator\(driver\);')
          .allMatches(safariSmoke),
      hasLength(2),
    );
    expect(
      RegExp(r'await navigator\.advance\(\);').allMatches(safariSmoke),
      hasLength(2),
    );
  });

  test('GivenCiWorkflow_WhenNativeBuildsRun_ThenWindowsAndLinuxAreCovered', () {
    expect(continuousIntegration, contains('os: windows-latest'));
    expect(continuousIntegration, contains('target: windows'));
    expect(continuousIntegration, contains('os: ubuntu-latest'));
    expect(continuousIntegration, contains('target: linux'));
    final workflow = loadYaml(continuousIntegration) as YamlMap;
    final jobs = workflow['jobs'] as YamlMap;
    final native = jobs['native-tests'] as YamlMap;
    final steps = (native['steps'] as YamlList).cast<YamlMap>();
    final windows = steps.singleWhere(
      (step) => step['name'] == 'Test Windows integration',
    );
    final linux = steps.singleWhere(
      (step) => step['name'] == 'Test Linux integration',
    );
    expect(windows['run'], 'dart run tool/run_native_gui_tests.dart windows');
    expect(
      linux['run'],
      'xvfb-run -a dart run tool/run_native_gui_tests.dart linux',
    );
    expect(windows['working-directory'], isNull);
    expect(linux['working-directory'], isNull);
    final local = _readNormalized('tool/run_gui_tests.dart');
    expect(local, contains("const <String>['test', 'test']"));
    expect(local, contains('runNativeGuiTests(device: device)'));
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

  test(
    'GivenReleasePullRequest_WhenBranchPolicyRuns_ThenSourceAndCatalogAreReady',
    () {
      expect(
        branchPolicy,
        contains('dart tool/validate_release_readiness.dart'),
      );
      expect(branchPolicy, contains('repository: artur-rios/yggdrasil'));
      expect(
        branchPolicy,
        contains('python3 .yggdrasil/scripts/catalog.py validate'),
      );
      expect(branchPolicy, contains('ChimeraCatalogTests'));
      expect(branchPolicy, contains('tool/validate_yggdrasil_contract.py'));
      expect(
        branchPolicy,
        contains(
          'PYTHONPATH=.yggdrasil/scripts python3 -m unittest '
          'test_catalog.ChimeraCatalogTests',
        ),
      );
      expect(branchPolicy, isNot(contains('-k ChimeraCatalogTests')));
      expect(
        releaseArtifacts,
        contains('dart tool/validate_release_readiness.dart'),
      );
    },
  );

  test('GivenReleaseWorkflow_WhenArtifactsArePublished_ThenIntegrityAndMetadataAreIncluded', () {
    expect(releaseArtifacts, contains('tool/write_checksums.dart'));
    expect(releaseArtifacts, contains('.sha256'));
    expect(releaseArtifacts, contains('.release.json'));
    expect(releaseArtifacts, contains('actions/upload-artifact@'));
    expect(releaseArtifacts, contains('name: Validate complete native bundle'));
    expect(
      releaseArtifacts,
      contains('dart run tool/validate_release_bundle.dart'),
    );
    expect(releaseArtifacts, contains('tool/validate_release_upload.dart'));
    expect(releaseArtifacts, contains('inputs.publish'));
    expect(releaseArtifacts, contains('inputs.release_id'));
    expect(releaseArtifacts, contains('cancel-in-progress: false'));
    expect(releaseArtifacts, contains('Require an unpublished draft release'));
    expect(releaseArtifacts, contains('Publish the verified release'));
    expect(releaseArtifacts, isNot(contains('types: [published]')));
    expect(releaseArtifacts, contains('needs: validate-artifacts'));
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
