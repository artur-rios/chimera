import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test('GivenPeriodicHelp_WhenRequested_ThenDocumentsTimingAndStop', () async {
    final out = StringBuffer();
    expect(
      await runChimera(
        ['terminal', 'type-periodic', '--help'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('20'));
    expect(out.toString(), contains('Ctrl+C'));
  });
  for (final locale in ['en', 'pt-BR']) {
    test('GivenUnsupportedTarget_WhenRunIn$locale'
        '_ThenLocalizesFailure', () async {
      final err = StringBuffer();
      expect(
        await runChimera(
          ['terminal', 'type-periodic'],
          localeTag: locale,
          out: StringBuffer(),
          err: err,
          typePeriodicService: TypePeriodicService(),
        ),
        1,
      );
      expect(err.toString(), contains(locale == 'en' ? 'Windows' : 'Windows'));
      expect(err.toString(), isNot(contains('error.typePeriodic')));
    });
  }
  test(
    'GivenInvalidInterval_WhenStopped_ThenReportsEffectiveDefaultAndCount',
    () async {
      final out = StringBuffer();
      final stop = PeriodicCancellation();
      final terminal = Terminal(stop);
      expect(
        await runChimera(
          ['terminal', 'type-periodic', '--interval=nope'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
          periodicCancellation: stop,
          typePeriodicService: TypePeriodicService(
            terminal: terminal,
            sleep: (_) async {},
          ),
        ),
        0,
      );
      expect(out.toString(), contains('20'));
      expect(out.toString(), contains('1'));
      expect(terminal.closed, isTrue);
    },
  );
}

class Terminal implements PeriodicTerminal {
  Terminal(this.stop);
  final PeriodicCancellation stop;
  bool closed = false;
  @override
  bool get supported => true;
  @override
  Future<void> launch() async {}
  @override
  Future<void> activate() async {}
  @override
  Future<void> sendEcho(int counter) async {
    stop.cancel();
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
