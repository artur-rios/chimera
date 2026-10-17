import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';

typedef TextReader = Future<String> Function();
typedef FileTextReader = Future<String> Function(String path);
typedef FileBytesWriter = Future<void> Function(String path, List<int> bytes);

Future<int> runChimera(
  List<String> args, {
  required String localeTag,
  required StringSink out,
  required StringSink err,
  TextReader? readStandardInput,
  FileTextReader? readFile,
  FileBytesWriter? writeOutputFile,
  CronService cronService = const CronService(),
  DateService dateService = const DateService(),
  JsonCsvService jsonCsvService = const JsonCsvService(),
  JsonFormatService jsonFormatService = const JsonFormatService(),
  JsonTableService jsonTableService = const JsonTableService(),
  JsonYamlService jsonYamlService = const JsonYamlService(),
  SqlFormatService sqlFormatService = const SqlFormatService(),
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
    if (parsed.command!.name == 'date' &&
        parsed.command!.command?.name == 'convert') {
      return await _runDateConvert(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        dateService: dateService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'array-to-table') {
      return await _runJsonArrayToTable(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        jsonTableService: jsonTableService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'array-to-csv') {
      return await _runJsonArrayToCsv(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonCsvService: jsonCsvService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'to-yaml') {
      return await _runJsonToYaml(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonYamlService: jsonYamlService,
      );
    }
    if (parsed.command!.name == 'json' &&
        parsed.command!.command?.name == 'format') {
      return await _runJsonFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        jsonFormatService: jsonFormatService,
      );
    }
    if (parsed.command!.name == 'sql' &&
        parsed.command!.command?.name == 'format') {
      return await _runSqlFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        sqlFormatService: sqlFormatService,
      );
    }

    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  } on FormatException {
    final isCron = args.length >= 2 && args[0] == 'cron' && args[1] == 'parse';
    final isDate =
        args.length >= 2 && args[0] == 'date' && args[1] == 'convert';
    final isJsonTable =
        args.length >= 2 && args[0] == 'json' && args[1] == 'array-to-table';
    final isJsonCsv =
        args.length >= 2 && args[0] == 'json' && args[1] == 'array-to-csv';
    final isJsonYaml =
        args.length >= 2 && args[0] == 'json' && args[1] == 'to-yaml';
    final isJsonFormat =
        args.length >= 2 && args[0] == 'json' && args[1] == 'format';
    final isSqlFormat =
        args.length >= 2 && args[0] == 'sql' && args[1] == 'format';
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json:
          (isCron ||
              isDate ||
              isJsonTable ||
              isJsonCsv ||
              isJsonYaml ||
              isJsonFormat ||
              isSqlFormat) &&
          args.contains('--json'),
      kind: 'validation',
      code: isCron
          ? 'cron.invalid-options'
          : isDate
          ? 'date.invalid-options'
          : isJsonTable
          ? 'json-table.invalid-options'
          : isJsonCsv
          ? 'json-csv.invalid-options'
          : isJsonYaml
          ? 'json-yaml.invalid-options'
          : isJsonFormat
          ? 'json-format.invalid-options'
          : isSqlFormat
          ? 'sql-format.invalid-options'
          : 'cli.invalid-options',
      messageKey: isCron
          ? 'error.cron.validation'
          : isDate
          ? 'error.date.validation'
          : isJsonTable
          ? 'error.jsonTable.validation'
          : isJsonCsv
          ? 'error.jsonCsv.validation'
          : isJsonYaml
          ? 'error.jsonYaml.validation'
          : isJsonFormat
          ? 'error.jsonFormat.validation'
          : isSqlFormat
          ? 'error.sqlFormat.validation'
          : 'error.unexpected',
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
  final dateConvert = ArgParser()
    ..addOption('value', abbr: 'v')
    ..addOption('file', abbr: 'f')
    ..addOption('from')
    ..addOption('to')
    ..addOption('source-timezone', defaultsTo: 'UTC')
    ..addOption('target-timezone', defaultsTo: 'UTC')
    ..addOption('source-pattern')
    ..addOption('target-pattern')
    ..addFlag('json', negatable: false);
  final date = ArgParser()..addCommand('convert', dateConvert);
  final jsonArrayToTable = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addFlag('row-numbers', negatable: false)
    ..addFlag('json', negatable: false);
  final jsonArrayToCsv = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('delimiter', defaultsTo: 'comma')
    ..addFlag('headers', defaultsTo: true)
    ..addFlag('json', negatable: false);
  final jsonToYaml = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('quote-strings', negatable: false)
    ..addFlag('json', negatable: false);
  final jsonFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('json', negatable: false);
  final json = ArgParser()
    ..addCommand('array-to-table', jsonArrayToTable)
    ..addCommand('array-to-csv', jsonArrayToCsv)
    ..addCommand('to-yaml', jsonToYaml)
    ..addCommand('format', jsonFormat);
  final sqlFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('dialect', defaultsTo: 'postgresql')
    ..addOption('indent', defaultsTo: '2')
    ..addOption('keyword-case', defaultsTo: 'upper')
    ..addFlag('json', negatable: false);
  final sql = ArgParser()..addCommand('format', sqlFormat);
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('cron', cron)
    ..addCommand('date', date)
    ..addCommand('json', json)
    ..addCommand('sql', sql);
}

Future<int> _runSqlFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required SqlFormatService sqlFormatService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'sql-format.conflicting-inputs',
      messageKey: 'error.sqlFormat.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'sql-format.input-access'
          : 'sql-format.file-access',
      messageKey: fileOption == null
          ? 'error.sqlFormat.inputAccess'
          : 'error.sqlFormat.fileAccess',
    );
    return 74;
  }

  final dialect = parseSqlDialect(parsed.option('dialect') ?? '');
  final indent = int.tryParse(parsed.option('indent') ?? '');
  final keywordCase = parseSqlKeywordCase(parsed.option('keyword-case') ?? '');
  if (dialect == null || indent == null || keywordCase == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: dialect == null
          ? 'sql-format.invalid-dialect'
          : indent == null
          ? 'sql-format.invalid-indent'
          : 'sql-format.invalid-keyword-case',
      messageKey: 'error.sqlFormat.validation',
    );
    return 64;
  }

  final result = await sqlFormatService.execute(
    SqlFormatOperationRequest(
      source: source,
      dialect: dialect,
      indent: indent,
      keywordCase: keywordCase,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.formatted));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'sql-format.output-access',
            messageKey: 'error.sqlFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'sqlFormat.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.formatted);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonFormatService jsonFormatService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-format.conflicting-inputs',
      messageKey: 'error.jsonFormat.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on Object {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-format.input-access'
          : 'json-format.file-access',
      messageKey: fileOption == null
          ? 'error.jsonFormat.inputAccess'
          : 'error.jsonFormat.fileAccess',
    );
    return 74;
  }

  final indent = int.tryParse(parsed.option('indent') ?? '');
  if (indent == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-format.invalid-indent',
      messageKey: 'error.jsonFormat.validation',
    );
    return 64;
  }
  final result = await jsonFormatService.execute(
    JsonFormatOperationRequest(source: source, indent: indent),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.formatted));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-format.output-access',
            messageKey: 'error.jsonFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonFormat.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.formatted);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonToYaml(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonYamlService jsonYamlService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-yaml.conflicting-inputs',
      messageKey: 'error.jsonYaml.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-yaml.input-access'
          : 'json-yaml.file-access',
      messageKey: fileOption == null
          ? 'error.jsonYaml.inputAccess'
          : 'error.jsonYaml.fileAccess',
    );
    return 74;
  }

  final indent = int.tryParse(parsed.option('indent') ?? '');
  if (indent == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-yaml.invalid-indent',
      messageKey: 'error.jsonYaml.validation',
    );
    return 64;
  }
  final result = await jsonYamlService.execute(
    JsonYamlOperationRequest(
      source: source,
      indent: indent,
      quoteStrings: parsed.flag('quote-strings'),
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.yaml));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-yaml.output-access',
            messageKey: 'error.jsonYaml.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonYaml.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.yaml);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runJsonArrayToCsv(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required JsonCsvService jsonCsvService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-csv.conflicting-inputs',
      messageKey: 'error.jsonCsv.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-csv.input-access'
          : 'json-csv.file-access',
      messageKey: fileOption == null
          ? 'error.jsonCsv.inputAccess'
          : 'error.jsonCsv.fileAccess',
    );
    return 74;
  }

  final result = await jsonCsvService.execute(
    JsonCsvOperationRequest(
      source: source,
      delimiter: parsed.option('delimiter') ?? 'comma',
      includeHeaders: parsed.flag('headers'),
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(value.csv));
        } on IOException {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'json-csv.output-access',
            messageKey: 'error.jsonCsv.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'jsonCsv.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.write(value.csv);
      }
      return 0;
    },
    onFailure: (failure) async {
      _writeFailure(
        err,
        catalog: catalog,
        localeTag: localeTag,
        json: parsed.flag('json'),
        kind: failure.kind.name,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<void> _writeFileExactly(String path, List<int> bytes) async {
  final target = File(path);
  try {
    await target.writeAsBytes(bytes, flush: true);
  } on Object {
    try {
      if (await target.exists()) await target.delete();
    } on IOException {
      // Preserve the original write failure as the actionable diagnostic.
    }
    rethrow;
  }
}

Future<int> _runJsonArrayToTable(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required JsonTableService jsonTableService,
}) async {
  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'json-table.conflicting-inputs',
      messageKey: 'error.jsonTable.validation',
    );
    return 64;
  }

  late String source;
  try {
    source = fileOption != null
        ? await readFile(fileOption)
        : inputOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null
          ? 'json-table.input-access'
          : 'json-table.file-access',
      messageKey: fileOption == null
          ? 'error.jsonTable.inputAccess'
          : 'error.jsonTable.fileAccess',
    );
    return 74;
  }

  final result = await jsonTableService.execute(
    JsonTableOperationRequest(
      source: source,
      includeRowNumbers: parsed.flag('row-numbers'),
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        _writeHumanJsonTable(
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
        details: failure.details,
      );
      return _exitCodeFor(failure.kind);
    },
  );
}

Future<int> _runDateConvert(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required DateService dateService,
}) async {
  final valueOption = parsed.option('value');
  final fileOption = parsed.option('file');
  if (valueOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'date.conflicting-inputs',
      messageKey: 'error.date.validation',
    );
    return 64;
  }

  late String value;
  try {
    value = fileOption != null
        ? await readFile(fileOption)
        : valueOption ?? await readStandardInput();
  } on IOException {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'access',
      code: fileOption == null ? 'date.input-access' : 'date.file-access',
      messageKey: fileOption == null
          ? 'error.date.inputAccess'
          : 'error.date.fileAccess',
    );
    return 74;
  }

  final source = DateRepresentation.tryParse(parsed.option('from') ?? '');
  final target = DateRepresentation.tryParse(parsed.option('to') ?? '');
  if (source == null || target == null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'date.invalid-representation',
      messageKey: 'error.date.validation',
    );
    return 64;
  }

  final result = await dateService.execute(
    DateRequest(
      value: value.trim(),
      sourceRepresentation: source,
      targetRepresentation: target,
      sourceTimeZone: parsed.option('source-timezone') ?? 'UTC',
      targetTimeZone: parsed.option('target-timezone') ?? 'UTC',
      sourcePattern: parsed.option('source-pattern'),
      targetPattern: parsed.option('target-pattern'),
    ),
  );
  return result.fold(
    onSuccess: (value) {
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(value.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'date.resultLabel')}: '
          '${value.conversion.convertedValue}',
        );
        out.writeln(
          '${catalog.lookup(localeTag, 'date.utcLabel')}: '
          '${value.conversion.utcIso8601}',
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
      return _exitCodeFor(failure.kind);
    },
  );
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
      return _exitCodeFor(failure.kind);
    },
  );
}

int _exitCodeFor(FailureKind kind) => switch (kind) {
  FailureKind.validation => 64,
  FailureKind.range => 70,
  FailureKind.processing => 70,
  FailureKind.access => 74,
  FailureKind.resource => 75,
  FailureKind.update => 69,
  FailureKind.unexpected => 70,
};

void _writeFailure(
  StringSink err, {
  required MessageCatalog catalog,
  required String localeTag,
  required bool json,
  required String kind,
  required String code,
  required String messageKey,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  final message = catalog.lookup(localeTag, messageKey);
  if (!json) {
    err.writeln(message);
    if (details.isNotEmpty) {
      final location = details['path'] ?? details['offset'];
      err.writeln(
        '${catalog.lookup(localeTag, 'jsonTable.locationLabel')}: $location',
      );
    }
    return;
  }
  err.writeln(
    jsonEncode(<String, Object?>{
      'error': <String, Object?>{
        'kind': kind,
        'code': code,
        'message': message,
        if (details.isNotEmpty) 'location': details,
      },
    }),
  );
}

void _writeHumanJsonTable(
  JsonTableOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
}) {
  final table = output.table;
  if (table.rows.isEmpty) {
    out.writeln(catalog.lookup(localeTag, 'jsonTable.emptyResult'));
    return;
  }
  if (table.columns.isEmpty && !table.includeRowNumbers) {
    out.writeln(catalog.lookup(localeTag, 'jsonTable.noColumnsResult'));
    out.writeln(
      '${catalog.lookup(localeTag, 'jsonTable.rowCountLabel')}: '
      '${table.rows.length}',
    );
    return;
  }

  final headings = <String>[
    if (table.includeRowNumbers)
      catalog.lookup(localeTag, 'jsonTable.rowNumberLabel'),
    ...table.columns,
  ];
  out.writeln('| ${headings.map(_escapeTableCell).join(' | ')} |');
  out.writeln('| ${headings.map((_) => '---').join(' | ')} |');
  for (var index = 0; index < table.rows.length; index++) {
    final cells = <String>[
      if (table.includeRowNumbers) '${index + 1}',
      ...table.rows[index],
    ];
    out.writeln('| ${cells.map(_escapeTableCell).join(' | ')} |');
  }
}

String _escapeTableCell(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll('|', r'\|')
    .replaceAll('\r\n', '<br>')
    .replaceAll('\r', '<br>')
    .replaceAll('\n', '<br>');

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
