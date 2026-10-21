import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenApprovalMissing_WhenApplyRequested_ThenNoSideEffectIsAttempted',
    () async {
      final fixture = _Fixture();

      final result = await fixture.service.apply(
        UpdateApplyRequest(release: _release(), accepted: false),
      );

      _expectFailure(result, 'update-approval-required');
      expect(fixture.events, isEmpty);
    },
  );

  test(
    'GivenPortableRelease_WhenApplyRequested_ThenUnsafeReplacementIsRejected',
    () async {
      final fixture = _Fixture();

      final result = await fixture.service.apply(
        UpdateApplyRequest(
          release: _release(packageType: ReleasePackageType.portable),
          accepted: true,
        ),
      );

      _expectFailure(result, 'unsupported-update-package');
      expect(fixture.events, isEmpty);
    },
  );

  test('GivenAcceptedInstaller_WhenEveryBoundarySucceeds_ThenVerifiedArtifactIsInstalledAndCleaned', () async {
    final fixture = _Fixture();

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    expect(result, isA<ChimeraSuccess<UpdateApplyResult>>());
    final output = (result as ChimeraSuccess<UpdateApplyResult>).value;
    expect(output.release.releaseVersion.toString(), '2.0.0');
    expect(output.restartRequired, isTrue);
    expect(output.status, UpdateApplyStatus.applied);
    expect(fixture.events, <String>[
      'create',
      'download',
      'verify',
      'install',
      'cleanup',
    ]);
  });

  test('GivenInstallerOwnsDeferredCleanup_WhenApplied_ThenStorageDoesNotRaceTheHandoff', () async {
    final fixture = _Fixture(installerDefersCleanup: true);

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    expect(result, isA<ChimeraSuccess<UpdateApplyResult>>());
    expect(
      (result as ChimeraSuccess<UpdateApplyResult>).value.status,
      UpdateApplyStatus.scheduled,
    );
    expect(fixture.events, <String>['create', 'download', 'verify', 'install']);
  });

  for (final scenario in <({String boundary, String expectedCode})>[
    (boundary: 'create', expectedCode: 'update-download-failed'),
    (boundary: 'download', expectedCode: 'update-download-failed'),
    (boundary: 'verify', expectedCode: 'update-checksum-failed'),
    (boundary: 'install', expectedCode: 'update-install-failed'),
  ]) {
    test(
      'Given${scenario.boundary}Failure_WhenApplyRequested_ThenTypedFailureShortCircuitsAndStagingIsCleaned',
      () async {
        final fixture = _Fixture(failingBoundary: scenario.boundary);

        final result = await fixture.service.apply(
          UpdateApplyRequest(release: _release(), accepted: true),
        );

        _expectFailure(result, scenario.expectedCode);
        if (scenario.boundary == 'create') {
          expect(fixture.events, <String>['create']);
        } else {
          expect(fixture.events.last, 'cleanup');
          expect(
            fixture.events.where((event) => event == 'cleanup'),
            hasLength(1),
          );
        }
        expect(
          fixture.events.contains('install'),
          scenario.boundary == 'install',
        );
      },
    );
  }

  test('GivenChecksumMismatch_WhenApplyRequested_ThenInstallerIsNotCalledAndStagingIsCleaned', () async {
    final fixture = _Fixture(checksumMatches: false);

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    _expectFailure(result, 'update-checksum-failed');
    expect(fixture.events, <String>['create', 'download', 'verify', 'cleanup']);
  });

  test('GivenBoundaryThrows_WhenApplyRequested_ThenSafeFailureIsReturnedAndStagingIsCleaned', () async {
    final fixture = _Fixture(throwingBoundary: 'verify');

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    final failure = _expectFailure(result, 'update-checksum-failed');
    expect(failure.details.toString(), isNot(contains('private-path')));
    expect(fixture.events.last, 'cleanup');
  });

  test(
    'GivenElevationIsDenied_WhenInstalling_ThenActionableFailureIsPreserved',
    () async {
      final fixture = _Fixture(
        failingBoundary: 'install',
        installerFailureCode: 'update-elevation-denied',
      );

      final result = await fixture.service.apply(
        UpdateApplyRequest(release: _release(), accepted: true),
      );

      final failure = _expectFailure(result, 'update-elevation-denied');
      expect(failure.messageKey, 'error.update.elevationDenied');
      expect(failure.details, isEmpty);
      expect(fixture.events.last, 'cleanup');
    },
  );

  test('GivenCleanupFailsAfterInstall_WhenApplyRequested_ThenCleanupFailureIsReported', () async {
    final fixture = _Fixture(failingBoundary: 'cleanup');

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    _expectFailure(result, 'update-cleanup-failed');
    expect(fixture.events.last, 'cleanup');
  });

  test('GivenPrimaryAndCleanupFailures_WhenApplyRequested_ThenCleanupFailureRetainsSafePriorCode', () async {
    final fixture = _Fixture(failingBoundary: 'download', cleanupFails: true);

    final result = await fixture.service.apply(
      UpdateApplyRequest(release: _release(), accepted: true),
    );

    final failure = _expectFailure(result, 'update-cleanup-failed');
    expect(failure.details, <String, Object?>{
      'priorCode': 'update-download-failed',
    });
    expect(failure.details.toString(), isNot(contains('private-path')));
  });
}

ReleaseMetadata _release({
  ReleasePackageType packageType = ReleasePackageType.installer,
}) => ReleaseMetadata(
  releaseVersion: SemanticVersion.parse('2.0.0'),
  platform: ReleasePlatform.windows,
  application: ReleaseApplication.cli,
  packageType: packageType,
  downloadUrl: Uri.parse(
    'https://github.com/artur-rios/chimera/releases/download/v2.0.0/'
    'chimera-cli-windows-x64-installer.exe',
  ),
  checksum: 'a' * 64,
);

ChimeraFailure<UpdateApplyResult> _expectFailure(
  ChimeraResult<UpdateApplyResult> result,
  String code,
) {
  expect(result, isA<ChimeraFailure<UpdateApplyResult>>());
  final failure = result as ChimeraFailure<UpdateApplyResult>;
  expect(failure.kind, FailureKind.update);
  expect(failure.code, code);
  return failure;
}

final class _Fixture {
  _Fixture({
    this.failingBoundary,
    this.throwingBoundary,
    this.checksumMatches = true,
    this.cleanupFails = false,
    this.installerFailureCode,
    this.installerDefersCleanup = false,
  }) {
    service = UpdateApplyService(
      storage: _Storage(this),
      downloader: _Downloader(this),
      verifier: _Verifier(this),
      installer: _Installer(this),
    );
  }

  final String? failingBoundary;
  final String? throwingBoundary;
  final bool checksumMatches;
  final bool cleanupFails;
  final String? installerFailureCode;
  final bool installerDefersCleanup;
  final List<String> events = <String>[];
  late final UpdateApplyService service;

  ChimeraResult<T> result<T>(String boundary, T success) {
    events.add(boundary);
    if (throwingBoundary == boundary) {
      throw StateError('private-path');
    }
    if (failingBoundary == boundary ||
        (cleanupFails && boundary == 'cleanup')) {
      return ChimeraFailure<T>(
        kind: FailureKind.resource,
        code: '$boundary-private-failure',
        messageKey: 'private.message',
        details: const <String, Object?>{'path': 'private-path'},
      );
    }
    return ChimeraSuccess<T>(success);
  }
}

final class _Storage implements UpdateTemporaryStorage {
  const _Storage(this.fixture);

  final _Fixture fixture;

  @override
  Future<ChimeraResult<TemporaryUpdateArtifact>> createFor(Uri source) async =>
      fixture.result(
        'create',
        const TemporaryUpdateArtifact(
          rootPath: 'temporary-root',
          artifactPath: 'temporary-root/update.exe',
        ),
      );

  @override
  Future<ChimeraResult<void>> cleanup(TemporaryUpdateArtifact artifact) async =>
      fixture.result('cleanup', null);
}

final class _Downloader implements UpdateArtifactDownloader {
  const _Downloader(this.fixture);

  final _Fixture fixture;

  @override
  Future<ChimeraResult<void>> download({
    required Uri source,
    required String destinationPath,
  }) async => fixture.result('download', null);
}

final class _Verifier implements UpdateChecksumVerifier {
  const _Verifier(this.fixture);

  final _Fixture fixture;

  @override
  Future<ChimeraResult<bool>> verifySha256({
    required String path,
    required String expectedDigest,
  }) async => fixture.result('verify', fixture.checksumMatches);
}

final class _Installer implements UpdateInstaller {
  const _Installer(this.fixture);

  final _Fixture fixture;

  @override
  Future<ChimeraResult<UpdateInstallResult>> install({
    required ReleaseMetadata release,
    required String artifactPath,
  }) async {
    if (fixture.installerFailureCode case final code?) {
      fixture.events.add('install');
      return ChimeraFailure<UpdateInstallResult>(
        kind: FailureKind.update,
        code: code,
        messageKey: 'private.message',
        details: const <String, Object?>{'path': 'private-path'},
      );
    }
    return fixture.result(
      'install',
      UpdateInstallResult(
        restartRequired: true,
        cleanupDeferred: fixture.installerDefersCleanup,
        status: fixture.installerDefersCleanup
            ? UpdateApplyStatus.scheduled
            : UpdateApplyStatus.applied,
      ),
    );
  }
}
