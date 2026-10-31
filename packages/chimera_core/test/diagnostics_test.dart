import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenSensitiveContext_WhenEventCreated_ThenSensitiveValuesAreRedacted',
    () {
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 16),
        severity: DiagnosticSeverity.warning,
        component: DiagnosticComponent.update,
        code: DiagnosticCode.operationFailed,
        context: const <String, Object?>{
          'status': DiagnosticStatus.failed,
          'durationMs': 20,
          'input': 'private utility data',
          'output': 'private result',
          'token': 'secret-token',
          'url': 'https://user:secret@example.test/artifact',
        },
      );

      expect(event.component, 'update');
      expect(event.code, 'operationFailed');
      expect(event.context['status'], 'failed');
      expect(event.context['durationMs'], 20);
      expect(event.context['input'], DiagnosticEvent.redactedValue);
      expect(event.context['output'], DiagnosticEvent.redactedValue);
      expect(event.context['token'], DiagnosticEvent.redactedValue);
      expect(event.context['url'], DiagnosticEvent.redactedValue);
      expect(event.context.values, isNot(contains('private utility data')));
      expect(event.context.values, isNot(contains('private result')));
      expect(event.context.values, isNot(contains('secret-token')));
    },
  );

  test(
    'GivenSensitiveAliases_WhenAllowedKeysAreUsed_ThenValuesAreStillRedacted',
    () {
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 16),
        severity: DiagnosticSeverity.error,
        component: DiagnosticComponent.core,
        code: DiagnosticCode.operationFailed,
        context: const <String, Object?>{
          'operation': 'private utility data',
          'status': <String>['secret-token'],
          'target': <String, String>{'url': 'https://user:secret@example.test'},
          'failureKind': FailureKind.validation,
          'platform': DiagnosticPlatform.windows,
          'version': '1.2.3',
        },
      );

      expect(event.context['operation'], DiagnosticEvent.redactedValue);
      expect(event.context['status'], DiagnosticEvent.redactedValue);
      expect(event.context['target'], DiagnosticEvent.redactedValue);
      expect(event.context['failureKind'], 'validation');
      expect(event.context['platform'], 'windows');
      expect(event.context['version'], '1.2.3');
      expect(event.context.toString(), isNot(contains('secret')));
      expect(event.context.toString(), isNot(contains('private utility data')));
    },
  );

  test(
    'GivenDiagnosticSink_WhenEventEmitted_ThenSinkReceivesSanitizedEvent',
    () {
      final sink = _RecordingDiagnosticSink();
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 16),
        severity: DiagnosticSeverity.info,
        component: DiagnosticComponent.cli,
        code: DiagnosticCode.operationStarted,
        context: const <String, Object?>{
          'platform': DiagnosticPlatform.windows,
        },
      );

      sink.emit(event);

      expect(sink.events, <DiagnosticEvent>[event]);
    },
  );
}

final class _RecordingDiagnosticSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void emit(DiagnosticEvent event) {
    events.add(event);
  }
}
