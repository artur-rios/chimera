import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';

typedef TextReader = Future<String> Function();
typedef FileTextReader = Future<String> Function(String path);

Future<int> runChimera(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  TextReader? readStandardInput,
  FileTextReader? readFile,
  CronService cronService = const CronService(),
  DateTime Function()? currentTime,
}) async {
  const catalog = MessageCatalog();
  final parser = _buildParser();

  try {
    final parsed = parser.parse(args);
    if (parsed.flag('help')) {
      out.writeln(catalog.lookup(localeTag, 'cli.usage'));
      return 0;
    }
    if (parsed.command == null) {
      err.writeln(catalog.lookup(localeTag, 'cli.noCommand'));
      return 64;
    }
    if (parsed.command!.name == 'cron' &&
        parsed.command!.command?.name == 'parse') {
      return await _runCronParse(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        cronService: cronService,
        currentTime: currentTime ?? DateTime.now,
      );
    }

    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  } on FormatException {
    final isCron = args.length >= 2 && args[0] == 'cron' && args[1] == 'parse';
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: isCron && args.contains('--json'),
      kind: 'validation',
      code: isCron ? 'cron.invalid-options' : 'cli.invalid-options',
      messageKey: isCron ? 'error.cron.validation' : 'error.unexpected',
    );
    return 64;
  }
}

ArgParser _buildParser() {
  final cronParse = ArgParser()
    ..addOption('expression', abbr: 'e')
    ..addOption('file', abbr: 'f')
    ..addOption('timezone', abbr: 'z', defaultsTo: 'UTC')
    ..addOption('count', abbr: 'n', defaultsTo: '5')
    ..addOption('at')
    ..addFlag('json', negatable: false);
  final cron = ArgParser()..addCommand('parse', cronParse);
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('cron', cron);
}

Future<int> _runCronParse(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required CronService cronService,
  required DateTime Function() currentTime,
}) async {
  final expressionOption = parsed.option('expression');
  final fileOption = parsed.option('file');
  if (expressionOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'cron.conflicting-inputs',
      messageKey: 'error.cron.validation',
    );
    return 64;
  }

  late String expression;
  if (fileOption != null) {
    try {
      expression = await readFile(fileOption);
    } on IOException {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: 'access',
        code: 'cron.file-access',
        messageKey: 'error.cron.fileAccess',
      );
      return 74;
    }
  } else if (expressionOption != null) {
    expression = expressionOption;
  } else {
    try {
      expression = await readStandardInput();
    } on IOException {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: 'access',
        code: 'cron.input-access',
        messageKey: 'error.cron.inputAccess',
      );
      return 74;
    }
  }

  final count = int.tryParse(parsed.option('count') ?? '');
  final atSource = parsed.option('at');
  final reference = atSource == null
      ? currentTime().toUtc()
      : parseCronReference(atSource);
  if (count == null || reference == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == null ? 'cron.invalid-count' : 'cron.invalid-reference',
      messageKey: 'error.cron.validation',
    );
    return 64;
  }

  final result = await cronService.execute(
    CronRequest(
      expression: expression.trim(),
      timeZone: parsed.option('timezone') ?? 'UTC',
      occurrenceCount: count,
      referenceUtc: reference,
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        _writeHumanCronResult(
          value,
          localeTag: localeTag,
          catalog: catalog,
          out: out,
        );
      }
      return 0;
    },
    onFailure: (failure) {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
      );
      return switch (failure.kind) {
        FailureKind.validation => 64,
        FailureKind.processing => 70,
        FailureKind.access => 74,
        FailureKind.resource => 75,
        FailureKind.update => 69,
        FailureKind.unexpected => 70,
      };
    },
  );
}

void _writeFailure(
  StringSink err, {
  required MessageCatalog catalog,
  required String localeTag,
  required bool json,
  required String kind,
  required String code,
  required String messageKey,
}) {
  final message = catalog.lookup(localeTag, messageKey);
  if (!json) {
    err.writeln(message);
    return;
  }
  err.writeln(
    jsonEncode(<String, Object?>{
      'error': <String, Object?>{
        'kind': kind,
        'code': code,
        'message': message,
      },
    }),
  );
}

void _writeHumanCronResult(
  CronOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
}) {
  final evaluation = output.evaluation;
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.scheduleLabel')}: '
    '${evaluation.normalizedExpression}',
  );
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.timeZoneLabel')}: ${evaluation.timeZone}',
  );
  final descriptions = evaluation.fields.entries
      .map((entry) {
        final label = catalog.lookup(localeTag, 'cron.field.${entry.key}');
        final value = entry.value == '*'
            ? catalog.lookup(localeTag, 'cron.everyValue')
            : entry.value;
        return '$label $value';
      })
      .join('; ');
  out.writeln(
    '${catalog.lookup(localeTag, 'cron.explanationLabel')}: $descriptions',
  );
  for (final occurrence in evaluation.previous) {
    out.writeln(
      '${catalog.lookup(localeTag, 'cron.previousLabel')}: '
      '${occurrence.localIso8601}',
    );
  }
  for (final occurrence in evaluation.next) {
    out.writeln(
      '${catalog.lookup(localeTag, 'cron.nextLabel')}: '
      '${occurrence.localIso8601}',
    );
  }
}
