enum DiagnosticSeverity { debug, info, warning, error }

abstract interface class DiagnosticSink {
  void emit(DiagnosticEvent event);
}

final class DiagnosticEvent {
  DiagnosticEvent._({
    required this.timestamp,
    required this.severity,
    required this.component,
    required this.code,
    required this.context,
  });

  static const String redactedValue = '[REDACTED]';

  static const Set<String> _allowedContextKeys = <String>{
    'durationMs',
    'environment',
    'failureKind',
    'operation',
    'platform',
    'status',
    'target',
    'version',
  };

  final DateTime timestamp;
  final DiagnosticSeverity severity;
  final String component;
  final String code;
  final Map<String, Object?> context;

  factory DiagnosticEvent.create({
    required DateTime timestamp,
    required DiagnosticSeverity severity,
    required String component,
    required String code,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final sanitized = <String, Object?>{
      for (final entry in context.entries)
        entry.key: _allowedContextKeys.contains(entry.key)
            ? entry.value
            : redactedValue,
    };

    return DiagnosticEvent._(
      timestamp: timestamp,
      severity: severity,
      component: component,
      code: code,
      context: Map<String, Object?>.unmodifiable(sanitized),
    );
  }
}
