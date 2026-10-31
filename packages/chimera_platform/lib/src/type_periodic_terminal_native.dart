import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';

import 'windows_periodic_helper.dart';

PeriodicTerminal createPeriodicTerminal() => WindowsPeriodicTerminal();

/// The fixed helper protocol never accepts shell text from an operation request.
abstract interface class PeriodicHelper {
  Future<String> command(String command);
  Future<void> close();
}

final class WindowsPeriodicTerminal implements PeriodicTerminal {
  WindowsPeriodicTerminal({
    bool? isWindows,
    Future<PeriodicHelper> Function()? helperFactory,
  }) : _isWindows = isWindows ?? Platform.isWindows,
       _helperFactory = helperFactory ?? _ProcessHelper.start;
  final bool _isWindows;
  final Future<PeriodicHelper> Function() _helperFactory;
  PeriodicHelper? _helper;
  @override
  bool get supported => _isWindows;
  @override
  Future<void> launch() async {
    if (!supported) {
      throw const PeriodicTerminalException(
        PeriodicTerminalFailure.unsupported,
      );
    }
    if (_helper != null) {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
    _helper = await _helperFactory();
    await _command('launch');
  }

  @override
  Future<void> activate() => _command('activate');
  @override
  Future<void> sendEcho(int counter) {
    if (counter <= 0) {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
    return _command('send:$counter');
  }

  Future<void> _command(String command) async {
    final helper = _helper;
    if (helper == null) {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
    final result = await helper.command(command);
    if (result != 'ok') {
      throw PeriodicTerminalException(
        result == 'focus_lost'
            ? PeriodicTerminalFailure.focusLost
            : PeriodicTerminalFailure.automation,
      );
    }
  }

  @override
  Future<void> close() async {
    final helper = _helper;
    _helper = null;
    await helper?.close();
  }
}

final class _ProcessHelper implements PeriodicHelper {
  _ProcessHelper(this.process) {
    // Never retain or emit raw native diagnostics.
    _errors = process.stderr.drain<void>();
    _replies = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }
  final Process process;
  late final Future<void> _errors;
  late final StreamIterator<String> _replies;
  static Future<PeriodicHelper> start() async {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final encoded = base64Encode(
      windowsPeriodicHelper.codeUnits.expand((u) => [u & 255, u >> 8]).toList(),
    );
    final process = await Process.start(
      '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      ['-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      runInShell: false,
    );
    return _ProcessHelper(process);
  }

  @override
  Future<String> command(String command) async {
    process.stdin.writeln(command);
    await process.stdin.flush();
    if (!await _replies.moveNext().timeout(const Duration(seconds: 15))) {
      throw const PeriodicTerminalException(PeriodicTerminalFailure.automation);
    }
    return _replies.current;
  }

  @override
  Future<void> close() async {
    try {
      await process.stdin
          .close(); // EOF triggers helper finally and job disposal.
      await process.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      // The native kill-on-close job closes even if the helper is terminated.
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    } finally {
      await _replies.cancel();
      await _errors;
    }
  }
}
