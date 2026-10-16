enum DiagnosticSeverity { debug, info, warning, error }

enum DiagnosticComponent { application, cli, core, gui, platform, update, web }

enum DiagnosticCode { operationStarted, operationCompleted, operationFailed }

enum DiagnosticEnvironment {
  local,
  development,
  homologation,
  production,
  test,
}

enum DiagnosticPlatform { cli, linux, web, windows }

enum DiagnosticStatus { started, succeeded, failed, cancelled }

enum DiagnosticTarget { cli, gui, release, web }

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
    required DiagnosticComponent component,
    required DiagnosticCode code,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final sanitized = <String, Object?>{
      for (final entry in context.entries)
        entry.key: _sanitizeContextValue(entry.key, entry.value),
    };

    return DiagnosticEvent._(
      timestamp: timestamp,
      severity: severity,
      component: component.name,
      code: code.name,
      context: Map<String, Object?>.unmodifiable(sanitized),
    );
  }

  static Object? _sanitizeContextValue(String key, Object? value) {
    if (!_allowedContextKeys.contains(key)) {
      return redactedValue;
    }

    if (key == 'durationMs' && value is num && value.isFinite && value >= 0) {
      return value;
    }

    if (key == 'version' && value is String) {
      final semanticVersion = RegExp(
        r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$',
      );
      return semanticVersion.hasMatch(value) ? value : redactedValue;
    }

    if (value is Enum) {
      return value.name;
    }

    return redactedValue;
  }
}
