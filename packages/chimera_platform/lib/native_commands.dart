/// Native-only process and project-discovery adapters. Import conditionally on web.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:path/path.dart' as p;

import 'src/windows_process_helper.dart';

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
        if (p.extension(candidate).toLowerCase() != extension.toLowerCase()) {
          return fail('dotnet.invalidPath');
        }
        // A Windows 8.3 spelling can name the same file outside the lexical
        // spelling of resolved. Inspect ancestors before resolving the file:
        // accept same-object spellings, never linked or redirected ancestors.
        final ancestors = <String>[];
        var ancestor = p.dirname(candidate);
        while (true) {
          ancestors.add(ancestor);
          final parent = p.dirname(ancestor);
          if (parent == ancestor) break;
          ancestor = parent;
        }
        for (final ancestor in ancestors.reversed) {
          final type = await FileSystemEntity.type(
            ancestor,
            followLinks: false,
          );
          if (type == FileSystemEntityType.notFound) {
            return fail('dotnet.noSolution', choices: choices);
          }
          if (type != FileSystemEntityType.directory) {
            return fail('dotnet.invalidPath');
          }
          final canonical = await Directory(ancestor).resolveSymbolicLinks();
          if (!await FileSystemEntity.identical(ancestor, canonical)) {
            return fail('dotnet.invalidPath');
          }
        }
        final type = await FileSystemEntity.type(candidate, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          return fail('dotnet.noSolution', choices: choices);
        }
        if (type != FileSystemEntityType.file) {
          return fail('dotnet.invalidPath');
        }
        final actual = await File(candidate).resolveSymbolicLinks();
        if (!p.isWithin(resolved, actual) ||
            !await FileSystemEntity.identical(candidate, actual)) {
          return fail('dotnet.invalidPath');
        }
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
/// Windows contains the suspended child in a kill-on-close job object.
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
        Platform.isLinux
            ? 'setsid'
            : '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
        Platform.isLinux
            ? ['--wait', command.executable, ...command.arguments]
            : [
                '-NoLogo',
                '-NoProfile',
                '-NonInteractive',
                '-EncodedCommand',
                base64Encode(
                  windowsProcessHelper.codeUnits
                      .expand((unit) => [unit & 255, unit >> 8])
                      .toList(),
                ),
              ],
        workingDirectory: command.workingDirectory,
        runInShell: false,
      );
    } on ProcessException {
      return const NativeCommandResult(exitCode: 127, unavailable: true);
    }
    if (Platform.isWindows) {
      process.stdin.writeln(
        jsonEncode({
          'executable': command.executable,
          'arguments': command.arguments,
          'workingDirectory':
              command.workingDirectory ?? Directory.current.path,
        }),
      );
      await process.stdin.close();
    }
    final output = StringBuffer();
    var cancelled = false;
    var finished = false;
    Future<void>? termination;
    Future<void> terminate() async {
      if (Platform.isWindows) {
        process.kill(ProcessSignal.sigkill);
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
