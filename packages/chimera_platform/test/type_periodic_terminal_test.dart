import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/src/type_periodic_terminal_native.dart';
import 'package:test/test.dart';

void main() {
  test('GivenUnsupportedTarget_WhenStarted_ThenNeverCreatesHelper', () async {
    var created = false;
    final terminal = WindowsPeriodicTerminal(
      isWindows: false,
      helperFactory: () async {
        created = true;
        return Helper();
      },
    );
    final result = await TypePeriodicService(terminal: terminal).run();
    expect((result as ChimeraFailure).code, 'type_periodic_unsupported');
    expect(created, isFalse);
  });
  test('GivenOwnedConsole_WhenSending_ThenUsesOnlyFixedProtocol', () async {
    final helper = Helper();
    final terminal = WindowsPeriodicTerminal(
      isWindows: true,
      helperFactory: () async => helper,
    );
    await terminal.launch();
    await terminal.activate();
    await terminal.sendEcho(1);
    await terminal.close();
    expect(helper.commands, ['launch', 'activate', 'send:1']);
    expect(helper.closed, isTrue);
  });
  test('GivenFocusLost_WhenSending_ThenReturnsTypedFailureAndCloses', () async {
    final helper = Helper()..reply = 'focus_lost';
    final terminal = WindowsPeriodicTerminal(
      isWindows: true,
      helperFactory: () async => helper,
    );
    // Launch must succeed before simulating focus loss at the send boundary.
    helper.reply = 'ok';
    await terminal.launch();
    helper.reply = 'focus_lost';
    await expectLater(
      terminal.sendEcho(1),
      throwsA(
        isA<PeriodicTerminalException>().having(
          (e) => e.failure,
          'failure',
          PeriodicTerminalFailure.focusLost,
        ),
      ),
    );
    await terminal.close();
    expect(helper.closed, isTrue);
  });
  test('GivenUnknownHelperError_WhenStarted_ThenRedactsFailure', () async {
    final helper = Helper()..reply = 'secret path and process output';
    final terminal = WindowsPeriodicTerminal(
      isWindows: true,
      helperFactory: () async => helper,
    );
    await expectLater(
      terminal.launch(),
      throwsA(
        isA<PeriodicTerminalException>().having(
          (e) => e.failure,
          'failure',
          PeriodicTerminalFailure.automation,
        ),
      ),
    );
    await terminal.close();
  });
}

class Helper implements PeriodicHelper {
  final commands = <String>[];
  var reply = 'ok';
  var closed = false;
  @override
  Future<String> command(String command) async {
    commands.add(command);
    return reply;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
