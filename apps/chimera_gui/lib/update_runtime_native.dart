import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:chimera_platform/native_updates.dart';
import 'package:package_info_plus/package_info_plus.dart';

final bool nativeUpdateChecksSupported = Platform.isWindows || Platform.isLinux;
const String _releaseRepository = String.fromEnvironment(
  'CHIMERA_RELEASE_REPOSITORY',
  defaultValue: 'artur-rios/chimera',
);
final UpdateCheckService _nativeUpdateCheckService = UpdateCheckService(
  GitHubReleaseMetadataSource(),
);
final NativeUpdateTemporaryStorage _nativeUpdateStorage =
    NativeUpdateTemporaryStorage();
final UpdateApplyService _nativeUpdateApplyService = UpdateApplyService(
  storage: _nativeUpdateStorage,
  downloader: HttpUpdateArtifactDownloader(),
  verifier: const Sha256UpdateChecksumVerifier(),
  installer: NativeUpdateInstaller(
    platform: Platform.isWindows
        ? ReleasePlatform.windows
        : ReleasePlatform.linux,
  ),
);

Future<ChimeraResult<UpdateCheckResult>> checkForNativeUpdate() async {
  if (!nativeUpdateChecksSupported) {
    return const ChimeraFailure<UpdateCheckResult>(
      kind: FailureKind.update,
      code: 'unsupported-update-platform',
      messageKey: 'error.update.checkFailed',
    );
  }
  try {
    final package = await PackageInfo.fromPlatform();
    return await _nativeUpdateCheckService.check(
      endpoint: Uri.https(
        'api.github.com',
        '/repos/$_releaseRepository/releases/latest',
      ),
      installedVersion: package.version,
      target: UpdateTarget(
        platform: Platform.isWindows
            ? ReleasePlatform.windows
            : ReleasePlatform.linux,
        application: ReleaseApplication.desktop,
        packageType: ReleasePackageType.installer,
      ),
    );
  } on Object {
    return const ChimeraFailure<UpdateCheckResult>(
      kind: FailureKind.update,
      code: 'update-runtime-failed',
      messageKey: 'error.update.checkFailed',
    );
  }
}

Future<ChimeraResult<UpdateApplyResult>> applyNativeUpdate(
  ReleaseMetadata release,
) async {
  if (!nativeUpdateChecksSupported ||
      release.application != ReleaseApplication.desktop ||
      release.platform !=
          (Platform.isWindows
              ? ReleasePlatform.windows
              : ReleasePlatform.linux)) {
    return const ChimeraFailure<UpdateApplyResult>(
      kind: FailureKind.update,
      code: 'unsupported-update-platform',
      messageKey: 'error.update.installFailed',
    );
  }
  try {
    return await _nativeUpdateApplyService.apply(
      UpdateApplyRequest(release: release, accepted: true),
    );
  } on Object {
    return const ChimeraFailure<UpdateApplyResult>(
      kind: FailureKind.update,
      code: 'update-runtime-failed',
      messageKey: 'error.update.installFailed',
    );
  }
}
