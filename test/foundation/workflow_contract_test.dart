import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

// Chimera's CI is yggdrasil's Jenkins pipeline: the Linux checks, the branch policy and the release are
// yggdrasil.yml and ci/*.sh, and the Windows and macOS jobs stay GitHub Actions workflows on the GitHub mirror,
// whose results Jenkins copies under the names GitHub reports (the catalog's actionsChecks).
const List<String> _checks = <String>[
  'analyze-and-test',
  'browser-tests',
  'native-linux',
  'container',
  'accessibility-performance',
  'cleanup-contract',
  'generated-library',
  'evaluate-projects',
  'version-contract',
  'build-contract',
  'minimal-library',
];

const List<String> _actionsChecks = <String>[
  'Safari',
  'Native (windows)',
  'Artifact cleanup (windows-latest)',
  'Generated NuGet library (windows-latest)',
  '.NET project evaluation (windows-latest)',
  'Project version editing (windows-latest)',
  '.NET build, coverage and process lifecycle (windows-latest)',
  'Minimal library contracts (windows-latest)',
  'Windows owned terminal lifecycle',
];

void main() {
  late String pipelineFile;
  late YamlMap pipeline;
  late String branchPolicy;
  late String continuousIntegration;
  late String releaseBuild;
  late String releaseValidate;
  late String releaseWindows;
  late String safariSmoke;
  late Map<String, YamlMap> workflows;

  setUpAll(() {
    pipelineFile = _readNormalized('yggdrasil.yml');
    pipeline = loadYaml(pipelineFile) as YamlMap;
    branchPolicy = _readNormalized('ci/branch-policy.sh');
    continuousIntegration = _readNormalized('.github/workflows/ci.yml');
    releaseBuild = _readNormalized('ci/release-build.sh');
    releaseValidate = _readNormalized('ci/release-validate.sh');
    releaseWindows = _readNormalized('.github/workflows/release-windows.yml');
    safariSmoke = _readNormalized('tests/web/safari_smoke.dart');
    workflows = <String, YamlMap>{
      for (final file
          in Directory('.github/workflows')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.yml')))
        file.uri.pathSegments.last:
            loadYaml(_readNormalized(file.path)) as YamlMap,
    };
  });

  test(
    'GivenPipelineFile_WhenChecksAreListed_ThenTheyAreTheCatalogChecksInOrder',
    () {
      final checks = pipeline['checks'] as YamlMap;

      expect(checks.keys.cast<String>().toList(), _checks);
      for (final name in _checks) {
        final check = checks[name] as YamlMap;
        expect(check['run'], 'ci/$name.sh');
        expect(File('ci/$name.sh').existsSync(), isTrue, reason: name);
        expect(
          check['image'] as String,
          matches(RegExp(r'^[^\s@]+:[^\s@]+@sha256:[0-9a-f]{64}$')),
          reason: '$name: images are pinned by version and digest',
        );
      }
      expect((checks['container'] as YamlMap)['docker'], isTrue);
    },
  );

  test('GivenWorkflows_WhenJobsAreListed_ThenOnlyWindowsAndMacosJobsRemainUnderTheirGitHubNames', () {
    final names = <String>[];
    for (final MapEntry(key: file, value: workflow) in workflows.entries) {
      final jobs = workflow['jobs'] as YamlMap;
      for (final job in jobs.values.cast<YamlMap>()) {
        final runner = job['runs-on'] as String;
        expect(runner, anyOf('windows-latest', 'macos-latest'), reason: file);
        expect(job['needs'], isNull, reason: '$file: no job to wait for');
        if (file != 'release-windows.yml') {
          names.add(job['name'] as String);
        }
      }
    }

    expect(names, unorderedEquals(_actionsChecks));
    expect(File('.github/workflows/branch-policy.yml').existsSync(), isFalse);
    expect(
      File('.github/workflows/release-artifacts.yml').existsSync(),
      isFalse,
    );
    expect(File('.github/dependabot.yml').existsSync(), isFalse);
  });

  // Pull requests exist only on Forgejo; the mirror pushes every branch, and Jenkins copies the results of the
  // pull request's head commit. A job that skips a branch or a path would leave its required check pending.
  test(
    'GivenActionsChecks_WhenTheMirrorPushesAnyBranch_ThenTheyRunUnfiltered',
    () {
      for (final MapEntry(key: file, value: workflow) in workflows.entries) {
        final on = workflow['on'] as YamlMap;
        if (file == 'release-windows.yml') {
          expect(on.keys.cast<String>().toList(), <String>[
            'workflow_dispatch',
          ]);
          continue;
        }
        final push = on['push'] as YamlMap;

        expect((push['branches'] as YamlList).cast<String>(), <String>[
          '**',
        ], reason: file);
        expect(push.containsKey('paths'), isFalse, reason: file);
        expect(on.containsKey('pull_request'), isFalse, reason: file);
        expect(on.containsKey('workflow_dispatch'), isTrue, reason: file);
      }
    },
  );

  test('GivenPullRequest_WhenBranchPolicyRuns_ThenReleasesAreCheckedAgainstThePipelineCatalog', () {
    final policy = pipeline['branchPolicy'] as YamlMap;

    expect(policy['run'], 'ci/branch-policy.sh');
    expect(branchPolicy, contains('if [ "\$base" != main ]; then'));
    expect(
      branchPolicy,
      contains(
        'dart tool/validate_release_readiness.dart --version "\$version"',
      ),
    );
    expect(
      branchPolicy,
      contains('python3 "\$yggdrasil/scripts/catalog.py" validate'),
    );
    expect(
      branchPolicy,
      contains(
        'python3 tool/validate_yggdrasil_contract.py "\$yggdrasil/catalog.yaml"',
      ),
    );
    expect(
      branchPolicy,
      contains(
        'PYTHONPATH="\$yggdrasil/scripts\${PYTHONPATH:+:\$PYTHONPATH}" '
        'python3 -m unittest test_catalog.ChimeraCatalogTests',
      ),
    );
    expect(branchPolicy, isNot(contains('-k ChimeraCatalogTests')));
    expect(branchPolicy, isNot(contains('github.com')));
  });

  test(
    'GivenBrowserCheck_WhenWebTestsRun_ThenEverySupportedBrowserIsCovered',
    () {
      final browserTests = _readNormalized('ci/browser-tests.sh');
      final playwright = _readNormalized('tests/web/playwright.config.mjs');

      expect(browserTests, contains('browsers=(chromium firefox webkit)'));
      expect(browserTests, contains('--no-web-resources-cdn'));
      expect(browserTests, contains('cd tests/web'));
      for (final browser in <String>['chromium', 'firefox', 'webkit']) {
        expect(playwright, contains("name: '$browser'"));
      }
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
    expect(safariSmoke, contains('sendChord: driver.keyboard.sendChord'));
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

  test('GivenNativeChecks_WhenBuildsRun_ThenWindowsAndLinuxAreCovered', () {
    final nativeLinux = _readNormalized('ci/native-linux.sh');
    final jobs = workflows['ci.yml']!['jobs'] as YamlMap;
    final native = jobs['native-tests'] as YamlMap;
    final steps = (native['steps'] as YamlList).cast<YamlMap>();
    final windows = steps.singleWhere(
      (step) => step['name'] == 'Test Windows integration',
    );

    expect(native['runs-on'], 'windows-latest');
    expect(windows['run'], 'dart run tool/run_native_gui_tests.dart windows');
    expect(windows['working-directory'], isNull);
    expect(
      nativeLinux,
      contains('xvfb-run -a dart run tool/run_native_gui_tests.dart linux'),
    );
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
      nativeLinux,
      contains('mkdir -p build/cli/linux'),
      reason: 'The Linux AOT compiler does not create parent directories.',
    );
  });

  test(
    'GivenReleaseBuild_WhenPackagingRuns_ThenVerificationCompletesFirst',
    () {
      final verify = releaseBuild.indexOf(
        'dart tool/validate_release_readiness.dart --version "\$version"',
      );
      final package = releaseBuild.indexOf('sh tool/package_linux.sh');

      expect(verify, isNonNegative);
      expect(package, greaterThan(verify));
      expect(releaseBuild, contains('dart run melos run test:unit'));
      expect(
        releaseBuild,
        contains(
          'dart test test tests/deployment tests/update tests/performance',
        ),
      );
      expect(releaseWindows, contains('tool/package_windows.ps1'));
    },
  );

  test('GivenRelease_WhenArtifactsArePublished_ThenIntegrityAndMetadataAreValidatedTogether', () {
    final release = pipeline['release'] as YamlMap;
    final build = release['build'] as YamlMap;
    final windows = release['windows'] as YamlMap;
    final validate = release['validate'] as YamlMap;

    expect(build['run'], 'ci/release-build.sh');
    expect((build['files'] as YamlList).cast<String>(), <String>[
      'dist/linux/*',
    ]);
    expect(windows['workflow'], 'release-windows.yml');
    expect((windows['files'] as YamlList).cast<String>(), <String>[
      'chimera-windows-packages/*',
    ]);
    expect(validate['run'], 'ci/release-validate.sh');

    expect(releaseBuild, contains('tool/write_checksums.dart'));
    expect(releaseWindows, contains('tool/write_checksums.dart'));
    expect(releaseWindows, contains('.sha256'));
    expect(releaseWindows, contains('.release.json'));
    expect(releaseWindows, contains('name: chimera-windows-packages'));
    expect(releaseWindows, contains('actions/upload-artifact@'));
    expect(releaseWindows, contains('cancel-in-progress: false'));
    expect(releaseWindows, contains('inputs.tag'));
    expect(
      releaseValidate,
      contains('dart run tool/validate_release_bundle.dart "\$bundle"'),
    );
    expect(releaseValidate, contains(r'$files/build/dist/linux'));
    expect(
      releaseValidate,
      contains(r'$files/windows/chimera-windows-packages'),
    );
  });

  test('GivenLinuxRelease_WhenPackagesAreBuilt_ThenTheInstalledPackagesAreSmokeTested', () {
    expect(releaseBuild, contains('dpkg --install'));
    expect(releaseBuild, contains('xvfb-run -a timeout 5s chimera-gui'));
    expect(releaseBuild, contains('"\$status" -ne 124'));
  });

  test('GivenChecks_WhenEvidenceIsProduced_ThenItIsArchived', () {
    final checks = pipeline['checks'] as YamlMap;
    final analyze =
        (checks['analyze-and-test'] as YamlMap)['archive'] as String;
    final accessibility =
        (checks['accessibility-performance'] as YamlMap)['archive'] as String;

    expect(analyze, contains('evidence/unit-tests.txt'));
    expect(analyze, contains('coverage/dart/lcov.info'));
    expect(accessibility, contains('docs/operations/accessibility-review.md'));
    expect(
      accessibility,
      contains('tests/performance/acceptance_thresholds.json'),
    );
    expect(accessibility, contains('apps/chimera_gui/coverage/lcov.info'));
    expect(
      _readNormalized('ci/analyze-and-test.sh'),
      contains('dart test --concurrency=2 --coverage='),
    );
    expect(
      _readNormalized('ci/accessibility-performance.sh'),
      contains('flutter test --coverage'),
    );
  });

  test('GivenReleaseWorkflow_WhenPermissionsAreScoped_ThenItOnlyReads', () {
    expect(releaseWindows, contains('permissions:\n  contents: read'));
    expect(releaseWindows, isNot(contains('contents: write')));
  });

  test('GivenJenkins_WhenItBuildsChimera_ThenTheSharedPipelineReadsThePipelineFile', () {
    expect(File('Jenkinsfile').existsSync(), isFalse);
    expect(pipeline.keys.cast<String>().toSet(), <String>{
      'checks',
      'branchPolicy',
      'release',
    });
    expect(
      (pipeline['release'] as YamlMap).keys.cast<String>().toSet(),
      <String>{'build', 'windows', 'validate'},
    );
  });
}

String _readNormalized(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
