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
}
