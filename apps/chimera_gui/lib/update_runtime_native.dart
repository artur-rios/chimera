import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:package_info_plus/package_info_plus.dart';

final bool nativeUpdateChecksSupported = Platform.isWindows || Platform.isLinux;
const String _releaseRepository = String.fromEnvironment(
  'CHIMERA_RELEASE_REPOSITORY',
  defaultValue: 'artur-rios/chimera',
);
final UpdateCheckService _nativeUpdateCheckService = UpdateCheckService(
  GitHubReleaseMetadataSource(),
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
