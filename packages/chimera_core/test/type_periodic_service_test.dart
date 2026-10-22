import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test('GivenInvalidIntervals_WhenNormalized_ThenUsesTwentySeconds', () {
    for (final input in [
      null,
      '',
      'abc',
      '0',
      '-1',
      '1.5',
      '2147483648',
      '0x10',
    ]) {
      expect(TypePeriodicService.effectiveInterval(input), 20);
    }
    expect(TypePeriodicService.effectiveInterval(' 3 '), 3);
  });

  test(
    'GivenOwnedTerminal_WhenRunning_ThenWaitsAndTypesSequentialCommands',
    () async {
      final terminal = FakeTerminal();
      final cancellation = PeriodicCancellation();
      final delays = <Duration>[];
      final service = TypePeriodicService(
        terminal: terminal,
        sleep: (delay) async {
          delays.add(delay);
        },
      );
      terminal.onSend = (counter) {
        if (counter == 2) cancellation.cancel();
      };
      final result = await service.run(
        interval: '3',
        cancellation: cancellation,
      );
      expect(result, isA<ChimeraSuccess<TypePeriodicOutput>>());
      expect(delays.map((e) => e.inSeconds), [1, 15, 3, 3]);
      expect(terminal.events, [
        'launch',
        'activate',
        'send:1',
        'send:2',
        'close',
      ]);
      expect((result as ChimeraSuccess<TypePeriodicOutput>).value.sentCount, 2);
    },
  );

  for (final phase in [1, 2, 3]) {
    test(
      'GivenCancellationDuringDelay${phase}_WhenStopped_ThenNoInputIsSent',
      () async {
        final terminal = FakeTerminal();
        final cancellation = PeriodicCancellation();
        var count = 0;
        final service = TypePeriodicService(
          terminal: terminal,
          sleep: (_) {
            count++;
            if (count == phase) {
              cancellation.cancel();
              return Completer<void>().future;
            }
            return Future.value();
          },
        );
        expect(
          await service.run(cancellation: cancellation),
          isA<ChimeraSuccess<TypePeriodicOutput>>(),
        );
        expect(terminal.events.where((e) => e.startsWith('send')), isEmpty);
        expect(terminal.events.last, 'close');
      },
    );
  }

  test('GivenForegroundLost_WhenSending_ThenStopsAndCleansUp', () async {
    final terminal = FakeTerminal()
      ..failure = PeriodicTerminalFailure.focusLost;
    final result = await TypePeriodicService(
      terminal: terminal,
      sleep: (_) async {},
    ).run();
    expect(
      (result as ChimeraFailure<TypePeriodicOutput>).code,
      'type_periodic_focus_lost',
    );
    expect(terminal.events, ['launch', 'activate', 'send:1', 'close']);
    expect(result.details, isEmpty);
  });

  test(
    'GivenCleanupFailure_WhenCancelled_ThenReturnsTypedCleanupFailure',
    () async {
      final terminal = FakeTerminal()..failStage = 'close';
      final stop = PeriodicCancellation();
      terminal.onSend = (_) => stop.cancel();
      final result = await TypePeriodicService(
        terminal: terminal,
        sleep: (_) async {},
      ).run(cancellation: stop);
      expect(
        (result as ChimeraFailure<TypePeriodicOutput>).code,
        'type_periodic_cleanup',
      );
    },
  );

  test(
    'GivenRunningService_WhenStartedAgain_ThenRejectsWithoutSharingTerminal',
    () async {
      final terminal = FakeTerminal();
      final stop = PeriodicCancellation();
      final service = TypePeriodicService(
        terminal: terminal,
        sleep: (_) => Completer<void>().future,
      );
      final first = service.run(cancellation: stop);
      final second = await service.run();
      expect(
        (second as ChimeraFailure<TypePeriodicOutput>).code,
        'type_periodic_busy',
      );
      stop.cancel();
      await first;
      expect(terminal.events.where((event) => event == 'launch'), hasLength(1));
      expect(terminal.events.where((event) => event == 'close'), hasLength(1));
    },
  );

  test(
    'GivenSensitiveNativeFailure_WhenRun_ThenDiagnosticsContainOnlySafeEnums',
    () async {
      final sink = Events();
      final terminal = FakeTerminal()..failStage = 'launch';
      await TypePeriodicService(
        terminal: terminal,
        diagnostics: sink,
      ).run(interval: 'sensitive input');
      expect(sink.events.last.code, 'operationFailed');
      expect(sink.events.last.context['operation'], 'typePeriodic');
      expect(sink.events.toString(), isNot(contains('sensitive input')));
      expect(
        sink.events.last.context.keys,
        unorderedEquals(['operation', 'status', 'failureKind']),
      );
    },
  );

  test('GivenUnsupportedTarget_WhenStarted_ThenReturnsTypedFailure', () async {
    final result = await TypePeriodicService().run();
    expect(
      (result as ChimeraFailure<TypePeriodicOutput>).code,
      'type_periodic_unsupported',
    );
  });

  test('GivenCancelledBeforeStart_WhenRun_ThenDoesNotLaunch', () async {
    final terminal = FakeTerminal();
    final cancellation = PeriodicCancellation()..cancel();
    await TypePeriodicService(terminal: terminal)
        .run(cancellation: cancellation);
    expect(terminal.events, isEmpty);
  });

  test('GivenCancellation_WhenDefaultClockWaits_ThenCancelsItsTimer', () async {
    final terminal = FakeTerminal();
    final cancellation = PeriodicCancellation();
    final timers = <Timer>[];
    await runZoned(
      () async {
        final future = TypePeriodicService(terminal: terminal)
            .run(cancellation: cancellation);
        await Future<void>.delayed(Duration.zero);
        cancellation.cancel();
        await future;
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });

  test(
    'GivenLaunchOrActivationFailure_WhenRun_ThenClosesWithoutInput',
    () async {
      for (final stage in ['launch', 'activate']) {
        final terminal = FakeTerminal()..failStage = stage;
        final result = await TypePeriodicService(
          terminal: terminal,
          sleep: (_) async {},
        ).run();
        expect(result, isA<ChimeraFailure<TypePeriodicOutput>>());
        expect(terminal.events.last, 'close');
        expect(terminal.events.where((e) => e.startsWith('send')), isEmpty);
      }
    },
  );
}

class FakeTerminal implements PeriodicTerminal {
  final events = <String>[];
  PeriodicTerminalFailure? failure;
  String? failStage;
  void Function(int)? onSend;
  @override
  bool get supported => true;
  @override
  Future<void> launch() async {
    events.add('launch');
    if (failStage == 'launch') {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
  }

  @override
  Future<void> activate() async {
    events.add('activate');
    if (failStage == 'activate') {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
  }

  @override
  Future<void> sendEcho(int counter) async {
    events.add('send:$counter');
    if (failure != null) throw PeriodicTerminalException(failure!);
    onSend?.call(counter);
  }

  @override
  Future<void> close() async {
    events.add('close');
    if (failStage == 'close') throw StateError('sensitive diagnostic');
  }
}

class Events implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  void emit(DiagnosticEvent event) => events.add(event);
}
