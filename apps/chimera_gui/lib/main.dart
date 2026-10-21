import 'package:flutter/widgets.dart';

import 'app.dart';
import 'update_runtime.dart';

void main() {
  runApp(
    ChimeraApp(
      updateChecksEnabled: nativeUpdateChecksSupported,
      updateChecker: nativeUpdateChecksSupported ? checkForNativeUpdate : null,
      updateApplier: nativeUpdateChecksSupported ? applyNativeUpdate : null,
    ),
  );
}
