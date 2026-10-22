import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/dotnet_clean.dart';

Future<int> runDotnetCleanCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  Future<String> Function()? readConfirmation,
  DotnetCleanService? service,
}) async {
  const catalog = MessageCatalog();
  String message(String key) => catalog.lookup(localeTag, 'dotnetClean.$key');
  String? root;
  var yes = false;
  var help = false;
  final seen = <String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final option = arg.split('=').first;
    if (!seen.add(option) ||
        !{'--root', '--yes', '--help', '-h'}.contains(option)) {
      err.writeln(message('invalidOptions'));
      return 2;
    }
    if (option == '--root') {
      if (arg.startsWith('--root=')) {
        root = arg.substring('--root='.length);
      } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
        root = args[++i];
      } else {
        err.writeln(message('invalidOptions'));
        return 2;
      }
    } else if (arg == '--yes') {
      yes = true;
    } else if (arg == '--help' || arg == '-h') {
      help = true;
    } else {
      err.writeln(message('invalidOptions'));
      return 2;
    }
  }
  if (help) {
    out.writeln(message('usage'));
    return 0;
  }
  if (service == null && !Platform.isWindows && !Platform.isLinux) {
    err.writeln(message('unsupported'));
    return 2;
  }
  final cleaner = service ?? DotnetCleanService(NativeDotnetCleanGateway());
  final result = await cleaner.preview(root: root);
  if (result case ChimeraFailure<DotnetCleanPreview>(
    :final code,
    :final messageKey,
  )) {
    err.writeln('$code: ${catalog.lookup(localeTag, messageKey)}');
    return 2;
  }
  final preview = (result as ChimeraSuccess<DotnetCleanPreview>).value;
  out.writeln('${message('scope')}: ${preview.root}');
  for (final path in preview.paths) {
    out.writeln(path);
  }
  if (preview.paths.isEmpty) {
    out.writeln(message('removed').replaceAll('{count}', '0'));
    return 0;
  }
  if (!yes) {
    out.writeln(message('confirmPrompt'));
    if (out is IOSink) await out.flush();
    String response = '';
    try {
      if (readConfirmation != null) {
        response = await readConfirmation();
      } else if (stdin.hasTerminal) {
        response = stdin.readLineSync() ?? '';
      }
    } on Object {
      response = '';
    }
    if (!{
      'yes',
      if (localeTag == 'pt-BR') 'sim',
    }.contains(response.trim().toLowerCase())) {
      err.writeln(message('confirmationRequired'));
      return 2;
    }
  }
  final cleaned = await cleaner.clean(preview, confirmed: true);
  if (cleaned case ChimeraFailure<DotnetCleanReport>(
    :final code,
    :final messageKey,
  )) {
    err.writeln('$code: ${catalog.lookup(localeTag, messageKey)}');
    return 2;
  }
  final report = (cleaned as ChimeraSuccess<DotnetCleanReport>).value;
  out.writeln(
    message('removed').replaceAll('{count}', '${report.removed.length}'),
  );
  for (final path in report.retained.keys) {
    err.writeln('${message('retained')}: $path');
  }
  return report.isPartialFailure ? 1 : 0;
}
