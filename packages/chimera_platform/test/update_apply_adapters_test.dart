import 'dart:async';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_updates.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'chimera-update-adapter-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'GivenGithubArtifact_WhenDownloaded_ThenBytesAreStreamedToDestination',
    () async {
      late http.Request observedRequest;
      final destination = File('${temporaryDirectory.path}/artifact.exe');
      final downloader = HttpUpdateArtifactDownloader(
        client: MockClient((request) async {
          observedRequest = request;
          return http.Response.bytes(<int>[1, 2, 3, 4], 200);
        }),
      );

      final result = await downloader.download(
        source: _artifactUri('artifact.exe'),
        destinationPath: destination.path,
      );

      expect(result, isA<ChimeraSuccess<void>>());
      expect(await destination.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(observedRequest.headers['accept'], 'application/octet-stream');
      expect(observedRequest.headers['user-agent'], 'Chimera-update-apply');
    },
  );

  test('GivenOversizedDeclaredArtifact_WhenDownloaded_ThenBodyIsCancelledAndNoPartialFileRemains', () async {
    final cancelled = Completer<void>();
    final controller = StreamController<List<int>>(
      onCancel: () => cancelled.complete(),
    );
    final destination = File('${temporaryDirectory.path}/artifact.exe');
    final downloader = HttpUpdateArtifactDownloader(
      client: _SingleResponseClient(
        http.StreamedResponse(controller.stream, 200, contentLength: 5),
      ),
      maxArtifactBytes: 4,
    );

    final result = await downloader.download(
      source: _artifactUri('artifact.exe'),
      destinationPath: destination.path,
    );

    _expectFailure(result, 'update-download-too-large');
    await expectLater(cancelled.future, completes);
    expect(await destination.exists(), isFalse);
  });

  test('GivenNonSuccessResponse_WhenDownloaded_ThenBodyIsCancelledAndNoPartialFileRemains', () async {
    final cancelled = Completer<void>();
    final controller = StreamController<List<int>>(
      onCancel: () => cancelled.complete(),
    );
    final destination = File('${temporaryDirectory.path}/artifact.exe');
    final downloader = HttpUpdateArtifactDownloader(
      client: _SingleResponseClient(
        http.StreamedResponse(controller.stream, 503),
      ),
    );

    final result = await downloader.download(
      source: _artifactUri('artifact.exe'),
      destinationPath: destination.path,
    );

    _expectFailure(result, 'update-download-request-failed');
    await expectLater(cancelled.future, completes);
    expect(await destination.exists(), isFalse);
  });

  test(
    'GivenStreamExceedsLimit_WhenDownloaded_ThenPartialFileIsRemoved',
    () async {
      final destination = File('${temporaryDirectory.path}/artifact.exe');
      final downloader = HttpUpdateArtifactDownloader(
        client: _SingleResponseClient(
          http.StreamedResponse(
            Stream<List<int>>.fromIterable(<List<int>>[
              <int>[1, 2, 3],
              <int>[4, 5],
            ]),
            200,
          ),
        ),
        maxArtifactBytes: 4,
      );

      final result = await downloader.download(
        source: _artifactUri('artifact.exe'),
        destinationPath: destination.path,
      );

      _expectFailure(result, 'update-download-too-large');
      expect(await destination.exists(), isFalse);
    },
  );

  test('GivenDownloadTimeout_WhenDownloading_ThenRequestIsAbortedAndNoPartialFileRemains', () async {
    final client = _StallingClient();
    final destination = File('${temporaryDirectory.path}/artifact.exe');
    final downloader = HttpUpdateArtifactDownloader(
      client: client,
      requestTimeout: const Duration(milliseconds: 10),
    );

    final result = await downloader.download(
      source: _artifactUri('artifact.exe'),
      destinationPath: destination.path,
    );

    _expectFailure(result, 'update-download-timeout');
    await expectLater(
      client.abortObserved.future.timeout(const Duration(seconds: 1)),
      completes,
    );
    expect(await destination.exists(), isFalse);
  });

  test(
    'GivenNonGithubOrInsecureSource_WhenDownloaded_ThenRequestIsRejected',
    () async {
      final client = _CountingClient();
      final downloader = HttpUpdateArtifactDownloader(client: client);

      for (final source in <Uri>[
        Uri.parse('http://github.com/example/artifact.exe'),
        Uri.parse('https://example.test/artifact.exe'),
      ]) {
        final result = await downloader.download(
          source: source,
          destinationPath: '${temporaryDirectory.path}/artifact.exe',
        );
        _expectFailure(result, 'update-download-invalid-source');
      }

      expect(client.calls, 0);
    },
  );

  test(
    'GivenStagedArtifact_WhenCleaned_ThenOnlyStorageOwnedRootIsRemoved',
    () async {
      final storage = NativeUpdateTemporaryStorage();
      final created = await storage.createFor(_artifactUri('artifact.exe'));
      final artifact =
          (created as ChimeraSuccess<TemporaryUpdateArtifact>).value;
      await File(artifact.artifactPath).writeAsBytes(<int>[1]);

      final firstCleanup = await storage.cleanup(artifact);
      final secondCleanup = await storage.cleanup(artifact);

      expect(firstCleanup, isA<ChimeraSuccess<void>>());
      _expectFailure(secondCleanup, 'update-staging-cleanup-rejected');
      expect(await Directory(artifact.rootPath).exists(), isFalse);
    },
  );

  test('GivenArtifactAndPublishedDigest_WhenVerified_ThenExactSha256ResultIsReturned', () async {
    final artifact = File('${temporaryDirectory.path}/artifact.bin');
    await artifact.writeAsString('chimera');
    const verifier = Sha256UpdateChecksumVerifier();

    final matches = await verifier.verifySha256(
      path: artifact.path,
      expectedDigest:
          'ae391de9c5171466f31ef5ac920cfd3901bcc01aa28c2b02dc13b1ab3d6f2063',
    );
    final mismatch = await verifier.verifySha256(
      path: artifact.path,
      expectedDigest: '0' * 64,
    );

    expect((matches as ChimeraSuccess<bool>).value, isTrue);
    expect((mismatch as ChimeraSuccess<bool>).value, isFalse);
  });

  test('GivenVerifiedWindowsInstaller_WhenInstalled_ThenDetachedParentExitHandoffOwnsCleanup', () async {
    final runner = _RecordingRunner();
    final installer = NativeUpdateInstaller(
      platform: ReleasePlatform.windows,
      runner: runner,
      windowsDirectory: r'C:\Windows',
    );

    final result = await installer.install(
      release: _release(ReleasePlatform.windows),
      artifactPath: r'C:\temp\chimera-update-test\update.exe',
    );

    final value = (result as ChimeraSuccess<UpdateInstallResult>).value;
    expect(value.restartRequired, isTrue);
    expect(value.cleanupDeferred, isTrue);
    expect(value.status, UpdateApplyStatus.scheduled);
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.detached, isTrue);
    expect(
      runner.calls.single.executable,
      r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
    );
    expect(
      runner.calls.single.args,
      contains(r'C:\temp\chimera-update-test\update.exe'),
    );
    expect(runner.calls.single.args, contains(r'C:\temp\chimera-update-test'));
    expect(
      runner.calls.single.args.join(' '),
      allOf(
        contains('Wait-Process'),
        contains('Start-Process'),
        contains('ChimeraCliUpdateHandoff'),
        contains('Remove-Item -LiteralPath'),
      ),
    );
  });

  test('GivenVerifiedLinuxInstaller_WhenInstalled_ThenPreflightAndFixedCommandRunWithoutShell', () async {
    final runner = _RecordingRunner();
    final installer = NativeUpdateInstaller(
      platform: ReleasePlatform.linux,
      runner: runner,
    );

    final result = await installer.install(
      release: _release(ReleasePlatform.linux),
      artifactPath: '/tmp/update.deb',
    );

    final value = (result as ChimeraSuccess<UpdateInstallResult>).value;
    expect(value.cleanupDeferred, isFalse);
    expect(runner.calls, hasLength(2));
    expect(runner.calls[0].executable, 'dpkg');
    expect(runner.calls[0].args, <String>[
      '--no-act',
      '--install',
      '/tmp/update.deb',
    ]);
    expect(runner.calls[0].detached, isFalse);
    expect(runner.calls[1].executable, 'pkexec');
    expect(runner.calls[1].args, <String>[
      'dpkg',
      '--no-triggers',
      '--install',
      '/tmp/update.deb',
    ]);
    expect(runner.calls[1].detached, isFalse);
  });

  test('GivenElevationOrInstallerFailure_WhenInstalled_ThenTypedFailureContainsNoProcessOutput', () async {
    final runner = _RecordingRunner(exitCodes: <int>[0, 126]);
    final installer = NativeUpdateInstaller(
      platform: ReleasePlatform.linux,
      runner: runner,
    );

    final result = await installer.install(
      release: _release(ReleasePlatform.linux),
      artifactPath: '/tmp/update.deb',
    );

    final failure = _expectFailure(result, 'update-elevation-denied');
    expect(failure.messageKey, 'error.update.elevationDenied');
    expect(failure.details, isEmpty);
  });

  test(
    'GivenLinuxPreflightFailure_WhenInstalled_ThenElevationIsNotRequested',
    () async {
      final runner = _RecordingRunner(exitCodes: <int>[1]);
      final installer = NativeUpdateInstaller(
        platform: ReleasePlatform.linux,
        runner: runner,
      );

      final result = await installer.install(
        release: _release(ReleasePlatform.linux),
        artifactPath: '/tmp/update.deb',
      );

      _expectFailure(result, 'update-install-preflight-failed');
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.executable, 'dpkg');
    },
  );

  test(
    'GivenDesktopAndCliWindowsUpdates_WhenHandedOff_ThenMutexesDoNotCollide',
    () async {
      final runner = _RecordingRunner();
      final installer = NativeUpdateInstaller(
        platform: ReleasePlatform.windows,
        runner: runner,
        windowsDirectory: r'C:\Windows',
      );

      await installer.install(
        release: _release(
          ReleasePlatform.windows,
          application: ReleaseApplication.desktop,
        ),
        artifactPath: r'C:\temp\chimera-update-desktop\update.exe',
      );
      await installer.install(
        release: _release(ReleasePlatform.windows),
        artifactPath: r'C:\temp\chimera-update-cli\update.exe',
      );

      expect(runner.calls, hasLength(2));
      expect(
        runner.calls[0].args,
        contains(r'Local\ChimeraDesktopUpdateHandoff'),
      );
      expect(runner.calls[1].args, contains(r'Local\ChimeraCliUpdateHandoff'));
    },
  );

  test('GivenLinuxInstallFailureAfterPreflight_WhenInstalled_ThenTypedFailureIsReturned', () async {
    final runner = _RecordingRunner(exitCodes: <int>[0, 1]);
    final installer = NativeUpdateInstaller(
      platform: ReleasePlatform.linux,
      runner: runner,
    );

    final result = await installer.install(
      release: _release(ReleasePlatform.linux),
      artifactPath: '/tmp/update.deb',
    );

    _expectFailure(result, 'update-install-process-failed');
    expect(runner.calls, hasLength(2));
  });

  test('GivenPkexecIsUnavailable_WhenInstalled_ThenActionableElevationFailureIsReturned', () async {
    final runner = _RecordingRunner(throwOnCall: 2);
    final installer = NativeUpdateInstaller(
      platform: ReleasePlatform.linux,
      runner: runner,
    );

    final result = await installer.install(
      release: _release(ReleasePlatform.linux),
      artifactPath: '/tmp/update.deb',
    );

    final failure = _expectFailure(result, 'update-elevation-denied');
    expect(failure.messageKey, 'error.update.elevationDenied');
  });
}

Uri _artifactUri(String name) => Uri.parse(
  'https://github.com/artur-rios/chimera/releases/download/v2.0.0/$name',
);

ReleaseMetadata _release(
  ReleasePlatform platform, {
  ReleaseApplication application = ReleaseApplication.cli,
}) => ReleaseMetadata(
  releaseVersion: SemanticVersion.parse('2.0.0'),
  platform: platform,
  application: application,
  packageType: ReleasePackageType.installer,
  downloadUrl: _artifactUri(
    platform == ReleasePlatform.windows ? 'update.exe' : 'update.deb',
  ),
  checksum: 'a' * 64,
);

ChimeraFailure<T> _expectFailure<T>(ChimeraResult<T> result, String code) {
  expect(result, isA<ChimeraFailure<T>>());
  final failure = result as ChimeraFailure<T>;
  expect(failure.kind, FailureKind.update);
  expect(failure.code, code);
  return failure;
}

final class _SingleResponseClient extends http.BaseClient {
  _SingleResponseClient(this.response);

  final http.StreamedResponse response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}

final class _StallingClient extends http.BaseClient {
  final Completer<void> abortObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request case http.AbortableRequest(:final abortTrigger?)) {
      final response = Completer<http.StreamedResponse>();
      abortTrigger.then((_) {
        abortObserved.complete();
        response.completeError(http.RequestAbortedException(request.url));
      });
      return response.future;
    }
    return Completer<http.StreamedResponse>().future;
  }
}

final class _CountingClient extends http.BaseClient {
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}

final class _RecordingRunner implements UpdateProcessRunner {
  _RecordingRunner({int exitCode = 0, List<int>? exitCodes, this.throwOnCall})
    : _exitCodes = exitCodes ?? <int>[exitCode];

  final List<int> _exitCodes;
  final int? throwOnCall;
  final List<({String executable, List<String> args, bool detached})> calls =
      <({String executable, List<String> args, bool detached})>[];

  @override
  Future<UpdateProcessResult> run(
    String executable,
    List<String> arguments,
  ) async {
    calls.add((
      executable: executable,
      args: List<String>.of(arguments),
      detached: false,
    ));
    if (calls.length == throwOnCall) {
      throw ProcessException(executable, arguments);
    }
    final index = calls.length - 1;
    final exitCode = index < _exitCodes.length ? _exitCodes[index] : 0;
    return UpdateProcessResult(exitCode);
  }

  @override
  Future<void> startDetached(String executable, List<String> arguments) async {
    calls.add((
      executable: executable,
      args: List<String>.of(arguments),
      detached: true,
    ));
  }
}
