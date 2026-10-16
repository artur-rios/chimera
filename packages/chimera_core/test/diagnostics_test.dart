import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenSensitiveContext_WhenEventCreated_ThenSensitiveValuesAreRedacted',
    () {
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 16),
        severity: DiagnosticSeverity.warning,
        component: 'update',
        code: 'download-failed',
        context: const <String, Object?>{
          'status': 'failed',
          'durationMs': 20,
          'input': 'private utility data',
          'output': 'private result',
          'token': 'secret-token',
          'url': 'https://user:secret@example.test/artifact',
        },
      );

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
    'GivenDiagnosticSink_WhenEventEmitted_ThenSinkReceivesSanitizedEvent',
    () {
      final sink = _RecordingDiagnosticSink();
      final event = DiagnosticEvent.create(
        timestamp: DateTime.utc(2026, 10, 16),
        severity: DiagnosticSeverity.info,
        component: 'cli',
        code: 'started',
        context: const <String, Object?>{'platform': 'windows'},
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
