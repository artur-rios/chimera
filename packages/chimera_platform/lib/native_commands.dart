/// Native-only process and project-discovery adapters. Import conditionally on web.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

final class NativeProjectDiscovery implements ProjectDiscovery {
  const NativeProjectDiscovery();

  @override
  Future<ChimeraResult<String>> find(
    String root, {
    required String extension,
    String? selection,
  }) async {
    ChimeraFailure<String> fail(
      String code, {
      List<String> choices = const [],
    }) => ChimeraFailure(
      kind: FailureKind.validation,
      code: code,
      messageKey: 'error.$code',
      details: {'choices': choices},
    );
    try {
      final directory = Directory(root);
      if (!await directory.exists()) return fail('dotnet.invalidPath');
      final resolved = await directory.resolveSymbolicLinks();
      final files = <String>[];
      await for (final entity in Directory(resolved).list(followLinks: false)) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == extension.toLowerCase()) {
          files.add(entity.path);
        }
      }
      files.sort();
      final choices = files.map(p.basename).toList();
      if (selection != null) {
        final candidate = p.normalize(p.join(resolved, selection));
        if (!p.isWithin(resolved, candidate) ||
            p.extension(candidate).toLowerCase() != extension.toLowerCase()) {
          return fail('dotnet.invalidPath');
        }
        if (!await File(candidate).exists()) {
          return fail('dotnet.noSolution', choices: choices);
        }
        final actual = await File(candidate).resolveSymbolicLinks();
        if (!p.isWithin(resolved, actual)) return fail('dotnet.invalidPath');
        return ChimeraSuccess(actual);
      }
      if (files.length != 1) {
        return fail(
          files.isEmpty ? 'dotnet.noSolution' : 'dotnet.ambiguousSolution',
          choices: choices,
        );
      }
      return ChimeraSuccess(files.single);
    } on FileSystemException {
      return const ChimeraFailure(
        kind: FailureKind.access,
        code: 'dotnet.invalidPath',
        messageKey: 'error.dotnet.invalidPath',
      );
    } on ArgumentError {
      return fail('dotnet.invalidPath');
    }
  }
}

/// Executes argument arrays without a shell. Linux uses a fresh process group;
/// Windows uses taskkill /T to terminate descendants before awaiting pipe EOF.
final class NativeProcessRunner implements NativeCommandRunner {
  const NativeProcessRunner({this.maxDiagnosticCharacters = 65536});
  final int maxDiagnosticCharacters;

  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    if (cancellation?.isCancelled ?? false) {
      return const NativeCommandResult(exitCode: 130, cancelled: true);
    }
    if (!Platform.isLinux && !Platform.isWindows) {
      return const NativeCommandResult(exitCode: 127, unavailable: true);
    }
    Process process;
    try {
      process = await Process.start(
        Platform.isLinux ? 'setsid' : command.executable,
        Platform.isLinux
            ? ['--wait', command.executable, ...command.arguments]
            : command.arguments,
        workingDirectory: command.workingDirectory,
        runInShell: false,
      );
    } on ProcessException {
      return const NativeCommandResult(exitCode: 127, unavailable: true);
    }
    final output = StringBuffer();
    var cancelled = false;
    var finished = false;
    Future<void>? termination;
    Future<void> terminate() async {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      } else {
        await Process.run('kill', ['-KILL', '--', '-${process.pid}']);
      }
      process.kill(ProcessSignal.sigkill);
    }

    // Keep lines bounded before decoding/redacting; huge unterminated lines are
    // suppressed completely, never exposed in split fragments of a secret.
    Future<void> consume(Stream<List<int>> bytes) async {
      var pending = <int>[];
      var dropping = false;
      void emit() {
        if (dropping) {
          pending = [];
          dropping = false;
          return;
        }
        final safe = redactNativeDiagnostic(
          utf8.decode(pending, allowMalformed: true),
        );
        pending = [];
        final remaining = maxDiagnosticCharacters - output.length;
        if (remaining <= 0) return;
        final bounded = safe.length > remaining
            ? safe.substring(0, remaining)
            : safe;
        output.write(bounded);
        onDiagnostic?.call(bounded);
      }

      await for (final chunk in bytes) {
        for (final byte in chunk) {
          if (!dropping) {
            pending.add(byte);
            if (pending.length > 8192) {
              dropping = true;
              pending = [];
            }
          }
          if (byte == 10) emit();
        }
      }
      if (pending.isNotEmpty || dropping) emit();
    }

    final streams = Future.wait([
      consume(process.stdout),
      consume(process.stderr),
    ]);
    unawaited(
      cancellation?.whenCancelled.then((_) {
        if (finished) return;
        cancelled = true;
        termination = terminate();
      }),
    );
    final exitCode = await process.exitCode;
    // A child can outlive its parent and hold pipes open, so cancellation remains
    // registered until both streams close.
    await streams;
    finished = true;
    await termination;
    return NativeCommandResult(
      exitCode: cancelled ? 130 : exitCode,
      diagnostics: output.toString(),
      cancelled: cancelled,
      unavailable: exitCode == 127,
    );
  }
}

String redactNativeDiagnostic(String value) => value
    .replaceAll(
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      '[REDACTED URL]',
    )
    .replaceAll(
      RegExp(r'\b(?:Bearer|Basic)\s+\S+', caseSensitive: false),
      '[REDACTED]',
    )
    .replaceAll(
      RegExp(
        r'''\b(?:password|passwd|pwd|token|secret|api[_-]?key|authorization|credential|connectionstring)\s*[:=]\s*(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s;]+)''',
        caseSensitive: false,
      ),
      '[REDACTED]',
    );
