import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GivenEnglishLocale_WhenAppStarts_ThenEnglishShellIsAccessible', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
    await tester.pumpAndSettle();

    expect(find.text('Developer toolbox'), findsOneWidget);
    expect(find.byType(Focus), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      ),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets(
    'GivenBrazilianPortugueseLocale_WhenAppStarts_ThenPortugueseShellIsVisible',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'pt-BR'));
      await tester.pumpAndSettle();

      expect(
        find.text('Caixa de ferramentas para desenvolvedores'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenNarrowViewportAndLargeText_WhenShellRenders_ThenContentDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ChimeraApp(localeTag: 'pt-BR'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Caixa de ferramentas para desenvolvedores'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenCronForm_WhenValidValuesAreSubmitted_ThenLocalizedOccurrencesAreVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          currentTime: () => DateTime.utc(2026, 1, 5, 12),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-cron')));
      await tester.pumpAndSettle();
      expect(find.text('Parse cron expression'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('cron-expression')),
        '0 9 * * MON-FRI',
      );
      await tester.enterText(find.byKey(const Key('cron-time-zone')), 'UTC');
      await tester.enterText(find.byKey(const Key('cron-count')), '1');
      await tester.enterText(
        find.byKey(const Key('cron-reference')),
        '2026-01-05T12:00:00Z',
      );
      await tester.tap(find.byKey(const Key('cron-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Cron schedule: 0 9 * * 1-5'), findsOneWidget);
      expect(
        find.textContaining('Previous: 2026-01-05T09:00:00.000+00:00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Next: 2026-01-06T09:00:00.000+00:00'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenLocalCronFile_WhenSelected_ThenExpressionFieldUsesItsContent',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/cron/parse',
          cronFilePicker: () async => '0 8 * * MON-FRI',
          currentTime: () => DateTime.utc(2026, 1, 5, 12),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cron-file')));
      await tester.pumpAndSettle();

      final expressionField = tester.widget<TextField>(
        find.byKey(const Key('cron-expression')),
      );
      expect(expressionField.controller!.text, '0 8 * * MON-FRI');
    },
  );

  testWidgets(
    'GivenUnreadableLocalCronFile_WhenSelected_ThenLocalizedFailureIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/cron/parse',
          cronFilePicker: () async => throw const FormatException('invalid'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cron-file')));
      await tester.pumpAndSettle();

      expect(find.text('The input file could not be read.'), findsOneWidget);
      expect(find.textContaining('invalid'), findsNothing);
    },
  );

  testWidgets(
    'GivenInvalidCronForm_WhenSubmittedInPortuguese_ThenLocalizedFailureIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          currentTime: () => DateTime.utc(2026, 1, 5, 12),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-cron')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cron-expression')),
        'entrada secreta inválida',
      );
      await tester.tap(find.byKey(const Key('cron-submit')));
      await tester.pumpAndSettle();

      expect(find.text('A solicitação cron é inválida.'), findsOneWidget);
      expect(find.text('entrada secreta inválida'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenCronResourceFailure_WhenSubmitted_ThenResourceMessageIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          cronService: const CronService(
            evaluator: CronEvaluator(maxSearchDays: 1),
          ),
          currentTime: () => DateTime.utc(2026, 1, 2),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-cron')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cron-expression')),
        '0 0 1 12 *',
      );
      await tester.enterText(
        find.byKey(const Key('cron-reference')),
        '2026-01-02T00:00:00Z',
      );
      await tester.enterText(find.byKey(const Key('cron-count')), '1');
      await tester.tap(find.byKey(const Key('cron-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The cron calculation exceeded its resource limit.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenNarrowCronViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/cron/parse',
          currentTime: () => DateTime.utc(2026, 1, 5, 12),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parse cron expression'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenDateForm_WhenValidValuesAreSubmitted_ThenConvertedValueIsVisible',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-date')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Convert date'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('date-value')),
        '2026-01-15T12:30:45Z',
      );
      await tester.enterText(
        find.byKey(const Key('date-target-time-zone')),
        'America/Sao_Paulo',
      );
      await tester.tap(find.byKey(const Key('date-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Converted value: 2026-01-15T09:30:45.000-03:00'),
        findsOneWidget,
      );
      expect(
        find.text('UTC instant: 2026-01-15T12:30:45.000Z'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenLocalDateFile_WhenSelected_ThenValueFieldUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/date/convert',
        dateFilePicker: () async => '2026-01-15T12:30:45Z',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('date-file')));
    await tester.pumpAndSettle();

    final valueField = tester.widget<TextField>(
      find.byKey(const Key('date-value')),
    );
    expect(valueField.controller!.text, '2026-01-15T12:30:45Z');
  });

  testWidgets(
    'GivenInvalidDateForm_WhenSubmittedInPortuguese_ThenLocalizedFailureIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/date/convert'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('date-value')),
        'segredo inválido',
      );
      await tester.tap(find.byKey(const Key('date-submit')));
      await tester.pumpAndSettle();

      expect(find.text('A solicitação de data é inválida.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenDateOutsideTargetCalendarRange_WhenSubmitted_ThenRangeFailureIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/date/convert'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('date-value')),
        '9999-12-31T23:59:59.999Z',
      );
      await tester.enterText(
        find.byKey(const Key('date-target-time-zone')),
        'Pacific/Kiritimati',
      );
      await tester.tap(find.byKey(const Key('date-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The date is outside the supported range.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('date-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowDateViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/date/convert'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Convert date'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenJsonArrayForm_WhenSubmitted_ThenNestedValuesAppearInTable',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-json-table')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('json-table-input')),
        '[{"name":"Ada","meta":{"x":1}},{"name":"Lin"}]',
      );
      await tester.tap(find.byKey(const Key('json-table-row-numbers')));
      await tester.tap(find.byKey(const Key('json-table-submit')));
      await tester.pumpAndSettle();

      expect(find.text('name'), findsOneWidget);
      expect(find.text('meta'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('{"x":1}'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets('GivenLocalJsonFile_WhenSelected_ThenInputUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/array-to-table',
        jsonTableFilePicker: () async => '[{"name":"Ada"}]',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('json-table-file')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('json-table-input')),
    );
    expect(input.controller!.text, '[{"name":"Ada"}]');
  });

  testWidgets(
    'GivenInvalidJsonMember_WhenSubmittedInPortuguese_ThenPathIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/json/array-to-table',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-table-input')),
        '[false]',
      );
      await tester.tap(find.byKey(const Key('json-table-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('O array JSON é inválido.'), findsOneWidget);
      expect(find.textContaining(r'$[0]'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenJsonTableResourceFailure_WhenSubmitted_ThenNoPartialTableAppears',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-table',
          jsonTableService: const JsonTableService(
            converter: JsonTableConverter(maxCells: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-table-input')),
        '[{"a":1},{"a":2}]',
      );
      await tester.tap(find.byKey(const Key('json-table-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The table exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-table-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowJsonTableViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-table',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Convert JSON array to table'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenOnlyEmptyObjects_WhenSubmitted_ThenZeroColumnCountIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-table',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('json-table-input')), '[{}]');
      await tester.tap(find.byKey(const Key('json-table-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The array contains no columns. Row count: 1'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenGuiCellBudgetExceeded_WhenSubmitted_ThenResourceFailureIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-table',
        ),
      );
      await tester.pumpAndSettle();
      final source = '[${List<String>.filled(10001, '{"a":1}').join(',')}]';

      await tester.enterText(find.byKey(const Key('json-table-input')), source);
      await tester.tap(find.byKey(const Key('json-table-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The table exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-table-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenJsonValue_WhenYamlSubmitted_ThenAccessiblePreviewIsVisible',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-json-yaml')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('json-yaml-input')),
        '{"name":"Ada","active":true}',
      );
      await tester.tap(find.byKey(const Key('json-yaml-submit')));
      await tester.pumpAndSettle();

      expect(find.text('name: Ada\nactive: true'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('json-yaml-result-semantics')),
      );
      expect(semantics.properties.value, 'name: Ada\nactive: true');
      expect(find.byKey(const Key('json-yaml-save')), findsOneWidget);
    },
  );

  testWidgets('GivenYamlOptions_WhenChanged_ThenIndentAndQuotesAreApplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/to-yaml'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-yaml-input')),
      '{"outer":{"name":"Ada"}}',
    );
    await tester.tap(find.byKey(const Key('json-yaml-indent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 spaces').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('json-yaml-quote-strings')));
    await tester.tap(find.byKey(const Key('json-yaml-submit')));
    await tester.pumpAndSettle();

    expect(find.text('outer:\n    name: "Ada"'), findsOneWidget);
  });

  testWidgets('GivenLocalJsonFile_WhenYamlSelected_ThenInputUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/to-yaml',
        jsonYamlFilePicker: () async => '{"name":"Ada"}',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('json-yaml-file')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('json-yaml-input')),
    );
    expect(input.controller!.text, '{"name":"Ada"}');
  });

  testWidgets('GivenYamlResult_WhenSaved_ThenExactBytesReachLocalAdapter', (
    tester,
  ) async {
    String? savedName;
    List<int>? savedBytes;
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/to-yaml',
        jsonYamlFileSaver: (name, bytes) async {
          savedName = name;
          savedBytes = bytes;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-yaml-input')),
      '{"name":"Ada"}',
    );
    await tester.tap(find.byKey(const Key('json-yaml-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('json-yaml-save')));
    await tester.pumpAndSettle();

    expect(savedName, 'chimera.yaml');
    expect(utf8.decode(savedBytes!), 'name: Ada');
    expect(find.text('YAML saved.'), findsOneWidget);
  });

  testWidgets(
    'GivenYamlSaveFailure_WhenSavedInPortuguese_ThenAccessErrorIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/json/to-yaml',
          jsonYamlFileSaver: (name, bytes) async => throw StateError('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('json-yaml-input')), '{}');
      await tester.tap(find.byKey(const Key('json-yaml-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('json-yaml-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível salvar o arquivo YAML.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenInvalidJson_WhenYamlSubmitted_ThenLocationIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/to-yaml'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-yaml-input')),
      '{"secret":}',
    );
    await tester.tap(find.byKey(const Key('json-yaml-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Location:'), findsOneWidget);
    final error = tester.widget<Text>(find.byKey(const Key('json-yaml-error')));
    expect(error.data, isNot(contains('secret')));
  });

  testWidgets(
    'GivenYamlResourceFailure_WhenSubmitted_ThenNoPartialResultAppears',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/to-yaml',
          jsonYamlService: JsonYamlService(
            converter: JsonYamlConverter(maxNodes: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('json-yaml-input')), '[1,2]');
      await tester.tap(find.byKey(const Key('json-yaml-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The YAML conversion exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-yaml-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowYamlViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChimeraApp(localeTag: 'en', initialLocation: '/json/to-yaml'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('json-yaml-input')), findsOneWidget);
    },
  );

  testWidgets('GivenJsonArray_WhenCsvSubmitted_ThenQuotedPreviewIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-json-csv')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('json-csv-input')),
      '[{"name":"Ada, A.","meta":{"x":1}}]',
    );
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();

    expect(find.text('name,meta\r\n"Ada, A.","{""x"":1}"'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('json-csv-result-semantics')),
    );
    expect(semantics.properties.value, 'name,meta\r\n"Ada, A.","{""x"":1}"');
    expect(find.byKey(const Key('json-csv-save')), findsOneWidget);
  });

  testWidgets('GivenCsvOptions_WhenChanged_ThenDelimiterAndHeadersAreApplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/array-to-csv'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-csv-input')),
      '[{"name":"Ada","active":true}]',
    );
    await tester.tap(find.byKey(const Key('json-csv-delimiter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semicolon').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('json-csv-headers')));
    await tester.tap(find.byKey(const Key('json-csv-headers')));
    await tester.ensureVisible(find.byKey(const Key('json-csv-submit')));
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ada;true'), findsOneWidget);
  });

  testWidgets('GivenLocalJsonFile_WhenCsvSelected_ThenInputUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/array-to-csv',
        jsonCsvFilePicker: () async => '[{"name":"Ada"}]',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('json-csv-file')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('json-csv-input')),
    );
    expect(input.controller!.text, '[{"name":"Ada"}]');
  });

  testWidgets('GivenCsvResult_WhenSaved_ThenExactBytesReachLocalAdapter', (
    tester,
  ) async {
    String? savedName;
    List<int>? savedBytes;
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/array-to-csv',
        jsonCsvFileSaver: (name, bytes) async {
          savedName = name;
          savedBytes = bytes;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-csv-input')),
      '[{"name":"Ada"}]',
    );
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('json-csv-save')));
    await tester.pumpAndSettle();

    expect(savedName, 'chimera.csv');
    expect(savedBytes, <int>[110, 97, 109, 101, 13, 10, 65, 100, 97]);
    expect(find.text('CSV saved.'), findsOneWidget);
  });

  testWidgets(
    'GivenCsvSaveFailure_WhenSavedInPortuguese_ThenAccessErrorIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/json/array-to-csv',
          jsonCsvFileSaver: (name, bytes) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-csv-input')),
        '[{"name":"Ada"}]',
      );
      await tester.tap(find.byKey(const Key('json-csv-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('json-csv-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível salvar o arquivo CSV.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('GivenInvalidJson_WhenCsvSubmitted_ThenLocationIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/array-to-csv'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('json-csv-input')), '[false]');
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The JSON or CSV options are invalid.'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$[0]'), findsOneWidget);
    expect(find.byKey(const Key('json-csv-result')), findsNothing);
  });

  testWidgets(
    'GivenCsvResourceFailure_WhenSubmitted_ThenNoPartialResultAppears',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-csv',
          jsonCsvService: const JsonCsvService(
            converter: JsonCsvConverter(maxCells: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-csv-input')),
        '[{"a":1},{"a":2}]',
      );
      await tester.tap(find.byKey(const Key('json-csv-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The CSV conversion exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-csv-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowCsvViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/array-to-csv',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Convert JSON array to CSV'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
