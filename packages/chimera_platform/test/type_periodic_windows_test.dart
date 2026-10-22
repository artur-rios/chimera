import 'dart:io';

import 'package:chimera_platform/src/type_periodic_terminal_native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenWindows_WhenOwnedTerminalLaunchedAndClosed_ThenNativeHelperLifecycleCompletes',
    () async {
      final terminal = WindowsPeriodicTerminal();
      try {
        await terminal.launch();
      } finally {
        // No activation or input is sent. Closing exercises helper EOF and the
        // native kill-on-close job for the console this invocation owns.
        await terminal.close();
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
