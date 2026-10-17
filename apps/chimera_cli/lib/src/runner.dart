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
  ListCompareService listCompareService = const ListCompareService(),
  NumberBaseService numberBaseService = const NumberBaseService(),
  TextAnalyzeService textAnalyzeService = const TextAnalyzeService(),
  TextCompareService textCompareService = const TextCompareService(),
  TextEscapeService textEscapeService = const TextEscapeService(),
  TextTransformService textTransformService = const TextTransformService(),
  TextUnescapeService textUnescapeService = const TextUnescapeService(),
  SqlFormatService sqlFormatService = const SqlFormatService(),
  XmlFormatService xmlFormatService = const XmlFormatService(),
  DateTime Function()? currentTime,
}) async {
  const catalog = MessageCatalog();
  final parser = _buildParser();

  try {
    final parsed = parser.parse(_normalizeMultilineListOptions(args));
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
    if (parsed.command!.name == 'number' &&
        parsed.command!.command?.name == 'convert-base') {
      return await _runNumberBaseConvert(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        numberBaseService: numberBaseService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'analyze') {
      return await _runTextAnalyze(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textAnalyzeService: textAnalyzeService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'compare') {
      return await _runTextCompare(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textCompareService: textCompareService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'escape') {
      return await _runTextEscape(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textEscapeService: textEscapeService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'transform') {
      return await _runTextTransform(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textTransformService: textTransformService,
      );
    }
    if (parsed.command!.name == 'text' &&
        parsed.command!.command?.name == 'unescape') {
      return await _runTextUnescape(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        textUnescapeService: textUnescapeService,
      );
    }
    if (parsed.command!.name == 'list' &&
        parsed.command!.command?.name == 'compare') {
      return await _runListCompare(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        listCompareService: listCompareService,
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
    if (parsed.command!.name == 'xml' &&
        parsed.command!.command?.name == 'format') {
      return await _runXmlFormat(
        parsed.command!.command!,
        localeTag: localeTag,
        catalog: catalog,
        out: out,
        err: err,
        readStandardInput:
            readStandardInput ?? () => stdin.transform(utf8.decoder).join(),
        readFile: readFile ?? (path) => File(path).readAsString(),
        writeOutputFile: writeOutputFile ?? _writeFileExactly,
        xmlFormatService: xmlFormatService,
      );
    }

    err.writeln(catalog.lookup(localeTag, 'error.unexpected'));
    return 64;
  } on FormatException {
    final isCron = args.length >= 2 && args[0] == 'cron' && args[1] == 'parse';
    final isDate =
        args.length >= 2 && args[0] == 'date' && args[1] == 'convert';
    final isNumberBase =
        args.length >= 2 && args[0] == 'number' && args[1] == 'convert-base';
    final isTextEscape =
        args.length >= 2 && args[0] == 'text' && args[1] == 'escape';
    final isTextAnalyze =
        args.length >= 2 && args[0] == 'text' && args[1] == 'analyze';
    final isTextTransform =
        args.length >= 2 && args[0] == 'text' && args[1] == 'transform';
    final isTextCompare =
        args.length >= 2 && args[0] == 'text' && args[1] == 'compare';
    final isTextUnescape =
        args.length >= 2 && args[0] == 'text' && args[1] == 'unescape';
    final isListCompare =
        args.length >= 2 && args[0] == 'list' && args[1] == 'compare';
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
    final isXmlFormat =
        args.length >= 2 && args[0] == 'xml' && args[1] == 'format';
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json:
          (isCron ||
              isDate ||
              isNumberBase ||
              isTextAnalyze ||
              isTextTransform ||
              isTextCompare ||
              isTextEscape ||
              isTextUnescape ||
              isListCompare ||
              isJsonTable ||
              isJsonCsv ||
              isJsonYaml ||
              isJsonFormat ||
              isSqlFormat ||
              isXmlFormat) &&
          args.contains('--json'),
      kind: 'validation',
      code: isCron
          ? 'cron.invalid-options'
          : isDate
          ? 'date.invalid-options'
          : isNumberBase
          ? 'number-base.invalid-options'
          : isTextAnalyze
          ? 'text-analyze.invalid-options'
          : isTextTransform
          ? 'text-transform.invalid-options'
          : isTextCompare
          ? 'text-compare.invalid-options'
          : isTextEscape
          ? 'text-escape.invalid-options'
          : isTextUnescape
          ? 'text-unescape.invalid-options'
          : isListCompare
          ? 'list-compare.invalid-options'
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
          : isXmlFormat
          ? 'xml-format.invalid-options'
          : 'cli.invalid-options',
      messageKey: isCron
          ? 'error.cron.validation'
          : isDate
          ? 'error.date.validation'
          : isNumberBase
          ? 'error.numberBase.validation'
          : isTextAnalyze
          ? 'error.textAnalyze.validation'
          : isTextTransform
          ? 'error.textTransform.validation'
          : isTextCompare
          ? 'error.textCompare.validation'
          : isTextEscape
          ? 'error.textEscape.validation'
          : isTextUnescape
          ? 'error.textUnescape.validation'
          : isListCompare
          ? 'error.listCompare.validation'
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
          : isXmlFormat
          ? 'error.xmlFormat.validation'
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
  final numberConvertBase = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('from')
    ..addOption('to')
    ..addFlag('json', negatable: false);
  final number = ArgParser()..addCommand('convert-base', numberConvertBase);
  final textEscape = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final textAnalyze = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addFlag('json', negatable: false);
  final textCompare = ArgParser()
    ..addOption('left')
    ..addOption('left-file')
    ..addFlag('left-stdin', negatable: false)
    ..addOption('right')
    ..addOption('right-file')
    ..addFlag('right-stdin', negatable: false)
    ..addOption('output', abbr: 'o')
    ..addOption('granularity')
    ..addFlag('json', negatable: false);
  final textUnescape = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final textTransform = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('mode')
    ..addFlag('json', negatable: false);
  final text = ArgParser()
    ..addCommand('analyze', textAnalyze)
    ..addCommand('compare', textCompare)
    ..addCommand('escape', textEscape)
    ..addCommand('transform', textTransform)
    ..addCommand('unescape', textUnescape);
  final listCompare = ArgParser()
    ..addOption('left')
    ..addOption('left-file')
    ..addFlag('left-stdin', negatable: false)
    ..addOption('right')
    ..addOption('right-file')
    ..addFlag('right-stdin', negatable: false)
    ..addOption('output', abbr: 'o')
    ..addOption('case', defaultsTo: 'sensitive')
    ..addOption('whitespace', defaultsTo: 'preserve')
    ..addOption('duplicates', defaultsTo: 'preserve')
    ..addFlag('json', negatable: false);
  final list = ArgParser()..addCommand('compare', listCompare);
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
  final xmlFormat = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('file', abbr: 'f')
    ..addOption('output', abbr: 'o')
    ..addOption('indent', defaultsTo: '2')
    ..addFlag('json', negatable: false);
  final xml = ArgParser()..addCommand('format', xmlFormat);
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addCommand('cron', cron)
    ..addCommand('date', date)
    ..addCommand('json', json)
    ..addCommand('list', list)
    ..addCommand('number', number)
    ..addCommand('sql', sql)
    ..addCommand('text', text)
    ..addCommand('xml', xml);
}

Future<int> _runTextAnalyze(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextAnalyzeService textAnalyzeService,
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
      code: 'text-analyze.conflicting-inputs',
      messageKey: 'error.textAnalyze.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
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
          ? 'text-analyze.input-access'
          : 'text-analyze.file-access',
      messageKey: fileOption == null
          ? 'error.textAnalyze.inputAccess'
          : 'error.textAnalyze.fileAccess',
    );
    return 74;
  }

  final result = await textAnalyzeService.execute(
    TextAnalyzeOperationRequest(input: input),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanTextAnalyzeResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-analyze.output-access',
            messageKey: 'error.textAnalyze.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textAnalyze.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
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

String _humanTextAnalyzeResult(
  TextAnalyzeOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.characterCountLabel')}: '
      '${output.characterCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.wordCountLabel')}: '
      '${output.wordCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.lineCountLabel')}: '
      '${output.lineCount}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textAnalyze.byteCountLabel')}: '
      '${output.byteCount}',
    );
  return buffer.toString();
}

Future<int> _runTextEscape(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextEscapeService textEscapeService,
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
      code: 'text-escape.conflicting-inputs',
      messageKey: 'error.textEscape.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
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
          ? 'text-escape.input-access'
          : 'text-escape.file-access',
      messageKey: fileOption == null
          ? 'error.textEscape.inputAccess'
          : 'error.textEscape.fileAccess',
    );
    return 74;
  }

  final result = await textEscapeService.execute(
    TextEscapeOperationRequest(input: input, mode: parsed.option('mode') ?? ''),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.escaped));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'text-escape.output-access',
            messageKey: 'error.textEscape.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'textEscape.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'textEscape.resultLabel')}: '
          '${output.escaped}',
        );
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

Future<int> _runTextTransform(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextTransformService textTransformService,
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
      code: 'text-transform.conflicting-inputs',
      messageKey: 'error.textTransform.validation',
    );
    return 64;
  }

  final mode = parsed.option('mode') ?? '';
  try {
    parseTextTransformMode(mode);
  } on TextTransformException catch (error) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: error.kind.name,
      code: error.code,
      messageKey: 'error.textTransform.validation',
      details: <String, Object?>{
        'field': ?error.field,
        'reason': ?error.reason,
      },
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
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
          ? 'text-transform.input-access'
          : 'text-transform.file-access',
      messageKey: fileOption == null
          ? 'error.textTransform.inputAccess'
          : 'error.textTransform.fileAccess',
    );
    return 74;
  }

  final result = await textTransformService.execute(
    TextTransformOperationRequest(input: input, mode: mode),
  );
  return await result.fold(
    onSuccess: (output) async {
      final json = parsed.flag('json');
      final payload = json ? jsonEncode(output.toJson()) : output.output;
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-transform.output-access',
            messageKey: 'error.textTransform.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textTransform.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
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

Future<int> _runTextUnescape(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextUnescapeService textUnescapeService,
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
      code: 'text-unescape.conflicting-inputs',
      messageKey: 'error.textUnescape.validation',
    );
    return 64;
  }

  late String input;
  try {
    input = fileOption != null
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
          ? 'text-unescape.input-access'
          : 'text-unescape.file-access',
      messageKey: fileOption == null
          ? 'error.textUnescape.inputAccess'
          : 'error.textUnescape.fileAccess',
    );
    return 74;
  }

  final result = await textUnescapeService.execute(
    TextUnescapeOperationRequest(
      input: input,
      mode: parsed.option('mode') ?? '',
    ),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.unescaped));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'text-unescape.output-access',
            messageKey: 'error.textUnescape.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'textUnescape.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'textUnescape.resultLabel')}: '
          '${output.unescaped}',
        );
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

Future<int> _runListCompare(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required ListCompareService listCompareService,
}) async {
  final leftSources = <Object?>[
    parsed.option('left'),
    parsed.option('left-file'),
    if (parsed.flag('left-stdin')) true,
  ].where((source) => source != null).length;
  final rightSources = <Object?>[
    parsed.option('right'),
    parsed.option('right-file'),
    if (parsed.flag('right-stdin')) true,
  ].where((source) => source != null).length;

  if (leftSources != 1 || rightSources != 1) {
    final side = leftSources != 1 ? 'left' : 'right';
    final count = leftSources != 1 ? leftSources : rightSources;
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == 0
          ? 'list-compare.missing-$side-source'
          : 'list-compare.conflicting-$side-sources',
      messageKey: 'error.listCompare.validation',
    );
    return 64;
  }
  if (parsed.flag('left-stdin') && parsed.flag('right-stdin')) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'list-compare.shared-stdin',
      messageKey: 'error.listCompare.validation',
    );
    return 64;
  }

  late String left;
  late String right;
  try {
    left = await _readListSource(
      literal: parsed.option('left'),
      file: parsed.option('left-file'),
      standardInput: parsed.flag('left-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeListSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'left',
      file: parsed.option('left-file') != null,
    );
    return 74;
  }
  try {
    right = await _readListSource(
      literal: parsed.option('right'),
      file: parsed.option('right-file'),
      standardInput: parsed.flag('right-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeListSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'right',
      file: parsed.option('right-file') != null,
    );
    return 74;
  }

  final result = await listCompareService.execute(
    ListCompareOperationRequest(
      left: left,
      right: right,
      caseMode: parsed.option('case') ?? '',
      whitespaceMode: parsed.option('whitespace') ?? '',
      duplicateMode: parsed.option('duplicates') ?? '',
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanListCompareResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'list-compare.output-access',
            messageKey: 'error.listCompare.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'listCompare.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
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

Future<int> _runTextCompare(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required TextCompareService textCompareService,
}) async {
  final granularity = parsed.option('granularity') ?? '';
  try {
    parseTextCompareGranularity(granularity);
  } on TextCompareException catch (error) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: error.kind.name,
      code: error.code,
      messageKey: 'error.textCompare.validation',
      details: <String, Object?>{
        'field': ?error.field,
        'reason': ?error.reason,
      },
    );
    return 64;
  }

  final leftSources = <Object?>[
    parsed.option('left'),
    parsed.option('left-file'),
    if (parsed.flag('left-stdin')) true,
  ].where((source) => source != null).length;
  final rightSources = <Object?>[
    parsed.option('right'),
    parsed.option('right-file'),
    if (parsed.flag('right-stdin')) true,
  ].where((source) => source != null).length;

  if (leftSources != 1 || rightSources != 1) {
    final side = leftSources != 1 ? 'left' : 'right';
    final count = leftSources != 1 ? leftSources : rightSources;
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: count == 0
          ? 'text-compare.missing-$side-source'
          : 'text-compare.conflicting-$side-sources',
      messageKey: 'error.textCompare.validation',
    );
    return 64;
  }
  if (parsed.flag('left-stdin') && parsed.flag('right-stdin')) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'text-compare.shared-stdin',
      messageKey: 'error.textCompare.validation',
    );
    return 64;
  }

  late String left;
  late String right;
  try {
    left = await _readListSource(
      literal: parsed.option('left'),
      file: parsed.option('left-file'),
      standardInput: parsed.flag('left-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeTextCompareSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'left',
      file: parsed.option('left-file') != null,
    );
    return 74;
  }
  try {
    right = await _readListSource(
      literal: parsed.option('right'),
      file: parsed.option('right-file'),
      standardInput: parsed.flag('right-stdin'),
      readStandardInput: readStandardInput,
      readFile: readFile,
    );
  } on Object {
    _writeTextCompareSourceFailure(
      err,
      parsed: parsed,
      catalog: catalog,
      localeTag: localeTag,
      side: 'right',
      file: parsed.option('right-file') != null,
    );
    return 74;
  }

  final result = await textCompareService.execute(
    TextCompareOperationRequest(
      left: left,
      right: right,
      granularity: granularity,
    ),
  );
  return await result.fold(
    onSuccess: (value) async {
      final json = parsed.flag('json');
      final payload = json
          ? jsonEncode(value.toJson())
          : _humanTextCompareResult(
              value,
              localeTag: localeTag,
              catalog: catalog,
            );
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(payload));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: json,
            kind: 'access',
            code: 'text-compare.output-access',
            messageKey: 'error.textCompare.outputAccess',
          );
          return 74;
        }
        out.writeln(catalog.lookup(localeTag, 'textCompare.savedResult'));
      } else if (json) {
        out.writeln(payload);
      } else {
        out.write(payload);
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

List<String> _normalizeMultilineListOptions(List<String> args) {
  final normalized = <String>[];
  for (final argument in args) {
    final isLiteral =
        argument.startsWith('--input=') ||
        argument.startsWith('--left=') ||
        argument.startsWith('--right=');
    if (isLiteral && (argument.contains('\n') || argument.contains('\r'))) {
      final separator = argument.indexOf('=');
      normalized
        ..add(argument.substring(0, separator))
        ..add(argument.substring(separator + 1));
    } else {
      normalized.add(argument);
    }
  }
  return normalized;
}

Future<String> _readListSource({
  required String? literal,
  required String? file,
  required bool standardInput,
  required TextReader readStandardInput,
  required FileTextReader readFile,
}) {
  if (literal != null) return Future.value(literal);
  if (file != null) return readFile(file);
  assert(standardInput, 'A validated source must use standard input');
  return readStandardInput();
}

void _writeListSourceFailure(
  StringSink err, {
  required ArgResults parsed,
  required MessageCatalog catalog,
  required String localeTag,
  required String side,
  required bool file,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'access',
    code: 'list-compare.$side-${file ? 'file' : 'input'}-access',
    messageKey: file
        ? 'error.listCompare.fileAccess'
        : 'error.listCompare.inputAccess',
  );
}

void _writeTextCompareSourceFailure(
  StringSink err, {
  required ArgResults parsed,
  required MessageCatalog catalog,
  required String localeTag,
  required String side,
  required bool file,
}) {
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'access',
    code: 'text-compare.$side-${file ? 'file' : 'input'}-access',
    messageKey: file
        ? 'error.textCompare.fileAccess'
        : 'error.textCompare.inputAccess',
  );
}

String _humanTextCompareResult(
  TextCompareOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer();
  for (final span in output.spans) {
    buffer.writeln(
      '${catalog.lookup(localeTag, 'textCompare.kind.${span.kind.slug}')}: '
      '${_jsonEncodeHumanDiffText(span.text)}',
    );
  }
  buffer
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.addedCountLabel')}: '
      '${output.summary.added}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.removedCountLabel')}: '
      '${output.summary.removed}',
    )
    ..writeln(
      '${catalog.lookup(localeTag, 'textCompare.unchangedCountLabel')}: '
      '${output.summary.unchanged}',
    );
  return buffer.toString();
}

String _jsonEncodeHumanDiffText(String value) {
  final encoded = jsonEncode(value);
  final buffer = StringBuffer();
  for (final rune in encoded.runes) {
    if (_humanEscapedWhitespace.contains(rune)) {
      buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

const Set<int> _humanEscapedWhitespace = <int>{
  0x0085,
  0x00A0,
  0x1680,
  0x2000,
  0x2001,
  0x2002,
  0x2003,
  0x2004,
  0x2005,
  0x2006,
  0x2007,
  0x2008,
  0x2009,
  0x200A,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
};

String _humanListCompareResult(
  ListCompareOutput output, {
  required String localeTag,
  required MessageCatalog catalog,
}) {
  final buffer = StringBuffer();
  void writeSection(String messageKey, List<String> values) {
    buffer.writeln('${catalog.lookup(localeTag, messageKey)}:');
    for (final value in values) {
      buffer.writeln(value);
    }
  }

  writeSection('listCompare.leftOnlyLabel', output.leftOnly);
  writeSection('listCompare.rightOnlyLabel', output.rightOnly);
  writeSection('listCompare.intersectionLabel', output.intersection);
  buffer.writeln(
    '${catalog.lookup(localeTag, 'listCompare.equalLabel')}: '
    '${catalog.lookup(localeTag, output.equal ? 'listCompare.yesValue' : 'listCompare.noValue')}',
  );
  return buffer.toString();
}

Future<int> _runNumberBaseConvert(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required NumberBaseService numberBaseService,
}) async {
  final sourceBase = _parseNumberBase(
    parsed.option('from'),
    field: 'sourceBase',
    parsed: parsed,
    localeTag: localeTag,
    catalog: catalog,
    err: err,
  );
  if (sourceBase == null) return 64;
  final targetBase = _parseNumberBase(
    parsed.option('to'),
    field: 'targetBase',
    parsed: parsed,
    localeTag: localeTag,
    catalog: catalog,
    err: err,
  );
  if (targetBase == null) return 64;

  final inputOption = parsed.option('input');
  final fileOption = parsed.option('file');
  if (inputOption != null && fileOption != null) {
    _writeFailure(
      err,
      catalog: catalog,
      localeTag: localeTag,
      json: parsed.flag('json'),
      kind: 'validation',
      code: 'number-base.conflicting-inputs',
      messageKey: 'error.numberBase.validation',
    );
    return 64;
  }

  late String value;
  try {
    value = fileOption != null
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
          ? 'number-base.input-access'
          : 'number-base.file-access',
      messageKey: fileOption == null
          ? 'error.numberBase.inputAccess'
          : 'error.numberBase.fileAccess',
    );
    return 74;
  }

  final result = await numberBaseService.execute(
    NumberBaseOperationRequest(
      value: value,
      sourceBase: sourceBase,
      targetBase: targetBase,
    ),
  );
  return await result.fold(
    onSuccess: (output) async {
      final outputPath = parsed.option('output');
      if (outputPath != null) {
        try {
          await writeOutputFile(outputPath, utf8.encode(output.converted));
        } on Object {
          _writeFailure(
            err,
            catalog: catalog,
            localeTag: localeTag,
            json: parsed.flag('json'),
            kind: 'access',
            code: 'number-base.output-access',
            messageKey: 'error.numberBase.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'numberBase.savedResult'));
          return 0;
        }
      }
      if (parsed.flag('json')) {
        out.writeln(jsonEncode(output.toJson()));
      } else {
        out.writeln(
          '${catalog.lookup(localeTag, 'numberBase.resultLabel')}: '
          '${output.converted}',
        );
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

int? _parseNumberBase(
  String? raw, {
  required String field,
  required ArgResults parsed,
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink err,
}) {
  final parsedBase = raw == null ? null : int.tryParse(raw);
  final reason = raw == null
      ? 'missing-base'
      : parsedBase == null
      ? 'not-an-integer'
      : parsedBase < 2 || parsedBase > 36
      ? 'out-of-range-base'
      : null;
  if (reason == null) return parsedBase;
  _writeFailure(
    err,
    catalog: catalog,
    localeTag: localeTag,
    json: parsed.flag('json'),
    kind: 'validation',
    code: 'number-base.invalid-base',
    messageKey: 'error.numberBase.validation',
    details: <String, Object?>{'field': field, 'reason': reason},
  );
  return null;
}

Future<int> _runXmlFormat(
  ArgResults parsed, {
  required String localeTag,
  required MessageCatalog catalog,
  required StringSink out,
  required StringSink err,
  required TextReader readStandardInput,
  required FileTextReader readFile,
  required FileBytesWriter writeOutputFile,
  required XmlFormatService xmlFormatService,
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
      code: 'xml-format.conflicting-inputs',
      messageKey: 'error.xmlFormat.validation',
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
          ? 'xml-format.input-access'
          : 'xml-format.file-access',
      messageKey: fileOption == null
          ? 'error.xmlFormat.inputAccess'
          : 'error.xmlFormat.fileAccess',
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
      code: 'xml-format.invalid-indent',
      messageKey: 'error.xmlFormat.validation',
    );
    return 64;
  }

  final result = await xmlFormatService.execute(
    XmlFormatOperationRequest(source: source, indent: indent),
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
            code: 'xml-format.output-access',
            messageKey: 'error.xmlFormat.outputAccess',
          );
          return 74;
        }
        if (!parsed.flag('json')) {
          out.writeln(catalog.lookup(localeTag, 'xmlFormat.savedResult'));
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
      if (location != null) {
        err.writeln(
          '${catalog.lookup(localeTag, 'jsonTable.locationLabel')}: $location',
        );
      }
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
