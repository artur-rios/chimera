import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenUpdateApplyHelp_WhenRequested_ThenSpecificUsageIsPrinted',
    () async {
      final out = StringBuffer();

      final code = await runChimera(
        <String>['--help', 'update', 'apply'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(code, 0);
      expect(out.toString(), contains('chimera update apply --yes'));
    },
  );

  test(
    'GivenInvalidApplyOptionsAsJson_WhenParsed_ThenStableJsonFailureIsPrinted',
    () async {
      final err = StringBuffer();

      final code = await runChimera(
        <String>['update', 'apply', '--yes', '--platform=macos', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(code, 64);
      expect(
        (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
        containsPair('code', 'update-invalid-options'),
      );
    },
  );

  test(
    'GivenUnexpectedApplyOperand_WhenParsed_ThenItIsRejectedBeforeChecking',
    () async {
      final fixture = _Fixture();
      final err = StringBuffer();

      final code = await runChimera(
        <String>['update', 'apply', '--yes', '2.0.0', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 64);
      expect(
        (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
        containsPair('code', 'update-invalid-options'),
      );
      expect(fixture.source.calls, 0);
      expect(fixture.events, isEmpty);
    },
  );

  test(
    'GivenPortableApplyOption_WhenParsed_ThenItIsRejectedBeforeChecking',
    () async {
      final fixture = _Fixture();
      final err = StringBuffer();

      final code = await runChimera(
        <String>[
          'update',
          'apply',
          '--yes',
          '--package-type=portable',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 64);
      expect(
        (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
        containsPair('code', 'update-invalid-options'),
      );
      expect(fixture.source.calls, 0);
      expect(fixture.events, isEmpty);
    },
  );

  test(
    'GivenForeignPlatform_WhenApplyRequested_ThenItIsRejectedBeforeChecking',
    () async {
      final fixture = _Fixture();
      final err = StringBuffer();
      final foreignPlatform = Platform.isWindows ? 'linux' : 'windows';

      final code = await runChimera(
        <String>[
          'update',
          'apply',
          '--yes',
          '--platform=$foreignPlatform',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 64);
      expect(
        (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
        containsPair('code', 'update-invalid-options'),
      );
      expect(fixture.source.calls, 0);
      expect(fixture.events, isEmpty);
    },
  );

  test('GivenApprovalFlagMissing_WhenApplyRequested_ThenNoCheckDownloadOrInstallOccurs', () async {
    final fixture = _Fixture();
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await runChimera(
      <String>['update', 'apply', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      updateCheckService: fixture.checkService,
      updateApplyService: fixture.applyService,
    );

    expect(code, 69);
    expect(out, isEmpty);
    expect(jsonDecode(err.toString()), <String, Object?>{
      'error': <String, Object?>{
        'kind': 'update',
        'code': 'update-approval-required',
        'message': 'Approval is required before downloading an update.',
      },
    });
    expect(fixture.source.calls, 0);
    expect(fixture.events, isEmpty);
  });

  test(
    'GivenAcceptedCompatibleUpdate_WhenApplySucceeds_ThenStableJsonIsPrinted',
    () async {
      final fixture = _Fixture();
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await runChimera(
        <String>[
          'update',
          'apply',
          '--yes',
          '--json',
          '--current-version=1.0.0',
          '--platform=$_hostPlatformName',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 0);
      expect(err, isEmpty);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'status': 'scheduled',
        'installedVersion': '1.0.0',
        'appliedVersion': '2.0.0',
        'restartRequired': true,
      });
      expect(fixture.events, <String>[
        'create',
        'download',
        'verify',
        'install',
      ]);
    },
  );

  test(
    'GivenBrazilianPortuguese_WhenApplySucceeds_ThenLocalizedResultIsPrinted',
    () async {
      final fixture = _Fixture();
      final out = StringBuffer();

      final code = await runChimera(
        <String>['update', 'apply', '--yes', '--current-version=1.0.0'],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 0);
      expect(
        out.toString(),
        'A atualização do Chimera de 1.0.0 para 2.0.0 foi agendada. '
        'Reinicialização necessária: sim.\n',
      );
    },
  );

  test('GivenAcceptedUpdate_WhenApplySucceeds_ThenHumanOutputReportsBothVersionsAndRestart', () async {
    final fixture = _Fixture();
    final out = StringBuffer();

    final code = await runChimera(
      <String>[
        'update',
        'apply',
        '--yes',
        '--current-version=1.0.0',
        '--platform=$_hostPlatformName',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
      updateCheckService: fixture.checkService,
      updateApplyService: fixture.applyService,
    );

    expect(code, 0);
    expect(
      out.toString(),
      'The Chimera update from 1.0.0 to 2.0.0 is scheduled. '
      'Restart required: yes.\n',
    );
  });

  test('GivenNoNewerRelease_WhenApplyRequested_ThenCurrentStatusIsReturnedWithoutApply', () async {
    final fixture = _Fixture(current: true);
    final out = StringBuffer();

    final code = await runChimera(
      <String>['update', 'apply', '--yes', '--current-version=2.0.0'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
      updateCheckService: fixture.checkService,
      updateApplyService: fixture.applyService,
    );

    expect(code, 0);
    expect(out.toString(), 'Chimera 2.0.0 is current.\n');
    expect(fixture.events, isEmpty);
  });

  test('GivenChecksumFailure_WhenApplyRequested_ThenTypedFailureIsPrintedAndInstallerIsNotCalled', () async {
    final fixture = _Fixture(checksumMatches: false);
    final err = StringBuffer();

    final code = await runChimera(
      <String>['update', 'apply', '--yes', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      updateCheckService: fixture.checkService,
      updateApplyService: fixture.applyService,
    );

    expect(code, 69);
    expect(
      (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
      containsPair('code', 'update-checksum-failed'),
    );
    expect(fixture.events, isNot(contains('install')));
    expect(fixture.events.last, 'cleanup');
  });

  test(
    'GivenElevationDenied_WhenApplyRequested_ThenActionableFailureIsPrinted',
    () async {
      final fixture = _Fixture(installerFailureCode: 'update-elevation-denied');
      final err = StringBuffer();

      final code = await runChimera(
        <String>['update', 'apply', '--yes', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        updateCheckService: fixture.checkService,
        updateApplyService: fixture.applyService,
      );

      expect(code, 69);
      expect(jsonDecode(err.toString()), <String, Object?>{
        'error': <String, Object?>{
          'kind': 'update',
          'code': 'update-elevation-denied',
          'message':
              'Administrator permission was not granted. '
              'Approve the system prompt and try the update again.',
        },
      });
      expect(fixture.events.last, 'cleanup');
    },
  );
}

final class _Fixture {
  _Fixture({
    bool current = false,
    bool checksumMatches = true,
    String? installerFailureCode,
  }) : source = _Source(current: current) {
    checkService = UpdateCheckService(source);
    applyService = UpdateApplyService(
      storage: _Storage(events),
      downloader: _Downloader(events),
      verifier: _Verifier(events, checksumMatches),
      installer: _Installer(events, failureCode: installerFailureCode),
    );
  }

  final _Source source;
  final List<String> events = <String>[];
  late final UpdateCheckService checkService;
  late final UpdateApplyService applyService;
}

final class _Source implements ReleaseMetadataSource {
  _Source({required this.current});

  final bool current;
  int calls = 0;

  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async {
    calls++;
    return ChimeraSuccess<List<Map<String, Object?>>>(<Map<String, Object?>>[
      <String, Object?>{
        'releaseVersion': current ? '2.0.0' : '2.0.0',
        'platform': _hostPlatformName,
        'application': 'cli',
        'packageType': 'installer',
        'downloadUrl':
            'https://github.com/artur-rios/chimera/releases/download/v2.0.0/'
            'chimera-cli-windows-x64-installer.exe',
        'checksum': 'a' * 64,
      },
    ]);
  }
}

String get _hostPlatformName => Platform.isWindows ? 'windows' : 'linux';

final class _Storage implements UpdateTemporaryStorage {
  const _Storage(this.events);

  final List<String> events;

  @override
  Future<ChimeraResult<TemporaryUpdateArtifact>> createFor(Uri source) async {
    events.add('create');
    return const ChimeraSuccess<TemporaryUpdateArtifact>(
      TemporaryUpdateArtifact(
        rootPath: 'root',
        artifactPath: 'root/update.exe',
      ),
    );
  }

  @override
  Future<ChimeraResult<void>> cleanup(TemporaryUpdateArtifact artifact) async {
    events.add('cleanup');
    return const ChimeraSuccess<void>(null);
  }
}

final class _Downloader implements UpdateArtifactDownloader {
  const _Downloader(this.events);

  final List<String> events;

  @override
  Future<ChimeraResult<void>> download({
    required Uri source,
    required String destinationPath,
  }) async {
    events.add('download');
    return const ChimeraSuccess<void>(null);
  }
}

final class _Verifier implements UpdateChecksumVerifier {
  const _Verifier(this.events, this.matches);

  final List<String> events;
  final bool matches;

  @override
  Future<ChimeraResult<bool>> verifySha256({
    required String path,
    required String expectedDigest,
  }) async {
    events.add('verify');
    return ChimeraSuccess<bool>(matches);
  }
}

final class _Installer implements UpdateInstaller {
  const _Installer(this.events, {this.failureCode});

  final List<String> events;
  final String? failureCode;

  @override
  Future<ChimeraResult<UpdateInstallResult>> install({
    required ReleaseMetadata release,
    required String artifactPath,
  }) async {
    events.add('install');
    if (failureCode case final code?) {
      return ChimeraFailure<UpdateInstallResult>(
        kind: FailureKind.update,
        code: code,
        messageKey: 'private.message',
        details: const <String, Object?>{'path': 'private-path'},
      );
    }
    return const ChimeraSuccess<UpdateInstallResult>(
      UpdateInstallResult(
        restartRequired: true,
        cleanupDeferred: true,
        status: UpdateApplyStatus.scheduled,
      ),
    );
  }
}
