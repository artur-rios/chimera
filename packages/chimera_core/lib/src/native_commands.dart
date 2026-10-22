import 'dart:async';

import 'result.dart';

/// Cancellation belongs to one operation and is safe before process startup.
final class OperationCancellation {
  final _completion = Completer<void>();
  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;
  void cancel() {
    if (!isCancelled) _completion.complete();
  }
}

final class NativeCommand {
  const NativeCommand(this.executable, this.arguments, {this.workingDirectory});
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

final class NativeCommandResult {
  const NativeCommandResult({
    required this.exitCode,
    this.diagnostics = '',
    this.cancelled = false,
    this.unavailable = false,
  });
  final int exitCode;

  /// Bounded and redacted text, suitable for displaying to the actor.
  final String diagnostics;
  final bool cancelled;
  final bool unavailable;
}

abstract interface class NativeCommandRunner {
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  });
}

/// Nonrecursive file discovery. Explicit selections stay within the chosen root.
abstract interface class ProjectDiscovery {
  Future<ChimeraResult<String>> find(
    String root, {
    required String extension,
    String? selection,
  });
}

abstract interface class ProjectFileDiscovery {
  Future<ChimeraResult<List<String>>> discover(
    String root, {
    required String extension,
    bool recursive = false,
    Set<String> excludedDirectories = const {},
  });
}
