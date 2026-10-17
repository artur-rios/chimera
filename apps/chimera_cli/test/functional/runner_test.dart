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

  test('GivenXmlInput_WhenXmlFormatRuns_ThenIndentedXmlIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['xml', 'format', '--input=<root><name>Ada</name></root>'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), '<root>\n  <name>Ada</name>\n</root>');
  });

  test(
    'GivenXmlStandardInput_WhenJsonModeRuns_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>['xml', 'format', '--indent=4', '--json'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        readStandardInput: () async => '<root><child/></root>',
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'formatted': '<root>\n    <child/>\n</root>',
        'indent': 4,
      });
    },
  );

  test('GivenXmlFiles_WhenXmlFormatRuns_ThenExactBytesAreSaved', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-xml-format-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}source.xml');
    final output = File(
      '${directory.path}${Platform.pathSeparator}formatted.xml',
    );
    await input.writeAsString('<root><name>Ada</name></root>');

    final out = StringBuffer();
    final exitCode = await runChimera(
      <String>[
        'xml',
        'format',
        '--file=${input.path}',
        '--output=${output.path}',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Formatted XML saved.\n');
    expect(
      await output.readAsBytes(),
      utf8.encode('<root>\n  <name>Ada</name>\n</root>'),
    );
  });

  test(
    'GivenXmlBudgetExceeded_WhenXmlFormatRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['xml', 'format', '--input=<root/>'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        xmlFormatService: const XmlFormatService(
          formatter: XmlFormatter(maxOutputChars: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The XML formatting exceeded its resource limit.\n',
      );
    },
  );

  test('GivenMalformedXml_WhenXmlFormatRuns_ThenLocationIsRedacted', () async {
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'xml',
        'format',
        '--input=<root><secret></root>',
        '--json',
      ],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
    );

    expect(exitCode, 64);
    final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
    expect(failure['error'], containsPair('code', 'xml-format.invalid-xml'));
    expect(failure['error'], containsPair('location', contains('line')));
    expect(err.toString(), isNot(contains('secret')));
  });

  test(
    'GivenXmlOutputFailure_WhenXmlFormatRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'xml',
          'format',
          '--input=<root/>',
          '--output=formatted.xml',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (path, bytes) async =>
            throw const FileSystemException('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('arquivo XML formatado'));
    },
  );

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

  test('GivenSqlArguments_WhenFormatRuns_ThenFormattedSqlIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'sql',
        'format',
        '--input=select id,name from users where active=true',
        '--dialect=postgresql',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(
      out.toString(),
      'SELECT\n  id,\n  name\nFROM users\nWHERE active = TRUE',
    );
  });

  test('GivenSqlStdinAndJson_WhenFormatRuns_ThenStableJsonIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'sql',
        'format',
        '--dialect=mysql',
        '--indent=4',
        '--keyword-case=lower',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
      readStandardInput: () async => 'SELECT `user`,? FROM accounts',
    );

    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), <String, Object?>{
      'formatted': 'select\n    `user`,\n    ?\nfrom accounts',
      'dialect': 'mysql',
      'indent': 4,
      'keywordCase': 'lower',
    });
  });

  test('GivenSqlFiles_WhenFormatRuns_ThenExactBytesAreSaved', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-sql-format-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}source.sql');
    final output = File(
      '${directory.path}${Platform.pathSeparator}formatted.sql',
    );
    await input.writeAsString(
      'select top 1 [user],@id from accounts where id=@id;',
    );

    final out = StringBuffer();
    final exitCode = await runChimera(
      <String>[
        'sql',
        'format',
        '--file=${input.path}',
        '--output=${output.path}',
        '--dialect=sqlserver',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Formatted SQL saved.\n');
    expect(
      utf8.decode(await output.readAsBytes()),
      'SELECT\n  TOP 1 [user],\n  @id\nFROM accounts\nWHERE id = @id;',
    );
  });

  test(
    'GivenInvalidSqlDialect_WhenFormatRuns_ThenValidationExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'sql',
          'format',
          '--input=select 1',
          '--dialect=oracle',
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
          containsPair('code', 'sql-format.invalid-dialect'),
        ),
      );
    },
  );

  test('GivenMalformedSql_WhenFormatRuns_ThenLocationRedactsInput', () async {
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>['sql', 'format', "--input=select 'secret", '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
    );

    expect(exitCode, 64);
    final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
    expect(failure['error'], containsPair('code', 'sql-format.invalid-sql'));
    expect(failure['error'], containsPair('location', contains('offset')));
    expect(failure['error'], containsPair('location', contains('reason')));
    expect(err.toString(), isNot(contains('secret')));
  });

  test(
    'GivenSqlOutputFailure_WhenFormatRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'sql',
          'format',
          '--input=select secret from sample',
          '--output=sensitive.sql',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (path, bytes) async => throw Exception('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(
        err.toString(),
        'Não foi possível salvar o arquivo SQL formatado.\n',
      );
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenSqlTokenBudgetExceeded_WhenFormatRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['sql', 'format', '--input=select value from sample'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        sqlFormatService: const SqlFormatService(
          formatter: SqlFormatter(maxTokens: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The SQL formatting exceeded its resource limit.\n',
      );
    },
  );

  test(
    'GivenDirectNumber_WhenBaseConversionRuns_ThenLocalizedResultIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'number',
          'convert-base',
          '--input=255',
          '--from=10',
          '--to=16',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(out.toString(), 'Converted value: ff\n');
      expect(err.toString(), isEmpty);
    },
  );

  test(
    'GivenArbitraryPrecisionNumber_WhenJsonModeRuns_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'number',
          'convert-base',
          '--input=184467440737095516160',
          '--from=10',
          '--to=16',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'converted': 'a0000000000000000',
        'sourceBase': 10,
        'targetBase': 16,
      });
    },
  );

  test('GivenStandardInput_WhenBaseConversionRunsInPortuguese_ThenLocalizedResultIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['number', 'convert-base', '--from=36', '--to=10'],
      localeTag: 'pt-BR',
      out: out,
      err: StringBuffer(),
      readStandardInput: () async => 'zz\n',
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Valor convertido: 1295\n');
  });

  test(
    'GivenNumberFiles_WhenBaseConversionRuns_ThenExactBytesAreSaved',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-cli-number-base-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = File('${directory.path}${Platform.pathSeparator}value.txt');
      final output = File(
        '${directory.path}${Platform.pathSeparator}converted.txt',
      );
      await input.writeAsString('-11111111\n');
      final out = StringBuffer();

      final exitCode = await runChimera(
        <String>[
          'number',
          'convert-base',
          '--file=${input.path}',
          '--output=${output.path}',
          '--from=2',
          '--to=16',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(out.toString(), 'Converted value saved.\n');
      expect(await output.readAsBytes(), utf8.encode('-ff'));
    },
  );

  test(
    'GivenInvalidNumber_WhenJsonModeRuns_ThenSafeValidationFailureIsWritten',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'number',
          'convert-base',
          '--input=secret-Z',
          '--from=10',
          '--to=2',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
      );

      expect(exitCode, 64);
      final failure = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(
        failure['error'],
        containsPair('code', 'number-base.invalid-value'),
      );
      expect(
        failure['error'],
        containsPair('location', containsPair('reason', 'invalid-digit')),
      );
      expect(err.toString(), isNot(contains('secret')));
    },
  );

  test(
    'GivenInvalidBaseOptions_WhenConversionRuns_ThenPrecedenceIsStable',
    () async {
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['number', 'convert-base', '--input=1', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
        );
        expect(exitCode, 64);
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await failureFor(const <String>['--to=10']),
        containsPair('location', containsPair('reason', 'missing-base')),
      );
      expect(
        await failureFor(const <String>['--from=x', '--to=10']),
        containsPair('location', containsPair('reason', 'not-an-integer')),
      );
      expect(
        await failureFor(const <String>['--from=1', '--to=37']),
        containsPair(
          'location',
          allOf(
            containsPair('field', 'sourceBase'),
            containsPair('reason', 'out-of-range-base'),
          ),
        ),
      );
      expect(
        await failureFor(const <String>['--from=10', '--to=37']),
        containsPair(
          'location',
          allOf(
            containsPair('field', 'targetBase'),
            containsPair('reason', 'out-of-range-base'),
          ),
        ),
      );
    },
  );

  test('GivenConflictingNumberInputs_WhenConversionRuns_ThenValidationExitIsReturned', () async {
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'number',
        'convert-base',
        '--input=1',
        '--file=value.txt',
        '--from=10',
        '--to=2',
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
        containsPair('code', 'number-base.conflicting-inputs'),
      ),
    );
  });

  test(
    'GivenNumberResourceLimit_WhenConversionRuns_ThenResourceExitIsReturned',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'number',
          'convert-base',
          '--input=zz',
          '--from=36',
          '--to=2',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        numberBaseService: const NumberBaseService(
          converter: NumberBaseConverter(maxOutputCharacters: 3),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'The number conversion exceeded its resource limit.\n',
      );
    },
  );

  test('GivenNumberInputAccessFailures_WhenConversionRuns_ThenAccessCodesAreStable', () async {
    Future<Map<String, dynamic>> failureFor({required bool file}) async {
      final err = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'number',
          'convert-base',
          if (file) '--file=value.txt',
          '--from=10',
          '--to=2',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        readStandardInput: () async => throw Exception('denied'),
        readFile: (_) async => throw Exception('denied'),
      );
      expect(exitCode, 74);
      return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
          as Map<String, dynamic>;
    }

    expect(
      await failureFor(file: false),
      containsPair('code', 'number-base.input-access'),
    );
    expect(
      await failureFor(file: true),
      containsPair('code', 'number-base.file-access'),
    );
  });

  test(
    'GivenNumberOutputFailure_WhenConversionRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'number',
          'convert-base',
          '--input=255',
          '--from=10',
          '--to=16',
          '--output=converted.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (_, _) async => throw Exception('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o valor convertido.\n');
    },
  );

  test(
    'GivenEveryEscapeMode_WhenJsonCommandRuns_ThenStableOutputIsWritten',
    () async {
      final cases = <String, (String, String)>{
        'json': ('"', r'\"'),
        'unicode': ('A', r'\u0041'),
        'c': ("'", r"\'"),
        'html': ('&', '&amp;'),
        'url': (' ', '%20'),
      };

      for (final entry in cases.entries) {
        final out = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'escape',
            '--mode=${entry.key}',
            '--input=${entry.value.$1}',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
        );

        expect(exitCode, 0, reason: entry.key);
        expect(jsonDecode(out.toString()), <String, Object?>{
          'escaped': entry.value.$2,
          'mode': entry.key,
        }, reason: entry.key);
      }
    },
  );

  test('GivenStandardInput_WhenTextEscapeRunsInPortuguese_ThenLocalizedResultIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['text', 'escape', '--mode=url'],
      localeTag: 'pt-BR',
      out: out,
      err: StringBuffer(),
      readStandardInput: () async => 'A B',
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Texto escapado: A%20B\n');
  });

  test('GivenTextFiles_WhenEscapeRuns_ThenExactUtf8BytesAreSaved', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-text-escape-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}input.txt');
    final output = File(
      '${directory.path}${Platform.pathSeparator}escaped.txt',
    );
    await input.writeAsString('&é');
    final out = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'text',
        'escape',
        '--mode=html',
        '--file=${input.path}',
        '--output=${output.path}',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Escaped text saved.\n');
    expect(await output.readAsBytes(), utf8.encode('&amp;é'));
  });

  test(
    'GivenInvalidEscapeInputs_WhenCommandRuns_ThenSafeValidationFailuresReturn',
    () async {
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['text', 'escape', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
        );
        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('sensitive-text')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await failureFor(const <String>[
          '--input=sensitive-text',
          '--mode=bad',
        ]),
        allOf(
          containsPair('code', 'text-escape.invalid-mode'),
          containsPair(
            'location',
            allOf(
              containsPair('field', 'mode'),
              containsPair('reason', 'unsupported-mode'),
            ),
          ),
        ),
      );
      expect(
        await failureFor(const <String>[
          '--input=sensitive-text',
          '--file=input.txt',
          '--mode=json',
        ]),
        containsPair('code', 'text-escape.conflicting-inputs'),
      );
    },
  );

  test(
    'GivenTextEscapeResourceLimit_WhenCommandRuns_ThenResourceExitReturns',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['text', 'escape', '--mode=html', '--input=&'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        textEscapeService: const TextEscapeService(
          escaper: TextEscaper(maxOutputCharacters: 4),
        ),
      );

      expect(exitCode, 75);
      expect(err.toString(), 'Text escaping exceeded its resource limit.\n');
    },
  );

  test(
    'GivenTextEscapeAccessFailures_WhenCommandRuns_ThenNoSuccessIsWritten',
    () async {
      Future<Map<String, dynamic>> inputFailure({required bool file}) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'escape',
            '--mode=json',
            if (file) '--file=input.txt',
            '--json',
          ],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInput: () async => throw Exception('denied'),
          readFile: (_) async => throw Exception('denied'),
        );
        expect(exitCode, 74);
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await inputFailure(file: false),
        containsPair('code', 'text-escape.input-access'),
      );
      expect(
        await inputFailure(file: true),
        containsPair('code', 'text-escape.file-access'),
      );

      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        const <String>[
          'text',
          'escape',
          '--mode=html',
          '--input=&',
          '--output=escaped.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (_, _) async => throw Exception('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o texto escapado.\n');
    },
  );

  test(
    'GivenEveryUnescapeMode_WhenJsonCommandRuns_ThenStableOutputIsWritten',
    () async {
      final cases = <String, (String, String)>{
        'json': (r'\"', '"'),
        'unicode': (r'\u0041', 'A'),
        'c': (r'\101', 'A'),
        'html': ('&amp;', '&'),
        'url': ('%20', ' '),
      };

      for (final entry in cases.entries) {
        final out = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'unescape',
            '--mode=${entry.key}',
            '--input=${entry.value.$1}',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
        );

        expect(exitCode, 0, reason: entry.key);
        expect(jsonDecode(out.toString()), <String, Object?>{
          'unescaped': entry.value.$2,
          'mode': entry.key,
        }, reason: entry.key);
      }
    },
  );

  test('GivenStandardInput_WhenTextUnescapeRunsInPortuguese_ThenLocalizedResultIsWritten', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['text', 'unescape', '--mode=url'],
      localeTag: 'pt-BR',
      out: out,
      err: StringBuffer(),
      readStandardInput: () async => 'A%20B',
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Texto não escapado: A B\n');
  });

  test('GivenTextFiles_WhenUnescapeRuns_ThenExactUtf8BytesAreSaved', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-cli-text-unescape-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}input.txt');
    final output = File(
      '${directory.path}${Platform.pathSeparator}unescaped.txt',
    );
    await input.writeAsString('&amp;é');
    final out = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'text',
        'unescape',
        '--mode=html',
        '--file=${input.path}',
        '--output=${output.path}',
      ],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );

    expect(exitCode, 0);
    expect(out.toString(), 'Unescaped text saved.\n');
    expect(await output.readAsBytes(), utf8.encode('&é'));

    await input.writeAsString(r'\uD800');
    final invalidOutput = File(
      '${directory.path}${Platform.pathSeparator}invalid-unescaped.txt',
    );
    final invalidErr = StringBuffer();
    final invalidExitCode = await runChimera(
      <String>[
        'text',
        'unescape',
        '--mode=json',
        '--file=${input.path}',
        '--output=${invalidOutput.path}',
        '--json',
      ],
      localeTag: 'en',
      out: StringBuffer(),
      err: invalidErr,
    );

    expect(invalidExitCode, 64);
    expect(invalidOutput.existsSync(), isFalse);
    final invalidError =
        (jsonDecode(invalidErr.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
    expect(
      invalidError['location'],
      allOf(
        containsPair('reason', 'surrogate-scalar'),
        containsPair('offset', 0),
      ),
    );
  });

  test(
    'GivenInvalidUnescapeInputs_WhenCommandRuns_ThenSafeFailuresReturn',
    () async {
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['text', 'unescape', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
        );
        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('sensitive')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await failureFor(const <String>[r'--input=sensitive\q', '--mode=json']),
        allOf(
          containsPair('code', 'text-unescape.malformed-input'),
          containsPair(
            'location',
            allOf(
              containsPair('field', 'input'),
              containsPair('reason', 'unknown-escape'),
              containsPair('offset', 9),
            ),
          ),
        ),
      );
      expect(
        await failureFor(const <String>[
          '--input=sensitive',
          '--file=input.txt',
          '--mode=json',
        ]),
        containsPair('code', 'text-unescape.conflicting-inputs'),
      );
    },
  );

  test(
    'GivenTextUnescapeResourceLimit_WhenCommandRuns_ThenResourceExitReturns',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['text', 'unescape', '--mode=html', '--input=&amp;'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        textUnescapeService: const TextUnescapeService(
          unescaper: TextUnescaper(maxOutputCharacters: 0),
        ),
      );

      expect(exitCode, 75);
      expect(err.toString(), 'Text unescaping exceeded its resource limit.\n');
    },
  );

  test(
    'GivenTextUnescapeAccessFailures_WhenCommandRuns_ThenNoSuccessIsWritten',
    () async {
      Future<Map<String, dynamic>> inputFailure({required bool file}) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'unescape',
            '--mode=json',
            if (file) '--file=input.txt',
            '--json',
          ],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInput: () async => throw Exception('denied'),
          readFile: (_) async => throw Exception('denied'),
        );
        expect(exitCode, 74);
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await inputFailure(file: false),
        containsPair('code', 'text-unescape.input-access'),
      );
      expect(
        await inputFailure(file: true),
        containsPair('code', 'text-unescape.file-access'),
      );

      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        const <String>[
          'text',
          'unescape',
          '--mode=html',
          '--input=&amp;',
          '--output=unescaped.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (_, _) async => throw Exception('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o texto não escapado.\n');
    },
  );

  test(
    'GivenLiteralListsAndOptions_WhenListCompareRuns_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'list',
          'compare',
          '--left= Alpha \nalpha\nleft',
          '--right=ALPHA\nright',
          '--case=insensitive',
          '--whitespace=trim',
          '--duplicates=distinct',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0, reason: err.toString());
      expect(jsonDecode(out.toString()), <String, Object?>{
        'leftOnly': ['left'],
        'rightOnly': ['right'],
        'intersection': [' Alpha '],
        'equal': false,
        'options': <String, Object?>{
          'case': 'insensitive',
          'whitespace': 'trim',
          'duplicates': 'distinct',
        },
      });
    },
  );

  test(
    'GivenFileAndStandardInputSources_WhenListCompareRuns_ThenBothAreLoaded',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'list',
          'compare',
          '--left-file=left.txt',
          '--right-stdin',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
        readFile: (path) async => path == 'left.txt' ? 'um\ndois' : 'wrong',
        readStandardInput: () async => 'dois\ntrês',
      );

      expect(exitCode, 0);
      expect(
        out.toString(),
        'Somente à esquerda:\num\n'
        'Somente à direita:\ntrês\n'
        'Interseção:\ndois\n'
        'Iguais: não\n',
      );
    },
  );

  test(
    'GivenOutputPath_WhenListCompareRuns_ThenExactSelectedPayloadIsSaved',
    () async {
      List<int>? saved;
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'list',
          'compare',
          '--left=a\nb',
          '--right=a\nc',
          '--json',
          '--output=result.json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputFile: (_, bytes) async => saved = bytes,
      );

      expect(exitCode, 0, reason: err.toString());
      expect(out.toString(), 'List comparison saved.\n');
      expect(
        jsonDecode(utf8.decode(saved!)),
        containsPair('intersection', ['a']),
      );
      expect(utf8.decode(saved!), isNot(endsWith('\n')));
    },
  );

  test(
    'GivenOutputWriteFailure_WhenListCompareRuns_ThenAccessExitHasNoSuccess',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'list',
          'compare',
          '--left=secret',
          '--right=public',
          '--output=result.txt',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputFile: (_, _) async => throw Exception('denied'),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('secret')));
      expect(
        (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'list-compare.output-access'),
      );
    },
  );

  test(
    'GivenInvalidListSources_WhenCompareRuns_ThenSafeValidationReturns',
    () async {
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['list', 'compare', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
        );
        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('sensitive')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await failureFor(const [
          '--left=sensitive',
          '--right=right',
          '--left-stdin',
        ]),
        containsPair('code', 'list-compare.conflicting-left-sources'),
      );
      expect(
        await failureFor(const ['--left=left']),
        containsPair('code', 'list-compare.missing-right-source'),
      );
      expect(
        await failureFor(const ['--left-stdin', '--right-stdin']),
        containsPair('code', 'list-compare.shared-stdin'),
      );
      expect(
        await failureFor(const ['--left=left', '--right=right', '--case=fold']),
        containsPair('code', 'list-compare.invalid-option'),
      );
    },
  );

  test(
    'GivenListCompareAccessAndResourceFailures_WhenRun_ThenTypedExitsReturn',
    () async {
      final accessErr = StringBuffer();
      final accessExit = await runChimera(
        const <String>[
          'list',
          'compare',
          '--left-file=secret.txt',
          '--right=right',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: accessErr,
        readFile: (_) async => throw Exception('secret-file-detail'),
      );
      expect(accessExit, 74);
      expect(accessErr.toString(), isNot(contains('secret')));
      expect(
        (jsonDecode(accessErr.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'list-compare.left-file-access'),
      );

      final resourceErr = StringBuffer();
      final resourceExit = await runChimera(
        const <String>['list', 'compare', '--left=a\nb', '--right='],
        localeTag: 'en',
        out: StringBuffer(),
        err: resourceErr,
        listCompareService: const ListCompareService(
          comparator: ListComparator(maxResultItems: 1),
        ),
      );
      expect(resourceExit, 75);
      expect(
        resourceErr.toString(),
        'List comparison exceeded its resource limit.\n',
      );
    },
  );

  test(
    'GivenLiteralText_WhenTextAnalyzeRuns_ThenStableJsonIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['text', 'analyze', '--input=Hi there', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(jsonDecode(out.toString()), <String, dynamic>{
        'characters': 8,
        'words': 2,
        'lines': 1,
        'bytes': 8,
      });
    },
  );

  test('GivenStandardInput_WhenTextAnalyzeRunsInPortuguese_ThenLocalizedCountsReturn', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['text', 'analyze'],
      localeTag: 'pt-BR',
      out: out,
      err: StringBuffer(),
      readStandardInput: () async => 'A\nB',
    );

    expect(exitCode, 0);
    expect(
      out.toString(),
      'Caracteres: 3\nPalavras: 2\nLinhas: 2\nBytes UTF-8: 3\n',
    );
  });

  test('GivenFileInput_WhenTextAnalyzeRuns_ThenLocalFileIsRead', () async {
    final out = StringBuffer();

    final exitCode = await runChimera(
      const <String>['text', 'analyze', '--file=input.txt', '--json'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
      readFile: (path) async {
        expect(path, 'input.txt');
        return 'Olá';
      },
    );

    expect(exitCode, 0);
    expect(jsonDecode(out.toString()), containsPair('bytes', 4));
  });

  test(
    'GivenOutputPath_WhenTextAnalyzeRuns_ThenExactSelectedPayloadIsSaved',
    () async {
      final out = StringBuffer();
      late String savedPath;
      late List<int> savedBytes;

      final exitCode = await runChimera(
        const <String>[
          'text',
          'analyze',
          '--input=one two',
          '--json',
          '--output=counts.json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        writeOutputFile: (path, bytes) async {
          savedPath = path;
          savedBytes = bytes;
        },
      );

      expect(exitCode, 0);
      expect(savedPath, 'counts.json');
      expect(jsonDecode(utf8.decode(savedBytes)), containsPair('words', 2));
      expect(out.toString(), 'Text analysis saved.\n');
    },
  );

  test(
    'GivenTextAnalyzeFailures_WhenRun_ThenTypedRedactedExitsReturn',
    () async {
      final validationErr = StringBuffer();
      final validationExit = await runChimera(
        const <String>[
          'text',
          'analyze',
          '--input=sensitive-input',
          '--file=sensitive-file',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: validationErr,
      );
      expect(validationExit, 64);
      expect(validationErr.toString(), isNot(contains('sensitive')));
      expect(
        (jsonDecode(validationErr.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'text-analyze.conflicting-inputs'),
      );

      final accessErr = StringBuffer();
      final accessExit = await runChimera(
        const <String>['text', 'analyze', '--file=sensitive-file', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: accessErr,
        readFile: (_) async => throw Exception('sensitive-detail'),
      );
      expect(accessExit, 74);
      expect(accessErr.toString(), isNot(contains('sensitive')));
      expect(
        (jsonDecode(accessErr.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'text-analyze.file-access'),
      );

      final outputErr = StringBuffer();
      final outputExit = await runChimera(
        const <String>[
          'text',
          'analyze',
          '--input=value',
          '--output=counts.txt',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: outputErr,
        writeOutputFile: (_, _) async => throw Exception('write-detail'),
      );
      expect(outputExit, 74);
      expect(
        (jsonDecode(outputErr.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'text-analyze.output-access'),
      );

      final resourceErr = StringBuffer();
      final resourceExit = await runChimera(
        const <String>['text', 'analyze', '--input=abc'],
        localeTag: 'en',
        out: StringBuffer(),
        err: resourceErr,
        textAnalyzeService: const TextAnalyzeService(
          analyzer: TextAnalyzer(maxInputCodeUnits: 2),
        ),
      );
      expect(resourceExit, 75);
      expect(
        resourceErr.toString(),
        'Text analysis exceeded its resource limit.\n',
      );
    },
  );

  test(
    'GivenEveryTransformMode_WhenJsonCommandRuns_ThenStableOutputIsWritten',
    () async {
      final cases = <String, (String, String)>{
        'lowercase': ('ÉCOLE', 'école'),
        'uppercase': ('straße', 'STRASSE'),
        'normalize-whitespace': ('  one\t two\n', 'one two'),
        'sort-lines': ('b\r\na\n', 'a\nb\n'),
        'deduplicate-lines': ('b\r\na\nb\n', 'b\na\n'),
      };

      for (final entry in cases.entries) {
        final out = StringBuffer();
        final err = StringBuffer();

        final exitCode = await runChimera(
          <String>[
            'text',
            'transform',
            '--mode=${entry.key}',
            '--input=${entry.value.$1}',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
        );

        expect(exitCode, 0, reason: entry.key);
        expect(err.toString(), isEmpty, reason: entry.key);
        expect(jsonDecode(out.toString()), <String, Object?>{
          'mode': entry.key,
          'output': entry.value.$2,
        }, reason: entry.key);
      }
    },
  );

  test(
    'GivenStandardInput_WhenTextTransformRuns_ThenExactHumanTextIsWritten',
    () async {
      final out = StringBuffer();

      final exitCode = await runChimera(
        const <String>['text', 'transform', '--mode=uppercase'],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
        readStandardInput: () async => 'olá',
      );

      expect(exitCode, 0);
      expect(out.toString(), 'OLÁ');
    },
  );

  test(
    'GivenFileAndOutput_WhenTextTransformRuns_ThenExactPayloadIsSaved',
    () async {
      final out = StringBuffer();
      late String readPath;
      late String savedPath;
      late List<int> savedBytes;

      final exitCode = await runChimera(
        const <String>[
          'text',
          'transform',
          '--mode=normalize-whitespace',
          '--file=input.txt',
          '--output=result.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
        readFile: (path) async {
          readPath = path;
          return '  um\t dois\n';
        },
        writeOutputFile: (path, bytes) async {
          savedPath = path;
          savedBytes = bytes;
        },
      );

      expect(exitCode, 0);
      expect(readPath, 'input.txt');
      expect(savedPath, 'result.txt');
      expect(utf8.decode(savedBytes), 'um dois');
      expect(out.toString(), 'Texto transformado salvo.\n');
    },
  );

  test(
    'GivenJsonOutputFile_WhenTextTransformRuns_ThenSelectedJsonIsSaved',
    () async {
      final out = StringBuffer();
      late List<int> savedBytes;

      final exitCode = await runChimera(
        const <String>[
          'text',
          'transform',
          '--mode=lowercase',
          '--input=ABC',
          '--json',
          '--output=result.json',
        ],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        writeOutputFile: (_, bytes) async => savedBytes = bytes,
      );

      expect(exitCode, 0);
      expect(jsonDecode(utf8.decode(savedBytes)), <String, Object?>{
        'mode': 'lowercase',
        'output': 'abc',
      });
      expect(out.toString(), 'Transformed text saved.\n');
    },
  );

  test(
    'GivenInvalidTransformInputs_WhenRun_ThenTypedRedactedFailuresReturn',
    () async {
      var sourceReads = 0;
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['text', 'transform', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInput: () async {
            sourceReads++;
            return 'sensitive-standard-input';
          },
          readFile: (_) async {
            sourceReads++;
            return 'sensitive-file-input';
          },
        );
        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('sensitive')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      for (final options in <List<String>>[
        const <String>[],
        const <String>['--file=sensitive-file', '--mode=title-case'],
      ]) {
        expect(
          await failureFor(options),
          allOf(
            containsPair('code', 'text-transform.invalid-mode'),
            containsPair(
              'location',
              allOf(
                containsPair('field', 'mode'),
                containsPair('reason', 'unsupported-mode'),
              ),
            ),
          ),
        );
      }
      expect(sourceReads, 0);

      expect(
        await failureFor(const <String>[
          '--input=sensitive-input',
          '--file=sensitive-file',
          '--mode=lowercase',
        ]),
        containsPair('code', 'text-transform.conflicting-inputs'),
      );
      expect(sourceReads, 0);
    },
  );

  test(
    'GivenTextTransformAccessFailures_WhenRun_ThenNoSuccessIsWritten',
    () async {
      Future<Map<String, dynamic>> inputFailure({required bool file}) async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'transform',
            '--mode=lowercase',
            if (file) '--file=input.txt',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInput: () async => throw Exception('sensitive-detail'),
          readFile: (_) async => throw Exception('sensitive-detail'),
        );
        expect(exitCode, 74);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('sensitive')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await inputFailure(file: false),
        containsPair('code', 'text-transform.input-access'),
      );
      expect(
        await inputFailure(file: true),
        containsPair('code', 'text-transform.file-access'),
      );

      final out = StringBuffer();
      final err = StringBuffer();
      final outputExit = await runChimera(
        const <String>[
          'text',
          'transform',
          '--mode=uppercase',
          '--input=text',
          '--output=result.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        writeOutputFile: (_, _) async => throw Exception('sensitive-detail'),
      );

      expect(outputExit, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'Não foi possível salvar o texto transformado.\n');
    },
  );

  test(
    'GivenTextTransformResourceLimit_WhenRun_ThenResourceExitReturns',
    () async {
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>['text', 'transform', '--mode=uppercase', '--input=ß'],
        localeTag: 'en',
        out: StringBuffer(),
        err: err,
        textTransformService: const TextTransformService(
          transformer: TextTransformer(maxOutputCodeUnits: 1),
        ),
      );

      expect(exitCode, 75);
      expect(
        err.toString(),
        'Text transformation exceeded its resource limit.\n',
      );
    },
  );

  test(
    'GivenEveryTextGranularity_WhenCompareJsonRuns_ThenStableSpansAreWritten',
    () async {
      final cases = <String, (String, String)>{
        'line': ('alpha\nbeta', 'alpha\ngamma'),
        'word': ('Hello world', 'Hello brave world'),
        'character': ('café', 'cafe'),
      };

      for (final entry in cases.entries) {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>[
            'text',
            'compare',
            '--granularity=${entry.key}',
            '--left=${entry.value.$1}',
            '--right=${entry.value.$2}',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
        );

        expect(exitCode, 0, reason: err.toString());
        final output = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(output['granularity'], entry.key);
        expect(output['spans'], isA<List<dynamic>>());
        expect(output['summary'], isA<Map<String, dynamic>>());
      }
    },
  );

  test(
    'GivenFileAndStdinTexts_WhenCompareRuns_ThenLocalizedHumanDiffIsWritten',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        const <String>[
          'text',
          'compare',
          '--granularity=line',
          '--left-file=left.txt',
          '--right-stdin',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        readFile: (path) async => path == 'left.txt' ? 'um\ndois' : 'wrong',
        readStandardInput: () async => 'um\ntrês',
      );

      expect(exitCode, 0, reason: err.toString());
      expect(
        out.toString(),
        'Inalterado: "um\\n"\n'
        'Removido: "dois"\n'
        'Adicionado: "três"\n'
        'Adicionados: 1\n'
        'Removidos: 1\n'
        'Inalterados: 1\n',
      );
    },
  );

  test('GivenUnicodeSeparators_WhenCompareHumanOutputIsWritten_ThenWhitespaceIsEscaped', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'text',
        'compare',
        '--granularity=character',
        '--left=a\u0085\u2028\u2029',
        '--right=a\u0085\u2028\u2029',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0, reason: err.toString());
    expect(
      out.toString(),
      'Unchanged: "a\\u0085\\u2028\\u2029"\n'
      'Added: 0\n'
      'Removed: 0\n'
      'Unchanged: 4\n',
    );
  });

  test(
    'GivenTextCompareOutputPath_WhenRun_ThenExactSelectedJsonIsSaved',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      late List<int> savedBytes;

      final exitCode = await runChimera(
        const <String>[
          'text',
          'compare',
          '--granularity=word',
          '--left=Hello world',
          '--right=Hello brave world',
          '--json',
          '--output=diff.json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputFile: (_, bytes) async => savedBytes = bytes,
      );

      expect(exitCode, 0, reason: err.toString());
      expect(out.toString(), 'Text comparison saved.\n');
      expect(
        jsonDecode(utf8.decode(savedBytes)),
        containsPair('granularity', 'word'),
      );
      expect(utf8.decode(savedBytes), isNot(endsWith('\n')));
    },
  );

  test(
    'GivenInvalidTextCompareInputs_WhenRun_ThenValidationPrecedesSourceReads',
    () async {
      var sourceReads = 0;
      Future<Map<String, dynamic>> failureFor(List<String> options) async {
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['text', 'compare', '--json', ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInput: () async {
            sourceReads++;
            return 'sensitive-stdin';
          },
          readFile: (_) async {
            sourceReads++;
            return 'sensitive-file';
          },
        );
        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('sensitive')));
        return (jsonDecode(err.toString()) as Map<String, dynamic>)['error']
            as Map<String, dynamic>;
      }

      expect(
        await failureFor(const <String>[
          '--left-file=sensitive-left',
          '--right=right',
        ]),
        containsPair('code', 'text-compare.invalid-granularity'),
      );
      expect(
        await failureFor(const <String>[
          '--granularity=sentence',
          '--left-file=sensitive-left',
          '--right=right',
        ]),
        containsPair('code', 'text-compare.invalid-granularity'),
      );
      expect(
        await failureFor(const <String>[
          '--granularity=line',
          '--left=sensitive-left',
          '--left-stdin',
          '--right=right',
        ]),
        containsPair('code', 'text-compare.conflicting-left-sources'),
      );
      expect(
        await failureFor(const <String>['--granularity=line', '--left=left']),
        containsPair('code', 'text-compare.missing-right-source'),
      );
      expect(
        await failureFor(const <String>[
          '--granularity=line',
          '--left-stdin',
          '--right-stdin',
        ]),
        containsPair('code', 'text-compare.shared-stdin'),
      );
      expect(sourceReads, 0);
    },
  );

  test('GivenUnknownTextCompareOption_WhenJsonRequested_ThenTypedValidationReturns', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      const <String>[
        'text',
        'compare',
        '--granularity=line',
        '--left=left',
        '--right=right',
        '--bogus',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(
      (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
      <String, dynamic>{
        'kind': 'validation',
        'code': 'text-compare.invalid-options',
        'message': 'The text comparison sources or granularity are invalid.',
      },
    );
  });

  test(
    'GivenTextCompareAccessAndResourceFailures_WhenRun_ThenTypedExitsReturn',
    () async {
      final accessErr = StringBuffer();
      final accessExit = await runChimera(
        const <String>[
          'text',
          'compare',
          '--granularity=line',
          '--left-file=secret.txt',
          '--right=right',
          '--json',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: accessErr,
        readFile: (_) async => throw Exception('sensitive-detail'),
      );
      expect(accessExit, 74);
      expect(accessErr.toString(), isNot(contains('sensitive')));
      expect(
        (jsonDecode(accessErr.toString()) as Map<String, dynamic>)['error'],
        containsPair('code', 'text-compare.left-file-access'),
      );

      final outputErr = StringBuffer();
      final outputExit = await runChimera(
        const <String>[
          'text',
          'compare',
          '--granularity=line',
          '--left=left',
          '--right=right',
          '--output=diff.txt',
        ],
        localeTag: 'pt-BR',
        out: StringBuffer(),
        err: outputErr,
        writeOutputFile: (_, _) async => throw Exception('sensitive-detail'),
      );
      expect(outputExit, 74);
      expect(
        outputErr.toString(),
        'Não foi possível salvar a comparação de textos.\n',
      );

      final resourceErr = StringBuffer();
      final resourceExit = await runChimera(
        const <String>[
          'text',
          'compare',
          '--granularity=character',
          '--left=a',
          '--right=b',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: resourceErr,
        textCompareService: const TextCompareService(
          comparer: TextComparer(maxWorkUnits: 0),
        ),
      );
      expect(resourceExit, 75);
      expect(
        resourceErr.toString(),
        'Text comparison exceeded its resource limit.\n',
      );
    },
  );

  group('base64 encode', () {
    test(
      'GivenLiteralText_WhenBase64EncodeRuns_ThenLocalizedHumanResultReturns',
      () async {
        for (final testCase in <(String, String)>{
          (
            'en',
            'Base64: T2zDoSDwn5GL\n'
                'Input bytes: 9\n'
                'Output characters: 12\n',
          ),
          (
            'pt-BR',
            'Base64: T2zDoSDwn5GL\n'
                'Bytes de entrada: 9\n'
                'Caracteres de saída: 12\n',
          ),
        }) {
          final out = StringBuffer();
          final err = StringBuffer();

          final exitCode = await runChimera(
            const <String>['base64', 'encode', '--text=Olá 👋'],
            localeTag: testCase.$1,
            out: out,
            err: err,
          );

          expect(exitCode, 0, reason: err.toString());
          expect(out.toString(), testCase.$2);
          expect(err.toString(), isEmpty);
        }
      },
    );

    test(
      'GivenStdinBytes_WhenBase64EncodeJsonRuns_ThenStableJsonReturns',
      () async {
        final out = StringBuffer();

        final exitCode = await runChimera(
          const <String>['base64', 'encode', '--stdin', '--json'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
          readStandardInputBytes: () async => <int>[0xC3, 0xA9],
        );

        expect(exitCode, 0);
        expect(
          out.toString(),
          '{"encoded":"w6k=","inputByteCount":2,"outputCharacterCount":4}\n',
        );
      },
    );

    test(
      'GivenBinaryFile_WhenBase64EncodeRuns_ThenExactBytesAreEncoded',
      () async {
        final out = StringBuffer();
        var requestedPath = '';

        final exitCode = await runChimera(
          const <String>['base64', 'encode', '--file=bytes.bin', '--json'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
          readFileBytes: (path) async {
            requestedPath = path;
            return <int>[0x00, 0xFF];
          },
        );

        expect(exitCode, 0);
        expect(requestedPath, 'bytes.bin');
        expect(jsonDecode(out.toString()), <String, Object?>{
          'encoded': 'AP8=',
          'inputByteCount': 2,
          'outputCharacterCount': 4,
        });
      },
    );

    test(
      'GivenEmptySelectedSources_WhenBase64EncodeRuns_ThenEachSourceIsValid',
      () async {
        final commands = <List<String>>[
          const <String>['base64', 'encode', '--text=', '--json'],
          const <String>['base64', 'encode', '--stdin', '--json'],
          const <String>['base64', 'encode', '--file=empty.bin', '--json'],
        ];

        for (final command in commands) {
          final out = StringBuffer();
          final exitCode = await runChimera(
            command,
            localeTag: 'en',
            out: out,
            err: StringBuffer(),
            readStandardInputBytes: () async => <int>[],
            readFileBytes: (_) async => <int>[],
          );

          expect(exitCode, 0, reason: command.toString());
          expect(jsonDecode(out.toString()), <String, Object?>{
            'encoded': '',
            'inputByteCount': 0,
            'outputCharacterCount': 0,
          });
        }
      },
    );

    test('GivenOutputPath_WhenBase64EncodeRuns_ThenExactSelectedPayloadIsSaved', () async {
      final cases = <(List<String>, String)>[
        (
          const <String>[
            'base64',
            'encode',
            '--text=Hello',
            '--output=result.txt',
          ],
          'SGVsbG8=',
        ),
        (
          const <String>[
            'base64',
            'encode',
            '--text=Hello',
            '--json',
            '--output=result.json',
          ],
          '{"encoded":"SGVsbG8=","inputByteCount":5,"outputCharacterCount":8}',
        ),
      ];

      for (final testCase in cases) {
        final out = StringBuffer();
        late String savedPath;
        late List<int> savedBytes;
        final exitCode = await runChimera(
          testCase.$1,
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
          writeOutputFile: (path, bytes) async {
            savedPath = path;
            savedBytes = bytes;
          },
        );

        expect(exitCode, 0);
        expect(savedPath, testCase.$1.last.split('=').last);
        expect(utf8.decode(savedBytes), testCase.$2);
        expect(utf8.decode(savedBytes), isNot(endsWith('\n')));
        expect(out.toString(), isEmpty);
      }
    });

    test(
      'GivenInvalidSources_WhenBase64EncodeRuns_ThenValidationPrecedesReads',
      () async {
        var reads = 0;
        for (final options in <List<String>>[
          const <String>[],
          const <String>['--text=secret', '--stdin'],
          const <String>['--stdin', '--file=secret.bin'],
        ]) {
          final err = StringBuffer();
          final exitCode = await runChimera(
            <String>['base64', 'encode', '--json', ...options],
            localeTag: 'en',
            out: StringBuffer(),
            err: err,
            readStandardInputBytes: () async {
              reads++;
              return <int>[];
            },
            readFileBytes: (_) async {
              reads++;
              return <int>[];
            },
          );

          expect(exitCode, 64);
          expect(err.toString(), isNot(contains('secret')));
          expect(
            (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
            containsPair(
              'code',
              options.isEmpty
                  ? 'base64-encode.missing-source'
                  : 'base64-encode.conflicting-sources',
            ),
          );
        }
        expect(reads, 0);
      },
    );

    test('GivenMalformedTextOrUtf8_WhenBase64EncodeRuns_ThenRedactedValidationReturns', () async {
      final cases = <(List<String>, Future<List<int>> Function()?)>[
        (
          <String>[
            'base64',
            'encode',
            '--text=${String.fromCharCode(0xD800)}',
            '--json',
          ],
          null,
        ),
        (
          const <String>['base64', 'encode', '--stdin', '--json'],
          () async => <int>[0xC3, 0x28],
        ),
      ];

      for (final testCase in cases) {
        final err = StringBuffer();
        final exitCode = await runChimera(
          testCase.$1,
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInputBytes: testCase.$2,
        );

        expect(exitCode, 64);
        expect(err.toString(), isNot(contains('secret')));
        expect(
          (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
          containsPair('code', 'base64-encode.invalid-text'),
        );
      }
    });

    test('GivenAdapterFailures_WhenBase64EncodeRuns_ThenAccessAndResourceExitsAreTyped', () async {
      final cases =
          <
            ({
              List<String> args,
              Future<List<int>> Function()? stdinReader,
              Future<List<int>> Function(String)? fileReader,
              Future<void> Function(String, List<int>)? writer,
              int exitCode,
              String code,
            })
          >[
            (
              args: const <String>[
                'base64',
                'encode',
                '--file=secret.bin',
                '--json',
              ],
              stdinReader: null,
              fileReader: (_) async => throw Exception('private file detail'),
              writer: null,
              exitCode: 74,
              code: 'base64-encode.file-access',
            ),
            (
              args: const <String>[
                'base64',
                'encode',
                '--file=secret.bin',
                '--json',
              ],
              stdinReader: null,
              fileReader: (_) async => throw OutOfMemoryError(),
              writer: null,
              exitCode: 75,
              code: 'base64-encode.resource-limit',
            ),
            (
              args: const <String>['base64', 'encode', '--stdin', '--json'],
              stdinReader: () async => throw Exception('private stdin detail'),
              fileReader: null,
              writer: null,
              exitCode: 74,
              code: 'base64-encode.input-access',
            ),
            (
              args: const <String>['base64', 'encode', '--stdin', '--json'],
              stdinReader: () async => throw OutOfMemoryError(),
              fileReader: null,
              writer: null,
              exitCode: 75,
              code: 'base64-encode.resource-limit',
            ),
            (
              args: const <String>[
                'base64',
                'encode',
                '--text=value',
                '--output=secret.txt',
                '--json',
              ],
              stdinReader: null,
              fileReader: null,
              writer: (_, _) async => throw Exception('private output detail'),
              exitCode: 74,
              code: 'base64-encode.output-access',
            ),
            (
              args: const <String>[
                'base64',
                'encode',
                '--text=value',
                '--output=result.txt',
                '--json',
              ],
              stdinReader: null,
              fileReader: null,
              writer: (_, _) async => throw OutOfMemoryError(),
              exitCode: 75,
              code: 'base64-encode.resource-limit',
            ),
          ];

      for (final testCase in cases) {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          testCase.args,
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: testCase.stdinReader,
          readFileBytes: testCase.fileReader,
          writeOutputFile: testCase.writer,
        );

        expect(exitCode, testCase.exitCode);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('private')));
        expect(err.toString(), isNot(contains('secret')));
        expect(
          (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
          containsPair('code', testCase.code),
        );
      }
    });

    test('GivenEncoderResourceLimit_WhenBase64EncodeRuns_ThenExit75HasNoPartialOutput', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        const <String>['base64', 'encode', '--text=secret', '--json'],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        base64EncodeService: const Base64EncodeService(
          encoder: Base64ByteEncoder(maxInputBytes: 1),
        ),
      );

      expect(exitCode, 75);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('secret')));
      expect(
        (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
        allOf(
          containsPair('kind', 'resource'),
          containsPair('code', 'base64-encode.resource-limit'),
        ),
      );
    });

    test(
      'GivenUnknownBase64Option_WhenJsonRequested_ThenTypedValidationReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          const <String>[
            'base64',
            'encode',
            '--text=value',
            '--bogus',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
        );

        expect(exitCode, 64);
        expect(out.toString(), isEmpty);
        expect(
          (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
          <String, dynamic>{
            'kind': 'validation',
            'code': 'base64-encode.invalid-options',
            'message': 'The Base64 encoding source is invalid.',
          },
        );
      },
    );

    test('GivenStdoutAllocationFailure_WhenEitherFormatRuns_ThenNoPartialOutputReturns', () async {
      for (final json in <bool>[false, true]) {
        final out = _OutOfMemoryStringSink();
        final err = StringBuffer();

        final exitCode = await runChimera(
          <String>['base64', 'encode', '--text=secret', if (json) '--json'],
          localeTag: 'en',
          out: out,
          err: err,
        );

        expect(exitCode, 75, reason: 'json=$json');
        expect(out.emissionCalls, 1, reason: 'json=$json');
        expect(out.contents, isEmpty, reason: 'json=$json');
        expect(err.toString(), isNot(contains('secret')), reason: 'json=$json');
        if (json) {
          expect(
            (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
            allOf(
              containsPair('kind', 'resource'),
              containsPair('code', 'base64-encode.resource-limit'),
            ),
          );
        } else {
          expect(
            err.toString(),
            'Base64 encoding exceeded its resource limit.\n',
          );
        }
      }
    });
  });

  group('base64 decode', () {
    test(
      'GivenLiteralBase64InTextMode_WhenDecoded_ThenExactTextHasNoAddedNewline',
      () async {
        for (final input in <(String, String)>[
          ('', ''),
          ('SGVsbG8=', 'Hello'),
          ('T2zDoSDwn5GL', 'Olá 👋'),
          ('SGVsbG8Kd29ybGQ=', 'Hello\nworld'),
        ]) {
          final out = StringBuffer();
          final err = StringBuffer();

          final exitCode = await runChimera(
            <String>['base64', 'decode', '--text=${input.$1}', '--mode=text'],
            localeTag: 'en',
            out: out,
            err: err,
          );

          expect(exitCode, 0, reason: input.$1);
          expect(out.toString(), input.$2, reason: input.$1);
          expect(err.toString(), isEmpty, reason: input.$1);
        }
      },
    );

    test(
      'GivenEverySource_WhenDecoded_ThenRawUtf8BytesReachTheSharedService',
      () async {
        final cases =
            <
              (
                List<String>,
                Future<List<int>> Function()?,
                Future<List<int>> Function(String)?,
              )
            >[
              (const <String>['--text=SGVsbG8=', '--mode=text'], null, null),
              (
                const <String>['--stdin', '--mode=text'],
                () async => utf8.encode('SGVsbG8='),
                null,
              ),
              (
                const <String>['--file=secret-input.txt', '--mode=text'],
                null,
                (path) async {
                  expect(path, 'secret-input.txt');
                  return utf8.encode('SGVsbG8=');
                },
              ),
            ];

        for (final testCase in cases) {
          final out = StringBuffer();
          final exitCode = await runChimera(
            <String>['base64', 'decode', ...testCase.$1],
            localeTag: 'en',
            out: out,
            err: StringBuffer(),
            readStandardInputBytes: testCase.$2,
            readFileBytes: testCase.$3,
          );

          expect(exitCode, 0, reason: testCase.$1.toString());
          expect(out.toString(), 'Hello', reason: testCase.$1.toString());
        }
      },
    );

    test(
      'GivenTextOrBinaryModeWithJson_WhenDecoded_ThenStableJsonHasOneNewline',
      () async {
        final cases = <(List<String>, String)>[
          (
            const <String>['--text=SGVsbG8=', '--mode=text', '--json'],
            '{"mode":"text","text":"Hello","bytes":null,'
                '"inputCharacterCount":8,"outputByteCount":5,'
                '"imageCandidateMediaType":null}\n',
          ),
          (
            const <String>['--stdin', '--mode=binary', '--json'],
            '{"mode":"binary","text":null,"bytes":[0,255],'
                '"inputCharacterCount":4,"outputByteCount":2,'
                '"imageCandidateMediaType":null}\n',
          ),
        ];

        for (final testCase in cases) {
          final out = StringBuffer();
          final exitCode = await runChimera(
            <String>['base64', 'decode', ...testCase.$1],
            localeTag: 'en',
            out: out,
            err: StringBuffer(),
            readStandardInputBytes: () async => utf8.encode('AP8='),
          );

          expect(exitCode, 0, reason: testCase.$1.toString());
          expect(out.toString(), testCase.$2, reason: testCase.$1.toString());
        }
      },
    );

    test(
      'GivenOutputPath_WhenDecoded_ThenExactBytesAreSavedBeforeSuccessOutput',
      () async {
        for (final testCase in <(String, String)>[
          ('en', 'Decoded bytes saved.\n'),
          ('pt-BR', 'Bytes decodificados salvos.\n'),
        ]) {
          final out = StringBuffer();
          late String savedPath;
          late List<int> savedBytes;
          final exitCode = await runChimera(
            const <String>[
              'base64',
              'decode',
              '--text=AP8=',
              '--mode=binary',
              '--output=decoded.bin',
            ],
            localeTag: testCase.$1,
            out: out,
            err: StringBuffer(),
            writeOutputFile: (path, bytes) async {
              expect(out.toString(), isEmpty);
              savedPath = path;
              savedBytes = bytes;
            },
          );

          expect(exitCode, 0);
          expect(savedPath, 'decoded.bin');
          expect(savedBytes, <int>[0, 255]);
          expect(out.toString(), testCase.$2);
        }
      },
    );

    test(
      'GivenJsonAndOutputPath_WhenDecoded_ThenRawBytesAreSavedBeforeJsonStdout',
      () async {
        final out = StringBuffer();
        late List<int> savedBytes;
        final exitCode = await runChimera(
          const <String>[
            'base64',
            'decode',
            '--text=SGVsbG8=',
            '--mode=text',
            '--output=decoded.txt',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
          writeOutputFile: (_, bytes) async {
            expect(out.toString(), isEmpty);
            savedBytes = bytes;
          },
        );

        expect(exitCode, 0);
        expect(savedBytes, utf8.encode('Hello'));
        expect(out.toString(), startsWith('{"mode":"text"'));
        expect(out.toString(), endsWith('}\n'));
      },
    );

    test(
      'GivenInvalidStructure_WhenDecodeRuns_ThenValidationPrecedesEveryRead',
      () async {
        var reads = 0;
        final cases = <(List<String>, String)>[
          (
            const <String>['--mode=text', '--json'],
            'base64-decode.missing-source',
          ),
          (
            const <String>['--text=', '--stdin', '--mode=text', '--json'],
            'base64-decode.conflicting-sources',
          ),
          (
            const <String>['--stdin', '--file=secret', '--mode=text', '--json'],
            'base64-decode.conflicting-sources',
          ),
          (const <String>['--stdin', '--json'], 'base64-decode.invalid-mode'),
          (
            const <String>['--stdin', '--mode=words', '--json'],
            'base64-decode.invalid-mode',
          ),
          (
            const <String>['--stdin', '--mode=binary'],
            'base64-decode.binary-destination-required',
          ),
        ];

        for (final testCase in cases) {
          final out = StringBuffer();
          final err = StringBuffer();
          final exitCode = await runChimera(
            <String>['base64', 'decode', ...testCase.$1],
            localeTag: 'en',
            out: out,
            err: err,
            readStandardInputBytes: () async {
              reads++;
              return <int>[];
            },
            readFileBytes: (_) async {
              reads++;
              return <int>[];
            },
          );

          expect(exitCode, 64, reason: testCase.$1.toString());
          expect(out.toString(), isEmpty);
          expect(err.toString(), isNot(contains('secret')));
          if (testCase.$1.contains('--json')) {
            expect(
              (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
              containsPair('code', testCase.$2),
            );
          } else {
            expect(err.toString(), 'The Base64 decoding request is invalid.\n');
          }
        }
        expect(reads, 0);
      },
    );

    test(
      'GivenUnknownDecodeOption_WhenParsed_ThenTypedValidationPrecedesReads',
      () async {
        var reads = 0;
        final err = StringBuffer();
        final exitCode = await runChimera(
          const <String>[
            'base64',
            'decode',
            '--stdin',
            '--mode=text',
            '--private=secret',
            '--json',
          ],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
          readStandardInputBytes: () async {
            reads++;
            return <int>[];
          },
        );

        expect(exitCode, 64);
        expect(reads, 0);
        expect(err.toString(), isNot(contains('secret')));
        expect(jsonDecode(err.toString()), <String, Object?>{
          'error': <String, Object?>{
            'kind': 'validation',
            'code': 'base64-decode.invalid-options',
            'message': 'The Base64 decoding request is invalid.',
          },
        });
      },
    );

    test(
      'GivenMalformedBase64OrUtf8_WhenDecoded_ThenValidationIsRedacted',
      () async {
        final cases = <(List<String>, Future<List<int>> Function()?, String)>[
          (
            const <String>['--text=c2VjcmV0!', '--mode=text', '--json'],
            null,
            'base64-decode.invalid-input',
          ),
          (
            const <String>['--text=/w==', '--mode=text', '--json'],
            null,
            'base64-decode.invalid-text',
          ),
          (
            const <String>['--stdin', '--mode=text', '--json'],
            () async => <int>[0xC3, 0x28],
            'base64-decode.invalid-input',
          ),
        ];

        for (final testCase in cases) {
          final out = StringBuffer();
          final err = StringBuffer();
          final exitCode = await runChimera(
            <String>['base64', 'decode', ...testCase.$1],
            localeTag: 'en',
            out: out,
            err: err,
            readStandardInputBytes: testCase.$2,
          );

          expect(exitCode, 64);
          expect(out.toString(), isEmpty);
          expect(err.toString(), isNot(contains('secret')));
          expect(
            (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
            containsPair('code', testCase.$3),
          );
        }
      },
    );

    test('GivenAdapterFailures_WhenDecoded_ThenTypedExitHasNoPartialOutputOrDetail', () async {
      final cases =
          <
            ({
              List<String> args,
              BytesReader? stdinReader,
              FileBytesReader? fileReader,
              FileBytesWriter? writer,
              int exitCode,
              String code,
            })
          >[
            (
              args: const <String>['--stdin', '--mode=text', '--json'],
              stdinReader: () async => throw Exception('private stdin detail'),
              fileReader: null,
              writer: null,
              exitCode: 74,
              code: 'base64-decode.input-access',
            ),
            (
              args: const <String>['--file=secret', '--mode=text', '--json'],
              stdinReader: null,
              fileReader: (_) async => throw Exception('private file detail'),
              writer: null,
              exitCode: 74,
              code: 'base64-decode.file-access',
            ),
            (
              args: const <String>['--stdin', '--mode=text', '--json'],
              stdinReader: () async => throw OutOfMemoryError(),
              fileReader: null,
              writer: null,
              exitCode: 75,
              code: 'base64-decode.resource-limit',
            ),
            (
              args: const <String>[
                '--text=SGVsbG8=',
                '--mode=text',
                '--output=secret',
                '--json',
              ],
              stdinReader: null,
              fileReader: null,
              writer: (_, _) async => throw Exception('private write detail'),
              exitCode: 74,
              code: 'base64-decode.output-access',
            ),
            (
              args: const <String>[
                '--text=SGVsbG8=',
                '--mode=text',
                '--output=secret',
                '--json',
              ],
              stdinReader: null,
              fileReader: null,
              writer: (_, _) async => throw OutOfMemoryError(),
              exitCode: 75,
              code: 'base64-decode.resource-limit',
            ),
          ];

      for (final testCase in cases) {
        final out = StringBuffer();
        final err = StringBuffer();
        final exitCode = await runChimera(
          <String>['base64', 'decode', ...testCase.args],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: testCase.stdinReader,
          readFileBytes: testCase.fileReader,
          writeOutputFile: testCase.writer,
        );

        expect(exitCode, testCase.exitCode);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('private')));
        expect(err.toString(), isNot(contains('secret')));
        expect(
          (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
          containsPair('code', testCase.code),
        );
      }
    });

    test('GivenDecodeOrJsonAllocationFailure_WhenDecoded_ThenExit75HasNoPartialOutput', () async {
      final serviceOut = StringBuffer();
      final serviceErr = StringBuffer();
      final serviceExit = await runChimera(
        const <String>[
          'base64',
          'decode',
          '--text=SGVsbG8=',
          '--mode=text',
          '--json',
        ],
        localeTag: 'pt-BR',
        out: serviceOut,
        err: serviceErr,
        base64DecodeService: const Base64DecodeService(
          decoder: Base64ByteDecoder(maxOutputBytes: 1),
        ),
      );
      expect(serviceExit, 75);
      expect(serviceOut.toString(), isEmpty);
      expect(serviceErr.toString(), isNot(contains('SGVsbG8=')));

      final jsonOut = StringBuffer();
      final jsonErr = StringBuffer();
      final jsonExit = await runChimera(
        const <String>[
          'base64',
          'decode',
          '--text=SGVsbG8=',
          '--mode=text',
          '--json',
        ],
        localeTag: 'en',
        out: jsonOut,
        err: jsonErr,
        base64DecodeJsonEncoder: (_) => throw OutOfMemoryError(),
      );
      expect(jsonExit, 75);
      expect(jsonOut.toString(), isEmpty);
      expect(
        (jsonDecode(jsonErr.toString()) as Map<String, dynamic>)['error'],
        allOf(
          containsPair('kind', 'resource'),
          containsPair('code', 'base64-decode.resource-limit'),
        ),
      );
    });

    test(
      'GivenStdoutAllocationFailure_WhenDecodeEmits_ThenNoPartialOutputReturns',
      () async {
        for (final json in <bool>[false, true]) {
          final out = _OutOfMemoryStringSink();
          final err = StringBuffer();
          final exitCode = await runChimera(
            <String>[
              'base64',
              'decode',
              '--text=SGVsbG8=',
              '--mode=text',
              if (json) '--json',
            ],
            localeTag: 'en',
            out: out,
            err: err,
          );

          expect(exitCode, 75, reason: 'json=$json');
          expect(out.emissionCalls, 1);
          expect(out.contents, isEmpty);
          if (json) {
            expect(
              (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
              containsPair('code', 'base64-decode.resource-limit'),
            );
          } else {
            expect(
              err.toString(),
              'Base64 decoding exceeded its resource limit.\n',
            );
          }
        }
      },
    );

    test('GivenPartialStageFailure_WhenDecoded_ThenStageIsRemovedAndPriorTargetUnchanged', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-decode-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      await target.writeAsBytes(<int>[7, 8, 9], flush: true);
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputStage: (path, bytes) async {
          await File(path).writeAsBytes(<int>[bytes.first], flush: true);
          throw const FileSystemException('private partial failure');
        },
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The decoded bytes could not be saved.\n');
      expect(await target.readAsBytes(), <int>[7, 8, 9]);
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });

    test('GivenExistingTarget_WhenTransactionalSaveSucceeds_ThenExactBytesReplaceItWithoutArtifacts', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-replace-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      await target.writeAsBytes(<int>[7, 8, 9], flush: true);

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      );

      expect(exitCode, 0);
      expect(await target.readAsBytes(), <int>[0, 255]);
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });

    test('GivenStageAndBackupNameCollisions_WhenSaved_ThenUnrelatedFilesArePreservedAndNewNamesAreUsed', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-collision-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      await target.writeAsBytes(<int>[7, 8, 9], flush: true);
      final collisions = <File>[];
      final attempts = <String, int>{'stage': 0, 'backup': 0};

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
        outputFileOperations: TransactionalFileOperations(
          tryReserve: (candidate) async {
            final role = candidate.path.contains('.chimera-stage-')
                ? 'stage'
                : 'backup';
            final attempt = attempts[role]!;
            attempts[role] = attempt + 1;
            if (attempt == 0) {
              await candidate.writeAsBytes(
                role == 'stage' ? <int>[11] : <int>[22],
                flush: true,
              );
              collisions.add(candidate);
              return false;
            }
            await candidate.create(exclusive: true);
            return true;
          },
        ),
      );

      expect(exitCode, 0);
      expect(attempts, <String, int>{'stage': 2, 'backup': 2});
      expect(await target.readAsBytes(), <int>[0, 255]);
      expect(await collisions[0].readAsBytes(), <int>[11]);
      expect(await collisions[1].readAsBytes(), <int>[22]);
      expect(
        (await _chimeraTransactionArtifacts(directory))
            .map((file) => file.path)
            .toSet(),
        collisions.map((file) => file.path).toSet(),
      );
      for (final collision in collisions) {
        await collision.delete();
      }
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });

    test('GivenStageReplacementFailure_WhenSaved_ThenOriginalTargetIsRestoredWithoutArtifacts', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-rename-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      await target.writeAsBytes(<int>[7, 8, 9], flush: true);
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        outputFileOperations: TransactionalFileOperations(
          rename: (source, destinationPath) async {
            if (source.path.contains('.chimera-stage-') &&
                destinationPath == target.path) {
              throw const FileSystemException('private rename failure');
            }
            await source.rename(destinationPath);
          },
        ),
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The decoded bytes could not be saved.\n');
      expect(await target.readAsBytes(), <int>[7, 8, 9]);
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });

    test('GivenBackupCleanupFailure_WhenSaved_ThenInstalledTargetIsRolledBackAndFailureReturns', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-cleanup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      await target.writeAsBytes(<int>[7, 8, 9], flush: true);
      final out = StringBuffer();
      final err = StringBuffer();
      var cleanupFailures = 0;

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        outputFileOperations: TransactionalFileOperations(
          delete: (file) async {
            if (file.path.contains('.chimera-backup-') &&
                cleanupFailures == 0) {
              cleanupFailures++;
              throw const FileSystemException('private cleanup failure');
            }
            await file.delete();
          },
        ),
      );

      expect(exitCode, 74);
      expect(cleanupFailures, 1);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The decoded bytes could not be saved.\n');
      expect(await target.readAsBytes(), <int>[7, 8, 9]);
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });

    test('GivenNoExistingTargetAndPartialStageFailure_WhenSaved_ThenNoTargetOrArtifactsRemain', () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-base64-new-target-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}decoded.bin',
      );
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>[
          'base64',
          'decode',
          '--text=AP8=',
          '--mode=binary',
          '--output=${target.path}',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputStage: (path, bytes) async {
          await File(path).writeAsBytes(<int>[bytes.first], flush: true);
          throw const FileSystemException('private partial failure');
        },
      );

      expect(exitCode, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The decoded bytes could not be saved.\n');
      expect(await target.exists(), isFalse);
      expect(await _chimeraTransactionArtifacts(directory), isEmpty);
    });
  });
}

Future<List<File>> _chimeraTransactionArtifacts(Directory directory) async =>
    directory
        .list()
        .where((entry) {
          final name = entry.path.split(Platform.pathSeparator).last;
          return name.startsWith('.chimera-');
        })
        .map((entry) => File(entry.path))
        .toList();

final class _OutOfMemoryStringSink implements StringSink {
  var emissionCalls = 0;
  final StringBuffer _contents = StringBuffer();

  String get contents => _contents.toString();

  Never _fail() {
    emissionCalls++;
    throw OutOfMemoryError();
  }

  @override
  void write(Object? object) => _fail();

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();

  @override
  void writeCharCode(int charCode) => _fail();

  @override
  void writeln([Object? object = '']) => _fail();
}
