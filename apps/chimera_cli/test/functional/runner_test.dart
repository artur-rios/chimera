import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenNoCommand_WhenCliRunsInPortuguese_ThenLocalizedFailureIsReturned',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[],
        localeTag: 'pt-BR',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Nenhum comando foi informado.\n');
    },
  );

  test(
    'GivenHelpFlag_WhenCliRuns_ThenLocalizedUsageIsWrittenToStdout',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['--help'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(out.toString(), 'Usage: chimera <command> [options]\n');
      expect(err.toString(), isEmpty);
    },
  );

  test(
    'GivenSensitiveUnknownArguments_WhenCliRejectsThem_ThenValuesAreNotLogged',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['--unknown', 'secret-value'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(err.toString(), 'An unexpected error occurred.\n');
      expect(err.toString(), isNot(contains('secret-value')));
    },
  );

  test(
    'GivenCronArguments_WhenParseRuns_ThenLocalizedHumanResultIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'cron',
          'parse',
          '--expression',
          '0 9 * * MON-FRI',
          '--timezone',
          'UTC',
          '--count',
          '1',
          '--at',
          '2026-01-05T12:00:00Z',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(out.toString(), contains('Cron schedule: 0 9 * * 1-5'));
      expect(out.toString(), contains('Time zone: UTC'));
      expect(
        out.toString(),
        contains('Previous: 2026-01-05T09:00:00.000+00:00'),
      );
      expect(out.toString(), contains('Next: 2026-01-06T09:00:00.000+00:00'));
    },
  );

  test('GivenCronArgumentsAndJsonFlag_WhenParseRuns_ThenStableMachineResultIsWritten', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'cron',
        'parse',
        '--expression=30 */15 * * * *',
        '--timezone=UTC',
        '--count=1',
        '--at=2026-01-15T12:00:00Z',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    final json = jsonDecode(out.toString()) as Map<String, dynamic>;
    expect(json['expression'], '30 */15 * * * *');
    expect(json['hasSeconds'], isTrue);
    expect(
      (json['next'] as List<dynamic>).single,
      containsPair('utc', '2026-01-15T12:00:30.000Z'),
    );
  });

  test('GivenStandardInput_WhenCronParseRunsInPortuguese_ThenLocalizedResultIsWritten', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'cron',
        'parse',
        '--timezone=UTC',
        '--count=1',
        '--at=2026-01-05T12:00:00Z',
      ],
      localeTag: 'pt-BR',
      out: out,
      err: err,
      readStandardInput: () async => '0 9 * * *',
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    expect(out.toString(), contains('Agendamento cron: 0 9 * * *'));
    expect(out.toString(), contains('Fuso horário: UTC'));
    expect(out.toString(), contains('Anterior:'));
    expect(out.toString(), contains('Próxima:'));
  });

  test('GivenLocalFileFlag_WhenCronParseRuns_ThenFileContentIsUsed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-cron-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}schedule.txt');
    await file.writeAsString('0 9 * * *');
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'cron',
        'parse',
        '--file=${file.path}',
        '--timezone=UTC',
        '--count=1',
        '--at=2026-01-05T12:00:00Z',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), containsPair('expression', '0 9 * * *'));
  });

  test(
    'GivenInvalidCronInput_WhenParseRuns_ThenValidationExitDoesNotEchoInput',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'cron',
          'parse',
          '--expression=secret invalid input',
          '--timezone=UTC',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The cron request is invalid.\n');
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test('GivenInvalidCronInputAndJsonFlag_WhenParseRuns_ThenStableMachineFailureIsWritten', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'cron',
        'parse',
        '--expression=secret invalid input',
        '--timezone=UTC',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(jsonDecode(err.toString()), <String, Object?>{
      'error': <String, Object?>{
        'kind': 'validation',
        'code': 'cron.invalid-field-count',
        'message': 'The cron request is invalid.',
      },
    });
    expect(err.toString(), isNot(contains('secret')));
  });

  test(
    'GivenUnreadableCronFile_WhenParseRuns_ThenFileAccessExitIsReturned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-cli-cron-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final missingPath =
          '${directory.path}${Platform.pathSeparator}sensitive-missing.txt';
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['cron', 'parse', '--file=$missingPath'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The input file could not be read.\n');
      expect(err.toString(), isNot(contains('sensitive-missing')));
    },
  );

  test('GivenInvalidCronFileContent_WhenParseRuns_ThenValidationDoesNotEchoContent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-cron-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}invalid.txt');
    await file.writeAsString('secret invalid input');
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>['cron', 'parse', '--file=${file.path}', '--timezone=UTC'],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'The cron request is invalid.\n');
    expect(err.toString(), isNot(contains('secret')));
  });

  test(
    'GivenUnreadableStandardInput_WhenParseRuns_ThenInputAccessExitIsReturned',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['cron', 'parse'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInput: () async =>
            throw const FileSystemException('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The input could not be read.\n');
    },
  );

  test(
    'GivenReferenceWithoutOffset_WhenParseRuns_ThenValidationExitIsReturned',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'cron',
          'parse',
          '--expression=* * * * *',
          '--at=2026-01-05T12:00:00',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The cron request is invalid.\n');
    },
  );

  test(
    'GivenCronSearchBudgetFailure_WhenParseRuns_ThenResourceExitIsReturned',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'cron',
          'parse',
          '--expression=0 0 1 12 *',
          '--at=2026-01-02T00:00:00Z',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        cronService: const CronService(
          evaluator: CronEvaluator(maxSearchDays: 1),
        ),
      );

      expect(exitCode, 75);
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        'The cron calculation exceeded its resource limit.\n',
      );
    },
  );

  test(
    'GivenDateArguments_WhenConvertRuns_ThenLocalizedHumanResultIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'date',
          'convert',
          '--value=2026-01-15T12:30:45Z',
          '--from=iso8601',
          '--to=custom',
          '--target-timezone=America/Sao_Paulo',
          '--target-pattern=dd/MM/yyyy HH:mm:ss',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(out.toString(), contains('Converted value: 15/01/2026 09:30:45'));
      expect(out.toString(), contains('UTC instant: 2026-01-15T12:30:45.000Z'));
    },
  );

  test('GivenDateStandardInputAndJson_WhenConvertRuns_ThenStableMachineResultIsWritten', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'date',
        'convert',
        '--from=unix-seconds',
        '--to=iso8601',
        '--target-timezone=UTC',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      readStandardInput: () async => '0',
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    expect(
      jsonDecode(out.toString()),
      containsPair('value', '1970-01-01T00:00:00.000+00:00'),
    );
  });

  test('GivenLocalDateFile_WhenConvertRuns_ThenFileContentIsUsed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-date-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}date.txt');
    await file.writeAsString('2026-01-15T09:30:45');
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'date',
        'convert',
        '--file=${file.path}',
        '--from=iso8601',
        '--to=unix-seconds',
        '--source-timezone=America/Sao_Paulo',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), containsPair('value', '1768480245'));
  });

  test(
    'GivenInvalidDate_WhenConvertRunsInPortuguese_ThenInputIsRedacted',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'date',
          'convert',
          '--value=segredo inválido',
          '--from=iso8601',
          '--to=iso8601',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'A solicitação de data é inválida.\n');
      expect(err.toString(), isNot(contains('segredo')));
    },
  );

  test(
    'GivenOutOfRangeDate_WhenConvertRuns_ThenTypedRangeExitIsReturned',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'date',
          'convert',
          '--value=999999999999999999999',
          '--from=unix-milliseconds',
          '--to=iso8601',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 70);
      expect(jsonDecode(err.toString()), <String, Object?>{
        'error': <String, Object?>{
          'kind': 'range',
          'code': 'date.out-of-range',
          'message': 'The date is outside the supported range.',
        },
      });
    },
  );

  test(
    'GivenJsonArray_WhenTableRuns_ThenMarkdownWithRowNumbersIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-table',
          '--input=[{"name":"Ada","meta":{"x":1}},{"name":"Lin"}]',
          '--row-numbers',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(out.toString(), contains('| # | name | meta |'));
      expect(out.toString(), contains('| 1 | Ada | {"x":1} |'));
      expect(out.toString(), contains('| 2 | Lin |  |'));
    },
  );

  test(
    'GivenJsonStandardInput_WhenTableRunsWithJson_ThenStableResultIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'array-to-table', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInput: () async => '[{"active":true}]',
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'columns': <Object?>['active'],
        'rows': <Object?>[
          <Object?>['true'],
        ],
        'includeRowNumbers': false,
        'rowCount': 1,
      });
    },
  );

  test('GivenLocalJsonFile_WhenTableRuns_ThenFileContentIsUsed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-json-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}rows.json');
    await file.writeAsString('[{"name":"Ada"}]');
    final out = StringBuffer();

    final exitCode = await runChimera(
      <String>['json', 'array-to-table', '--file=${file.path}', '--json'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), containsPair('rowCount', 1));
  });

  test(
    'GivenMalformedJson_WhenTableRuns_ThenOffsetFailureRedactsInput',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-table',
          '--input=[{"secret":}]',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 64);
      final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(failure['error'], containsPair('code', 'json-table.invalid-json'));
      expect(failure['error'], containsPair('location', contains('offset')));
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenNonObjectMember_WhenTableRunsInPortuguese_ThenPathIsShown',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'array-to-table', '--input=[false]'],
        localeTag: 'pt-BR',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      expect(err.toString(), contains('O array JSON é inválido.'));
      expect(err.toString(), contains(r'$[0]'));
    },
  );

  test(
    'GivenTableCellBudgetExceeded_WhenTableRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'array-to-table', '--input=[{"a":1},{"a":2}]'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        jsonTableService: const JsonTableService(
          converter: JsonTableConverter(maxCells: 1),
        ),
      );

      expect(exitCode, 75);
      expect(err.toString(), 'The table exceeded its resource limit.\n');
    },
  );

  test(
    'GivenOnlyEmptyObjects_WhenTableRuns_ThenZeroColumnCountIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'array-to-table', '--input=[{}]'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), 'The array contains no columns.\nRow count: 1\n');
    },
  );

  test(
    'GivenBackslashBeforePipe_WhenTableRuns_ThenMarkdownCellIsSafe',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-table',
          r'--input=[{"value":"a\\|b"}]',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), contains(r'| a\\\|b |'));
    },
  );

  test(
    'GivenUnsupportedJsonNumber_WhenTableRuns_ThenTypedFailureIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-table',
          '--input=[{"value":1e400}]',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      expect(
        jsonDecode(err.toString()),
        containsPair(
          'error',
          containsPair('code', 'json-table.unsupported-number'),
        ),
      );
    },
  );

  test('GivenJsonArray_WhenCsvRuns_ThenQuotedCsvIsWritten', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'json',
        'array-to-csv',
        '--input=[{"name":"Ada, A.","meta":{"x":1}}]',
        '--delimiter=comma',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    expect(out.toString(), 'name,meta\r\n"Ada, A.","{""x"":1}"');
  });

  test(
    'GivenJsonStandardInput_WhenCsvRunsWithoutHeaders_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-csv',
          '--delimiter=semicolon',
          '--no-headers',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        readStandardInput: () async => '[{"name":"Ada"}]',
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'csv': 'Ada',
        'columns': <Object?>['name'],
        'delimiter': 'semicolon',
        'includeHeaders': false,
        'rowCount': 1,
      });
    },
  );

  test('GivenInputAndOutputFiles_WhenCsvRuns_ThenExactBytesAreSaved', () async {
    final directory = await Directory.systemTemp.createTemp('chimera-cli-csv-');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}rows.json');
    final output = File('${directory.path}${Platform.pathSeparator}rows.csv');
    await input.writeAsString('[{"name":"Ada"},{"name":"Lin"}]');
    await output.writeAsString('old output');
    final out = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'json',
        'array-to-csv',
        '--file=${input.path}',
        '--output=${output.path}',
        '--delimiter=pipe',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'CSV saved.\n');
    expect(await output.readAsBytes(), utf8.encode('name\r\nAda\r\nLin'));
    expect(
      directory.listSync().map(
        (entity) => entity.path.split(Platform.pathSeparator).last,
      ),
      unorderedEquals(<String>['rows.json', 'rows.csv']),
    );
  });

  test(
    'GivenInvalidCsvDelimiter_WhenCsvRuns_ThenValidationExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-csv',
          '--input=[]',
          '--delimiter=colon',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      expect(
        jsonDecode(err.toString()),
        containsPair(
          'error',
          containsPair('code', 'json-csv.invalid-delimiter'),
        ),
      );
    },
  );

  test(
    'GivenMalformedJson_WhenCsvRuns_ThenOffsetFailureRedactsInput',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-csv',
          '--input=[{"secret":}]',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(failure['error'], containsPair('code', 'json-csv.invalid-json'));
      expect(failure['error'], containsPair('location', contains('offset')));
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenOutputWriteFailure_WhenCsvRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'array-to-csv',
          '--input=[{"secret":"value"}]',
          '--output=sensitive.csv',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (path, bytes) async =>
            throw const FileSystemException('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o arquivo CSV.\n');
      expect(err.toString(), isNot(contains('secret')));
      expect(err.toString(), isNot(contains('sensitive.csv')));
    },
  );

  test(
    'GivenCsvCellBudgetExceeded_WhenCsvRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'array-to-csv', '--input=[{"a":1},{"a":2}]'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        jsonCsvService: const JsonCsvService(
          converter: JsonCsvConverter(maxCells: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The CSV conversion exceeded its resource limit.\n',
      );
    },
  );

  test('GivenJsonObject_WhenYamlRuns_ThenYamlIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['json', 'to-yaml', '--input={"name":"Ada","active":true}'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'name: Ada\nactive: true');
  });

  test(
    'GivenJsonStandardInput_WhenYamlRunsWithOptions_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'to-yaml',
          '--indent=4',
          '--quote-strings',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        readStandardInput: () async => '{"outer":{"name":"Ada"}}',
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'yaml': 'outer:\n    name: "Ada"',
        'indent': 4,
        'quoteStrings': true,
      });
    },
  );

  test(
    'GivenInputAndOutputFiles_WhenYamlRuns_ThenExactBytesAreSaved',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-cli-yaml-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = File(
        '${directory.path}${Platform.pathSeparator}value.json',
      );
      final output = File(
        '${directory.path}${Platform.pathSeparator}value.yaml',
      );
      await input.writeAsString('{"name":"Ada"}');

      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'json',
          'to-yaml',
          '--file=${input.path}',
          '--output=${output.path}',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), 'YAML saved.\n');
      expect(await output.readAsBytes(), utf8.encode('name: Ada'));
    },
  );

  test(
    'GivenInvalidYamlIndent_WhenYamlRuns_ThenValidationExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'to-yaml', '--input={}', '--indent=3', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      expect(
        jsonDecode(err.toString()),
        containsPair('error', containsPair('code', 'json-yaml.invalid-indent')),
      );
    },
  );

  test(
    'GivenMalformedJson_WhenYamlRuns_ThenOffsetFailureRedactsInput',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'to-yaml', '--input={"secret":}', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(failure['error'], containsPair('code', 'json-yaml.invalid-json'));
      expect(failure['error'], containsPair('location', contains('offset')));
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenOutputWriteFailure_WhenYamlRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'to-yaml',
          '--input={"secret":"value"}',
          '--output=sensitive.yaml',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (path, bytes) async =>
            throw const FileSystemException('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o arquivo YAML.\n');
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenYamlNodeBudgetExceeded_WhenYamlRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'to-yaml', '--input=[1,2]'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        jsonYamlService: const JsonYamlService(
          converter: JsonYamlConverter(maxNodes: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The YAML conversion exceeded its resource limit.\n',
      );
    },
  );

  test('GivenJsonObject_WhenFormatRuns_ThenIndentedJsonIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['json', 'format', '--input={"name":"Ada"}'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), '{\n  "name": "Ada"\n}');
  });

  test(
    'GivenJsonStandardInput_WhenFormatRunsWithOptions_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'format', '--indent=4', '--json'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        readStandardInput: () async => '{"outer":{"value":1}}',
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'formatted': '{\n    "outer": {\n        "value": 1\n    }\n}',
        'indent': 4,
      });
    },
  );

  test(
    'GivenInputAndOutputFiles_WhenFormatRuns_ThenExactBytesAreSaved',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-cli-json-format-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = File(
        '${directory.path}${Platform.pathSeparator}source.json',
      );
      final output = File(
        '${directory.path}${Platform.pathSeparator}formatted.json',
      );
      await input.writeAsString('{"name":"Ada"}');

      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'json',
          'format',
          '--file=${input.path}',
          '--output=${output.path}',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), 'Formatted JSON saved.\n');
      expect(await output.readAsBytes(), utf8.encode('{\n  "name": "Ada"\n}'));
    },
  );

  test(
    'GivenInvalidFormatIndent_WhenFormatRuns_ThenValidationExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'format', '--input={}', '--indent=3', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      expect(
        jsonDecode(err.toString()),
        containsPair(
          'error',
          containsPair('code', 'json-format.invalid-indent'),
        ),
      );
    },
  );

  test(
    'GivenMalformedJson_WhenFormatRuns_ThenReasonAndOffsetRedactInput',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'format', '--input={"secret":}', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(
        failure['error'],
        containsPair('code', 'json-format.invalid-json'),
      );
      expect(failure['error'], containsPair('location', contains('offset')));
      expect(failure['error'], containsPair('location', contains('reason')));
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenOutputWriteFailure_WhenFormatRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'json',
          'format',
          '--input={"secret":"value"}',
          '--output=sensitive.json',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (path, bytes) async =>
            throw const FileSystemException('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        'Não foi possível salvar o arquivo JSON formatado.\n',
      );
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenFormatOutputBudgetExceeded_WhenFormatRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['json', 'format', '--input={"a":1}'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        jsonFormatService: const JsonFormatService(
          formatter: JsonFormatter(maxOutputChars: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The JSON formatting exceeded its resource limit.\n',
      );
    },
  );

  test('GivenInvalidUtf8StandardInput_WhenFormatRuns_ThenInputAccessExitIsReturned', () async {
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>['json', 'format', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      readStandardInput: () async => throw const FormatException('bad utf8'),
    );

    expect(exitCode, 74);
    expect(
      jsonDecode(err.toString()),
      containsPair('error', containsPair('code', 'json-format.input-access')),
    );
  });

  test(
    'GivenInvalidUtf8File_WhenFormatRuns_ThenFileAccessExitIsReturned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-cli-invalid-utf8-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = File(
        '${directory.path}${Platform.pathSeparator}invalid.json',
      );
      await input.writeAsBytes(const <int>[0xff]);
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['json', 'format', '--file=${input.path}', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 74);
      expect(
        jsonDecode(err.toString()),
        containsPair('error', containsPair('code', 'json-format.file-access')),
      );
    },
  );
}
