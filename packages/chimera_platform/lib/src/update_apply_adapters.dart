import 'dart:async';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

final class NativeUpdateTemporaryStorage implements UpdateTemporaryStorage {
  NativeUpdateTemporaryStorage();

  final Set<String> _createdRoots = <String>{};

  @override
  Future<ChimeraResult<TemporaryUpdateArtifact>> createFor(Uri source) async {
    final fileName = p.basename(source.path);
    if (fileName.isEmpty || fileName == '.' || fileName == p.separator) {
      return _failure<TemporaryUpdateArtifact>('update-staging-invalid-source');
    }
    try {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-update-',
      );
      final rootPath = p.normalize(directory.absolute.path);
      _createdRoots.add(rootPath);
      return ChimeraSuccess<TemporaryUpdateArtifact>(
        TemporaryUpdateArtifact(
          rootPath: rootPath,
          artifactPath: p.join(rootPath, fileName),
        ),
      );
    } on Object {
      return _failure<TemporaryUpdateArtifact>('update-staging-create-failed');
    }
  }

  @override
  Future<ChimeraResult<void>> cleanup(TemporaryUpdateArtifact artifact) async {
    final rootPath = p.normalize(p.absolute(artifact.rootPath));
    final artifactPath = p.normalize(p.absolute(artifact.artifactPath));
    if (!_createdRoots.remove(rootPath) ||
        !p.isWithin(rootPath, artifactPath)) {
      return _failure<void>('update-staging-cleanup-rejected');
    }
    try {
      final directory = Directory(rootPath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return const ChimeraSuccess<void>(null);
    } on Object {
      return _failure<void>('update-staging-cleanup-failed');
    }
  }

  ChimeraFailure<T> _failure<T>(String code) => ChimeraFailure<T>(
    kind: FailureKind.update,
    code: code,
    messageKey: 'error.update.cleanupFailed',
  );
}

final class HttpUpdateArtifactDownloader implements UpdateArtifactDownloader {
  HttpUpdateArtifactDownloader({
    http.Client? client,
    this.maxArtifactBytes = 512 * 1024 * 1024,
    this.requestTimeout = const Duration(minutes: 5),
  }) : assert(maxArtifactBytes > 0),
       assert(requestTimeout > Duration.zero),
       // Keep the injected client private while retaining a descriptive
       // public constructor parameter.
       // ignore: prefer_initializing_formals
       _client = client ?? http.Client();

  final http.Client _client;
  final int maxArtifactBytes;
  final Duration requestTimeout;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/octet-stream',
    'User-Agent': 'Chimera-update-apply',
  };

  @override
  Future<ChimeraResult<void>> download({
    required Uri source,
    required String destinationPath,
  }) async {
    if (source.scheme != 'https' || source.host != 'github.com') {
      return _failure('update-download-invalid-source');
    }
    final abort = Completer<void>();
    final operation = _download(
      source: source,
      destinationPath: destinationPath,
      abortTrigger: abort.future,
    );
    try {
      return await operation.timeout(requestTimeout);
    } on TimeoutException {
      abort.complete();
      try {
        await operation.timeout(const Duration(seconds: 1));
      } on Object {
        // IOClient honors the abort trigger. The bounded grace period also
        // prevents an injected non-abortable client from hanging the caller.
      }
      await _deletePartial(destinationPath);
      return _failure('update-download-timeout');
    }
  }

  Future<ChimeraResult<void>> _download({
    required Uri source,
    required String destinationPath,
    required Future<void> abortTrigger,
  }) async {
    final http.StreamedResponse response;
    try {
      final request = http.AbortableRequest(
        'GET',
        source,
        abortTrigger: abortTrigger,
      )..headers.addAll(_headers);
      response = await _client.send(request);
    } on Object {
      await _deletePartial(destinationPath);
      return _failure('update-download-transport-failed');
    }
    if (response.statusCode != 200) {
      await _cancelResponseBody(response);
      await _deletePartial(destinationPath);
      return _failure('update-download-request-failed');
    }
    if (response.contentLength case final contentLength?
        when contentLength > maxArtifactBytes) {
      await _cancelResponseBody(response);
      await _deletePartial(destinationPath);
      return _failure('update-download-too-large');
    }

    RandomAccessFile? output;
    try {
      output = await File(destinationPath).open(mode: FileMode.write);
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxArtifactBytes) {
          throw const _ArtifactTooLarge();
        }
        await output.writeFrom(chunk);
      }
      await output.flush();
      await output.close();
      output = null;
      return const ChimeraSuccess<void>(null);
    } on _ArtifactTooLarge {
      await _close(output);
      output = null;
      await _deletePartial(destinationPath);
      return _failure('update-download-too-large');
    } on Object {
      await _close(output);
      output = null;
      await _deletePartial(destinationPath);
      return _failure('update-download-write-failed');
    } finally {
      await _close(output);
    }
  }

  Future<void> _cancelResponseBody(http.StreamedResponse response) async {
    try {
      await response.stream.listen((_) {}).cancel();
    } on Object {
      // The safe request failure remains authoritative.
    }
  }

  Future<void> _close(RandomAccessFile? output) async {
    try {
      await output?.close();
    } on Object {
      // Partial data is deleted by the caller.
    }
  }

  Future<void> _deletePartial(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Do not expose local filesystem details.
    }
  }

  ChimeraFailure<void> _failure(String code) => ChimeraFailure<void>(
    kind: FailureKind.update,
    code: code,
    messageKey: 'error.update.downloadFailed',
  );
}

final class Sha256UpdateChecksumVerifier implements UpdateChecksumVerifier {
  const Sha256UpdateChecksumVerifier();

  @override
  Future<ChimeraResult<bool>> verifySha256({
    required String path,
    required String expectedDigest,
  }) async {
    try {
      final digest = await sha256.bind(File(path).openRead()).first;
      return ChimeraSuccess<bool>(
        digest.toString().toLowerCase() == expectedDigest.toLowerCase(),
      );
    } on Object {
      return const ChimeraFailure<bool>(
        kind: FailureKind.update,
        code: 'update-checksum-read-failed',
        messageKey: 'error.update.checksumFailed',
      );
    }
  }
}

final class UpdateProcessResult {
  const UpdateProcessResult(this.exitCode);

  final int exitCode;
}

abstract interface class UpdateProcessRunner {
  Future<UpdateProcessResult> run(String executable, List<String> arguments);

  Future<void> startDetached(String executable, List<String> arguments);
}

final class IoUpdateProcessRunner implements UpdateProcessRunner {
  const IoUpdateProcessRunner();

  @override
  Future<UpdateProcessResult> run(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments, runInShell: false);
    return UpdateProcessResult(result.exitCode);
  }

  @override
  Future<void> startDetached(String executable, List<String> arguments) async {
    await Process.start(
      executable,
      arguments,
      runInShell: false,
      mode: ProcessStartMode.detached,
    );
  }
}

final class NativeUpdateInstaller implements UpdateInstaller {
  const NativeUpdateInstaller({
    required this.platform,
    UpdateProcessRunner runner = const IoUpdateProcessRunner(),
    String? windowsDirectory,
  }) : // Keep the descriptive public parameter while retaining a private port.
       // ignore: prefer_initializing_formals
       _runner = runner,
       // ignore: prefer_initializing_formals
       _windowsDirectory = windowsDirectory;

  final ReleasePlatform platform;
  final UpdateProcessRunner _runner;
  final String? _windowsDirectory;

  @override
  Future<ChimeraResult<UpdateInstallResult>> install({
    required ReleaseMetadata release,
    required String artifactPath,
  }) async {
    if (release.platform != platform ||
        release.packageType != ReleasePackageType.installer ||
        !_hasExpectedExtension(artifactPath)) {
      return _failure('update-install-invalid-artifact');
    }
    switch (platform) {
      case ReleasePlatform.windows:
        return _runWindowsInstaller(release.application, artifactPath);
      case ReleasePlatform.linux:
        return _runLinuxInstaller(artifactPath);
    }
  }

  Future<ChimeraResult<UpdateInstallResult>> _runWindowsInstaller(
    ReleaseApplication application,
    String artifactPath,
  ) async {
    final stagingRoot = p.windows.dirname(artifactPath);
    if (!p.windows.basename(stagingRoot).startsWith('chimera-update-') ||
        !p.windows.isWithin(stagingRoot, artifactPath)) {
      return _failure('update-install-invalid-staging');
    }
    final configuredWindowsDirectory =
        _windowsDirectory ?? Platform.environment['SystemRoot'];
    if (configuredWindowsDirectory == null) {
      return _failure('update-install-invalid-system-root');
    }
    final windowsDirectory = p.windows.normalize(configuredWindowsDirectory);
    if (!p.windows.isAbsolute(windowsDirectory) ||
        p.windows.basename(windowsDirectory).toLowerCase() != 'windows') {
      return _failure('update-install-invalid-system-root');
    }
    final powershell = p.windows.join(
      windowsDirectory,
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    );
    final mutexName = switch (application) {
      ReleaseApplication.desktop => r'Local\ChimeraDesktopUpdateHandoff',
      ReleaseApplication.cli => r'Local\ChimeraCliUpdateHandoff',
    };
    try {
      await _runner.startDetached(powershell, <String>[
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        _windowsHandoffScript,
        '$pid',
        artifactPath,
        stagingRoot,
        mutexName,
      ]);
      return const ChimeraSuccess<UpdateInstallResult>(
        UpdateInstallResult(
          restartRequired: true,
          cleanupDeferred: true,
          status: UpdateApplyStatus.scheduled,
        ),
      );
    } on Object {
      return _failure('update-install-launch-failed');
    }
  }

  Future<ChimeraResult<UpdateInstallResult>> _runLinuxInstaller(
    String artifactPath,
  ) async {
    final UpdateProcessResult preflight;
    try {
      // Chimera's Debian packages have no maintainer scripts. A no-op pass
      // rejects dependency/package conflicts before elevation; --no-triggers
      // then limits the real transaction to dpkg's backup-and-rollback unpack
      // behavior plus the script-free package configuration.
      preflight = await _runner.run('dpkg', <String>[
        '--no-act',
        '--install',
        artifactPath,
      ]);
    } on Object {
      return _failure('update-install-launch-failed');
    }
    if (preflight.exitCode != 0) {
      return _failure('update-install-preflight-failed');
    }

    final UpdateProcessResult result;
    try {
      result = await _runner.run('pkexec', <String>[
        'dpkg',
        '--no-triggers',
        '--install',
        artifactPath,
      ]);
    } on Object {
      return _elevationFailure();
    }
    if (result.exitCode == 126 || result.exitCode == 127) {
      return _elevationFailure();
    }
    if (result.exitCode != 0) {
      return _failure('update-install-process-failed');
    }
    return const ChimeraSuccess<UpdateInstallResult>(
      UpdateInstallResult(restartRequired: true),
    );
  }

  bool _hasExpectedExtension(String path) => switch (platform) {
    ReleasePlatform.windows => p.extension(path).toLowerCase() == '.exe',
    ReleasePlatform.linux => p.extension(path).toLowerCase() == '.deb',
  };

  ChimeraFailure<UpdateInstallResult> _failure(String code) =>
      ChimeraFailure<UpdateInstallResult>(
        kind: FailureKind.update,
        code: code,
        messageKey: 'error.update.installFailed',
      );

  ChimeraFailure<UpdateInstallResult> _elevationFailure() =>
      const ChimeraFailure<UpdateInstallResult>(
        kind: FailureKind.update,
        code: 'update-elevation-denied',
        messageKey: 'error.update.elevationDenied',
      );

  static const String _windowsHandoffScript = r'''
$parentId = [int]$args[0]
$installer = $args[1]
$stagingRoot = $args[2]
$mutexName = $args[3]
$installerExitCode = 1
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
try {
  if (-not $createdNew) {
    $installerExitCode = 2
    return
  }
  Wait-Process -Id $parentId -ErrorAction SilentlyContinue
  $process = Start-Process -FilePath $installer -ArgumentList @('/SILENT', '/NORESTART', '/SP-') -Wait -PassThru
  $installerExitCode = $process.ExitCode
} finally {
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
  if ($createdNew) {
    $mutex.ReleaseMutex()
  }
  $mutex.Dispose()
}
exit $installerExitCode
''';
}

final class _ArtifactTooLarge implements Exception {
  const _ArtifactTooLarge();
}
