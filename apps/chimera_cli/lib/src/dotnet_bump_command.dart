import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_platform/dotnet_bump.dart';

Future<int> runDotnetBumpCommand(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  DotnetBumpService? service,
}) async {
  const catalog = MessageCatalog();
  String message(String key) => catalog.lookup(localeTag, 'dotnetBump.$key');
  String? project;
  String? version;
  String? increment;
  var json = false;
  var help = false;
  final seen = <String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final option = arg.split('=').first;
    if (!{
          '--project',
          '--version',
          '--major',
          '--minor',
          '--patch',
          '--json',
          '--help',
          '-h',
        }.contains(option) ||
        !seen.add(option)) {
      err.writeln(message('invalidOptions'));
      return 2;
    }
    if (option == '--project' || option == '--version') {
      String value;
      if (arg.startsWith('$option=')) {
        value = arg.substring(option.length + 1);
      } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
        value = args[++i];
      } else {
        err.writeln(message('invalidOptions'));
        return 2;
      }
      if (option == '--project') {
        project = value;
      } else {
        version = value;
      }
    } else if ({'--major', '--minor', '--patch'}.contains(arg)) {
      if (increment != null) {
        err.writeln(message('invalidOptions'));
        return 2;
      }
      increment = arg.substring(2);
    } else if (arg == '--json') {
      json = true;
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
  if (service == null && !Platform.isLinux && !Platform.isWindows) {
    err.writeln(message('unsupported'));
    return 2;
  }
  final result = await (service ?? DotnetBumpService(NativeDotnetBumpGateway()))
      .execute(
        DotnetBumpRequest(
          project: project,
          version: version,
          increment: increment,
        ),
      );
  if (result case ChimeraFailure<DotnetBumpOutput>(
    :final kind,
    :final code,
    :final messageKey,
    :final details,
  )) {
    final text = catalog.lookup(localeTag, messageKey);
    if (json) {
      err.writeln(
        jsonEncode({'code': code, 'message': text, 'details': details}),
      );
    } else {
      err.writeln('$code: $text');
      if (details['candidates'] case final List<Object?> candidates) {
        for (final candidate in candidates) {
          err.writeln(candidate);
        }
      }
      if (details['backupPath'] case final String backup) {
        err.writeln('${message('backupRetained')}: $backup');
      }
      if (details['restored'] case final bool restored) {
        err.writeln(message(restored ? 'restored' : 'notRestored'));
      }
    }
    return kind == FailureKind.validation ? 2 : 1;
  }
  final output = (result as ChimeraSuccess<DotnetBumpOutput>).value;
  if (json) {
    out.writeln(jsonEncode(output.toJson()));
  } else {
    out.writeln(
      message('success')
          .replaceAll('{project}', output.project)
          .replaceAll(
            '{previous}',
            output.previousVersion ?? message('missing'),
          )
          .replaceAll('{version}', output.version),
    );
    if (output.backupPath case final backup?) {
      out.writeln('${message('backupRetained')}: $backup');
    }
  }
  return 0;
}
