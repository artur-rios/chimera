import 'package:chimera_core/chimera_core.dart';

const bool nativeUpdateChecksSupported = false;

Future<ChimeraResult<UpdateCheckResult>> checkForNativeUpdate() async =>
    const ChimeraFailure<UpdateCheckResult>(
      kind: FailureKind.update,
      code: 'unsupported-update-platform',
      messageKey: 'error.update.checkFailed',
    );
