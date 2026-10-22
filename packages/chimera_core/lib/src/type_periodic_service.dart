import 'dart:async';

import 'diagnostics.dart';
import 'result.dart';

enum _PeriodicOperation { typePeriodic }

/// Cancellation is idempotent and wakes a waiting operation immediately.
final class PeriodicCancellation {
  final Completer<void> _completion = Completer<void>();
  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;
  void cancel() {
    if (!isCancelled) _completion.complete();
  }
}

enum PeriodicTerminalFailure { unsupported, automation, focusLost, cleanup }

final class PeriodicTerminalException implements Exception {
  const PeriodicTerminalException(this.failure);
  final PeriodicTerminalFailure failure;
}

/// Implementations must verify ownership and foreground at the actual input
/// write, and target a scoped console handle rather than global keyboard input.
abstract interface class PeriodicTerminal {
  bool get supported;
  Future<void> launch();
  Future<void> activate();
  Future<void> sendEcho(int counter);
  Future<void> close();
}

final class UnsupportedPeriodicTerminal implements PeriodicTerminal {
  const UnsupportedPeriodicTerminal();
  @override
  bool get supported => false;
  @override
  Future<void> launch() async => throw const PeriodicTerminalException(
    PeriodicTerminalFailure.unsupported,
  );
  @override
  Future<void> activate() => launch();
  @override
  Future<void> sendEcho(int counter) => launch();
  @override
  Future<void> close() async {}
}

final class TypePeriodicOutput {
  const TypePeriodicOutput({
    required this.intervalSeconds,
    required this.sentCount,
  });
  final int intervalSeconds;
  final int sentCount;
}

/// A service instance runs one operation at a time; each operation owns its child.
final class TypePeriodicService {
  TypePeriodicService({
    this.terminal = const UnsupportedPeriodicTerminal(),
    this.sleep,
    this.diagnostics,
  });

  final DiagnosticSink? diagnostics;
  final PeriodicTerminal terminal;
  final Future<void> Function(Duration)? sleep;
  bool _running = false;

  static int effectiveInterval(String? input) {
    final normalized = input?.trim() ?? '';
    if (!RegExp(r'^[+-]?[0-9]+$').hasMatch(normalized)) return 20;
    final seconds = int.tryParse(normalized);
    return seconds == null || seconds <= 0 || seconds > 2147483647
        ? 20
        : seconds;
  }

  Future<ChimeraResult<TypePeriodicOutput>> run({
    String? interval,
    PeriodicCancellation? cancellation,
    void Function(int intervalSeconds)? onStarted,
    void Function(int sentCount)? onSent,
  }) async {
    final stop = cancellation ?? PeriodicCancellation();
    final seconds = effectiveInterval(interval);
    var sent = 0;
    ChimeraResult<TypePeriodicOutput> success() => ChimeraSuccess(
      TypePeriodicOutput(intervalSeconds: seconds, sentCount: sent),
    );
    if (stop.isCancelled) return _report(success());
    if (_running) return _report(_failure('busy'));
    if (!terminal.supported) return _report(_failure('unsupported'));
    _running = true;
    _emit(DiagnosticCode.operationStarted, DiagnosticStatus.started);
    ChimeraResult<TypePeriodicOutput>? outcome;
    try {
      await terminal.launch();
      if (!stop.isCancelled && await _wait(1, stop)) {
        await terminal.activate();
        if (!stop.isCancelled) onStarted?.call(seconds);
        if (!stop.isCancelled && await _wait(15, stop)) {
          while (!stop.isCancelled && await _wait(seconds, stop)) {
            if (stop.isCancelled) break;
            await terminal.sendEcho(sent + 1);
            sent++;
            onSent?.call(sent);
          }
        }
      }
      outcome = success();
    } on PeriodicTerminalException catch (error) {
      outcome = _failure(switch (error.failure) {
        PeriodicTerminalFailure.unsupported => 'unsupported',
        PeriodicTerminalFailure.focusLost => 'focus_lost',
        PeriodicTerminalFailure.cleanup => 'cleanup',
        PeriodicTerminalFailure.automation => 'automation',
      });
    } catch (_) {
      outcome = _failure('automation');
    } finally {
      try {
        await terminal.close();
      } catch (_) {
        outcome = _failure('cleanup');
      }
      _running = false;
    }
    return _report(outcome!);
  }

  Future<bool> _wait(int seconds, PeriodicCancellation cancellation) async {
    Timer? timer;
    final sleeper = sleep;
    final elapsed = Completer<void>();
    try {
      final Future<void> delay;
      if (sleeper != null) {
        delay = sleeper(Duration(seconds: seconds));
      } else {
        timer = Timer(Duration(seconds: seconds), elapsed.complete);
        delay = elapsed.future;
      }
      await Future.any<void>([delay, cancellation.whenCancelled]);
    } finally {
      timer?.cancel();
    }
    return !cancellation.isCancelled;
  }

  ChimeraResult<TypePeriodicOutput> _report(
    ChimeraResult<TypePeriodicOutput> result,
  ) {
    result.fold(
      onSuccess: (_) =>
          _emit(DiagnosticCode.operationCompleted, DiagnosticStatus.cancelled),
      onFailure: (failure) => _emit(
        DiagnosticCode.operationFailed,
        DiagnosticStatus.failed,
        failure.kind,
      ),
    );
    return result;
  }

  void _emit(
    DiagnosticCode code,
    DiagnosticStatus status, [
    FailureKind? kind,
  ]) {
    try {
      diagnostics?.emit(
        DiagnosticEvent.create(
          timestamp: DateTime.now().toUtc(),
          severity: kind == null
              ? DiagnosticSeverity.info
              : DiagnosticSeverity.error,
          component: DiagnosticComponent.core,
          code: code,
          context: {
            'operation': _PeriodicOperation.typePeriodic,
            'status': status,
            'failureKind': ?kind,
          },
        ),
      );
    } catch (_) {
      // Diagnostic sinks must never interrupt cleanup or expose raw errors.
    }
  }

  ChimeraFailure<TypePeriodicOutput> _failure(String reason) => ChimeraFailure(
    kind: FailureKind.processing,
    code: 'type_periodic_$reason',
    messageKey: 'error.typePeriodic.$reason',
  );
}
