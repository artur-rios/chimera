import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsRole;

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

  testWidgets('GivenJsonValue_WhenFormatSubmitted_ThenPreviewIsAccessible', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-json-format')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"name":"Ada","meta":{"x":1}}',
    );
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();

    const formatted = '{\n  "name": "Ada",\n  "meta": {\n    "x": 1\n  }\n}';
    expect(find.text(formatted), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('json-format-result-semantics')),
    );
    expect(semantics.properties.value, formatted);
    expect(find.byKey(const Key('json-format-copy')), findsOneWidget);
    expect(find.byKey(const Key('json-format-save')), findsOneWidget);
  });

  testWidgets('GivenFourSpaceOption_WhenFormatted_ThenIndentIsApplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"outer":{"value":1}}',
    );
    await tester.tap(find.byKey(const Key('json-format-indent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 spaces').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('\n        "value": 1'), findsOneWidget);
  });

  testWidgets('GivenLocalJsonFile_WhenFormatSelected_ThenInputUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/format',
        jsonFormatFilePicker: () async => '{"name":"Ada"}',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('json-format-file')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('json-format-input')),
    );
    expect(input.controller!.text, '{"name":"Ada"}');
  });

  testWidgets('GivenClipboardJson_WhenPasted_ThenInputUsesItsContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/format',
        jsonFormatClipboardReader: () async => '{"pasted":true}',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('json-format-paste')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('json-format-input')),
    );
    expect(input.controller!.text, '{"pasted":true}');
  });

  testWidgets('GivenFormatResult_WhenCopiedAndSaved_ThenAdaptersReceiveIt', (
    tester,
  ) async {
    String? copied;
    String? savedName;
    List<int>? savedBytes;
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/format',
        jsonFormatClipboardWriter: (value) async => copied = value,
        jsonFormatFileSaver: (name, bytes) async {
          savedName = name;
          savedBytes = bytes;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"name":"Ada"}',
    );
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('json-format-copy')));
    await tester.tap(find.byKey(const Key('json-format-copy')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('json-format-save')));
    await tester.tap(find.byKey(const Key('json-format-save')));
    await tester.pumpAndSettle();

    const formatted = '{\n  "name": "Ada"\n}';
    expect(copied, formatted);
    expect(savedName, 'chimera-formatted.json');
    expect(savedBytes, utf8.encode(formatted));
    expect(find.text('Formatted JSON saved.'), findsOneWidget);
  });

  testWidgets(
    'GivenClipboardFailures_WhenReadOrWriteRuns_ThenLocalizedErrorIsVisible',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/json/format',
          jsonFormatClipboardReader: () async => throw Exception('denied'),
          jsonFormatClipboardWriter: (value) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('json-format-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível ler a área de transferência.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('json-format-input')),
        '{"value":1}',
      );
      await tester.tap(find.byKey(const Key('json-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('json-format-copy')));
      await tester.tap(find.byKey(const Key('json-format-copy')));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível escrever na área de transferência.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenSaveFailure_WhenFormattedResultIsSaved_ThenResultIsRemoved',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/format',
          jsonFormatFileSaver: (name, bytes) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-format-input')),
        '{"value":1}',
      );
      await tester.tap(find.byKey(const Key('json-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('json-format-save')));
      await tester.tap(find.byKey(const Key('json-format-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('The formatted JSON file could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-format-result')), findsNothing);
    },
  );

  testWidgets('GivenInvalidJson_WhenFormatSubmitted_ThenReasonIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"secret":}',
    );
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Location:'), findsOneWidget);
    expect(find.textContaining('Reason: Unexpected character'), findsOneWidget);
    final error = tester.widget<Text>(
      find.byKey(const Key('json-format-error')),
    );
    expect(error.data, isNot(contains('secret')));
  });

  testWidgets(
    'GivenFormatResourceFailure_WhenSubmitted_ThenNoPartialResultAppears',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/json/format',
          jsonFormatService: JsonFormatService(
            formatter: JsonFormatter(maxOutputChars: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('json-format-input')),
        '{"a":1}',
      );
      await tester.tap(find.byKey(const Key('json-format-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The JSON formatting exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('json-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowFormatViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChimeraApp(localeTag: 'en', initialLocation: '/json/format'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('json-format-input')), findsOneWidget);
    },
  );

  testWidgets('GivenSql_WhenFormatSubmitted_ThenPreviewIsAccessible', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-sql-format')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'select id,name from users where active=true',
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();

    const formatted = 'SELECT\n  id,\n  name\nFROM users\nWHERE active = TRUE';
    expect(find.text(formatted), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('sql-format-result-semantics')),
    );
    expect(semantics.properties.value, formatted);
    expect(find.byKey(const Key('sql-format-copy')), findsOneWidget);
    expect(find.byKey(const Key('sql-format-save')), findsOneWidget);
  });

  testWidgets('GivenSqlOptions_WhenChanged_ThenDialectAndStyleApply', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/sql/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'SELECT [user],@id FROM accounts WHERE id=@id',
    );
    await tester.tap(find.byKey(const Key('sql-format-dialect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SQL Server').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sql-format-indent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 spaces').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sql-format-keyword-case')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lowercase').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('\n    [user],'), findsOneWidget);
    expect(find.textContaining('\nfrom accounts'), findsOneWidget);
  });

  testWidgets('GivenSqlFileAndClipboard_WhenLoaded_ThenInputUsesContent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/sql/format',
        sqlFormatFilePicker: () async => 'select file_value from sample',
        sqlFormatClipboardReader: () async =>
            'select clipboard_value from sample',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sql-format-file')));
    await tester.pumpAndSettle();
    var input = tester.widget<TextField>(
      find.byKey(const Key('sql-format-input')),
    );
    expect(input.controller!.text, 'select file_value from sample');

    await tester.tap(find.byKey(const Key('sql-format-paste')));
    await tester.pumpAndSettle();
    input = tester.widget<TextField>(find.byKey(const Key('sql-format-input')));
    expect(input.controller!.text, 'select clipboard_value from sample');
  });

  testWidgets('GivenSqlResult_WhenCopiedAndSaved_ThenAdaptersReceiveIt', (
    tester,
  ) async {
    String? copied;
    String? savedName;
    List<int>? savedBytes;
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/sql/format',
        sqlFormatClipboardWriter: (value) async => copied = value,
        sqlFormatFileSaver: (name, bytes) async {
          savedName = name;
          savedBytes = bytes;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'select name from users',
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sql-format-copy')));
    await tester.tap(find.byKey(const Key('sql-format-copy')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sql-format-save')));
    await tester.tap(find.byKey(const Key('sql-format-save')));
    await tester.pumpAndSettle();

    const formatted = 'SELECT\n  name\nFROM users';
    expect(copied, formatted);
    expect(savedName, 'chimera-formatted.sql');
    expect(savedBytes, utf8.encode(formatted));
    expect(find.text('Formatted SQL saved.'), findsOneWidget);
  });

  testWidgets('GivenInvalidSql_WhenSubmitted_ThenLocalizedReasonIsSafe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/sql/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      "select 'secret",
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Local:'), findsOneWidget);
    expect(
      find.textContaining('Motivo: Literal não terminado'),
      findsOneWidget,
    );
    final error = tester.widget<Text>(
      find.byKey(const Key('sql-format-error')),
    );
    expect(error.data, isNot(contains('secret')));
  });

  testWidgets('GivenSqlClipboardFailure_WhenCopyRuns_ThenResultIsRemoved', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/sql/format',
        sqlFormatClipboardWriter: (value) async => throw Exception('denied'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'select value from sample',
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('sql-format-copy')));
    await tester.tap(find.byKey(const Key('sql-format-copy')));
    await tester.pumpAndSettle();

    expect(find.text('The clipboard could not be written.'), findsOneWidget);
    expect(find.byKey(const Key('sql-format-result')), findsNothing);
  });

  testWidgets(
    'GivenSqlFileFailures_WhenLoadOrSaveRuns_ThenNoResultIsRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/sql/format',
          sqlFormatFilePicker: () async => throw Exception('denied'),
          sqlFormatFileSaver: (name, bytes) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sql-format-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);
      expect(find.byKey(const Key('sql-format-result')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('sql-format-input')),
        'select value from sample',
      );
      await tester.tap(find.byKey(const Key('sql-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('sql-format-save')));
      await tester.tap(find.byKey(const Key('sql-format-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('The formatted SQL file could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sql-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenSqlResourceFailure_WhenSubmitted_ThenNoPartialResultAppears',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/sql/format',
          sqlFormatService: SqlFormatService(
            formatter: SqlFormatter(maxOutputChars: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sql-format-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The SQL formatting exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sql-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowSqlViewportAndLargeText_WhenRendered_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChimeraApp(localeTag: 'en', initialLocation: '/sql/format'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('sql-format-input')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenXmlFormatRoute_WhenSubmitted_ThenAccessibleResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/xml/format'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('xml-format-input')),
        '<root><name>Ada</name></root>',
      );
      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();

      expect(find.text('<root>\n  <name>Ada</name>\n</root>'), findsOneWidget);
      expect(
        find.byKey(const Key('xml-format-result-semantics')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('xml-format-copy')), findsOneWidget);
      expect(find.byKey(const Key('xml-format-save')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenMalformedXml_WhenSubmitted_ThenLocalizedLocationIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/xml/format'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('xml-format-input')),
        '<root>\n<secret></root>',
      );
      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('xml-format-error')), findsOneWidget);
      expect(find.textContaining('XML malformado'), findsOneWidget);
      expect(find.textContaining('linha 2'), findsOneWidget);
      expect(find.byKey(const Key('xml-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenXmlAdapters_WhenLoadCopyAndSaveRun_ThenExactContentIsTransferred',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/xml/format',
          xmlFormatFilePicker: () async => '<root><file/></root>',
          xmlFormatClipboardReader: () async => '<root><pasted/></root>',
          xmlFormatClipboardWriter: (value) async => copied = value,
          xmlFormatFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('xml-format-file')));
      await tester.pumpAndSettle();
      var input = tester.widget<TextField>(
        find.byKey(const Key('xml-format-input')),
      );
      expect(input.controller!.text, '<root><file/></root>');

      await tester.tap(find.byKey(const Key('xml-format-paste')));
      await tester.pumpAndSettle();
      input = tester.widget<TextField>(
        find.byKey(const Key('xml-format-input')),
      );
      expect(input.controller!.text, '<root><pasted/></root>');

      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('xml-format-copy')));
      await tester.tap(find.byKey(const Key('xml-format-copy')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('xml-format-save')));
      await tester.tap(find.byKey(const Key('xml-format-save')));
      await tester.pumpAndSettle();

      const formatted = '<root>\n  <pasted/>\n</root>';
      expect(copied, formatted);
      expect(savedName, 'chimera-formatted.xml');
      expect(savedBytes, utf8.encode(formatted));
      expect(find.text('Formatted XML saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenXmlAccessFailures_WhenAdaptersRun_ThenResultIsNotRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/xml/format',
          xmlFormatFilePicker: () async => throw Exception('denied'),
          xmlFormatClipboardReader: () async => throw Exception('denied'),
          xmlFormatClipboardWriter: (value) async => throw Exception('denied'),
          xmlFormatFileSaver: (name, bytes) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('xml-format-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('xml-format-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('xml-format-input')),
        '<root/>',
      );
      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('xml-format-copy')));
      await tester.tap(find.byKey(const Key('xml-format-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('xml-format-result')), findsNothing);

      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('xml-format-save')));
      await tester.tap(find.byKey(const Key('xml-format-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The formatted XML file could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('xml-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenXmlResourceFailure_WhenSubmitted_ThenNoPartialResultAppears',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/xml/format',
          xmlFormatService: XmlFormatService(
            formatter: XmlFormatter(maxOutputChars: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('xml-format-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The XML formatting exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('xml-format-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNumberBaseHomeAction_WhenOpened_ThenDefaultConversionAndBoundariesWork',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-number-base')));
      await tester.tap(find.byKey(const Key('open-number-base')));
      await tester.pumpAndSettle();
      expect(find.text('Convert number base'), findsOneWidget);

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      expect(find.text('ff'), findsOneWidget);

      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('number-base-source')),
          )
          .onChanged!(2);
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('number-base-target')),
          )
          .onChanged!(36);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('number-base-input')),
        '1010',
      );
      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('number-base-result-semantics')),
      );
      expect(semantics.properties.value, 'a');
    },
  );

  testWidgets(
    'GivenInvalidNumber_WhenSubmittedInPortuguese_ThenLocalizedFailureHasNoResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/number/convert-base',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Converter base numérica'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('number-base-input')),
        'segredo-Z',
      );
      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();

      expect(find.text('O número ou a base é inválido.'), findsOneWidget);
      expect(find.byKey(const Key('number-base-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNumberResourceFailure_WhenSubmitted_ThenStaleResultIsCleared',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
          numberBaseService: NumberBaseService(
            converter: NumberBaseConverter(maxOutputCharacters: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      expect(find.text('ff'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('number-base-input')), '256');
      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The number conversion exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('number-base-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNumberAdapters_WhenLoadPasteCopyAndSaveRun_ThenExactContentIsTransferred',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
          numberBaseFilePicker: () async => '15',
          numberBaseClipboardReader: () async => '255',
          numberBaseClipboardWriter: (value) async => copied = value,
          numberBaseFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('number-base-file')));
      await tester.pumpAndSettle();
      var input = tester.widget<TextField>(
        find.byKey(const Key('number-base-input')),
      );
      expect(input.controller!.text, '15');

      await tester.tap(find.byKey(const Key('number-base-paste')));
      await tester.pumpAndSettle();
      input = tester.widget<TextField>(
        find.byKey(const Key('number-base-input')),
      );
      expect(input.controller!.text, '255');

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('number-base-copy')));
      await tester.tap(find.byKey(const Key('number-base-copy')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('number-base-save')));
      await tester.tap(find.byKey(const Key('number-base-save')));
      await tester.pumpAndSettle();

      expect(copied, 'ff');
      expect(savedName, 'chimera-converted-number.txt');
      expect(savedBytes, utf8.encode('ff'));
      expect(find.text('Converted value saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenNumberAccessFailures_WhenAdaptersRun_ThenResultIsNotRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
          numberBaseFilePicker: () async => throw Exception('denied'),
          numberBaseClipboardReader: () async => throw Exception('denied'),
          numberBaseClipboardWriter: (_) async => throw Exception('denied'),
          numberBaseFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('number-base-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('number-base-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('number-base-copy')));
      await tester.tap(find.byKey(const Key('number-base-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('number-base-result')), findsNothing);

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('number-base-save')));
      await tester.tap(find.byKey(const Key('number-base-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The converted value could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('number-base-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNumberKeyboardSubmission_WhenDoneIsInvoked_ThenConversionRunsAccessibly',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
        ),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(
        find.byKey(const Key('number-base-input')),
      );
      expect(input.textInputAction, TextInputAction.done);
      input.onSubmitted!('255');
      await tester.pumpAndSettle();

      expect(find.text('ff'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenNumberResult_WhenInputIsEdited_ThenStaleActionsAreCleared',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('number-base-result')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('number-base-input')), '256');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('number-base-result')), findsNothing);
      expect(find.byKey(const Key('number-base-copy')), findsNothing);
      expect(find.byKey(const Key('number-base-save')), findsNothing);
    },
  );

  testWidgets(
    'GivenDelayedNumberLoad_WhenPending_ThenKeyboardSubmissionCannotRaceIt',
    (tester) async {
      final loadedValue = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
          numberBaseFilePicker: () => loadedValue.future,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('number-base-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('number-base-file')));
      await tester.pump();
      final pendingInput = tester.widget<TextField>(
        find.byKey(const Key('number-base-input')),
      );
      expect(pendingInput.enabled, isFalse);
      expect(pendingInput.onSubmitted, isNull);
      expect(find.byKey(const Key('number-base-result')), findsNothing);

      loadedValue.complete('15');
      await tester.pumpAndSettle();
      final completedInput = tester.widget<TextField>(
        find.byKey(const Key('number-base-input')),
      );
      expect(completedInput.enabled, isTrue);
      expect(completedInput.controller!.text, '15');
      expect(find.byKey(const Key('number-base-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextEscapeHomeAction_WhenOpened_ThenAllModesAndSemanticsWork',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-text-escape')));
      await tester.tap(find.byKey(const Key('open-text-escape')));
      await tester.pumpAndSettle();
      expect(find.text('Escape text'), findsWidgets);

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      expect(find.text(r'Hello, \"Chimera\"!'), findsOneWidget);

      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('text-escape-mode')),
      );
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('text-escape-mode')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value), <String>[
        'json',
        'unicode',
        'c',
        'html',
        'url',
      ]);
      selector.onChanged!('html');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('text-escape-input')), '&<');
      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();

      expect(find.text('&amp;&lt;'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('text-escape-result-semantics')),
      );
      expect(semantics.properties.value, '&amp;&lt;');
    },
  );

  testWidgets(
    'GivenTextEscapeResourceFailure_WhenSubmitted_ThenLocalizedFailureHasNoResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/escape',
          textEscapeService: TextEscapeService(
            escaper: TextEscaper(maxOutputCharacters: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Escapar texto'), findsWidgets);
      await tester.enterText(find.byKey(const Key('text-escape-input')), '&');
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-escape-mode')),
          )
          .onChanged!('html');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('O escape de texto excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-escape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextEscapeAdapters_WhenLoadPasteCopyAndSaveRun_ThenExactContentTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/escape',
          textEscapeFilePicker: () async => '&',
          textEscapeClipboardReader: () async => '<',
          textEscapeClipboardWriter: (value) async => copied = value,
          textEscapeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-escape-mode')),
          )
          .onChanged!('html');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-escape-file')));
      await tester.pumpAndSettle();
      var input = tester.widget<TextField>(
        find.byKey(const Key('text-escape-input')),
      );
      expect(input.controller!.text, '&');

      await tester.tap(find.byKey(const Key('text-escape-paste')));
      await tester.pumpAndSettle();
      input = tester.widget<TextField>(
        find.byKey(const Key('text-escape-input')),
      );
      expect(input.controller!.text, '<');

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-escape-copy')));
      await tester.tap(find.byKey(const Key('text-escape-copy')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-escape-save')));
      await tester.tap(find.byKey(const Key('text-escape-save')));
      await tester.pumpAndSettle();

      expect(copied, '&lt;');
      expect(savedName, 'chimera-escaped-text.txt');
      expect(savedBytes, utf8.encode('&lt;'));
      expect(find.text('Escaped text saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextEscapeAccessFailures_WhenAdaptersRun_ThenResultIsNotRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/escape',
          textEscapeFilePicker: () async => throw Exception('denied'),
          textEscapeClipboardReader: () async => throw Exception('denied'),
          textEscapeClipboardWriter: (_) async => throw Exception('denied'),
          textEscapeFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-escape-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-escape-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-escape-copy')));
      await tester.tap(find.byKey(const Key('text-escape-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('text-escape-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-escape-save')));
      await tester.tap(find.byKey(const Key('text-escape-save')));
      await tester.pumpAndSettle();
      expect(find.text('The escaped text could not be saved.'), findsOneWidget);
      expect(find.byKey(const Key('text-escape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenMultilineText_WhenTypedAndSubmitted_ThenNewlineEscapesAccessibly',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/escape'),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(
        find.byKey(const Key('text-escape-input')),
      );
      expect(input.keyboardType, TextInputType.multiline);
      expect(input.textInputAction, TextInputAction.newline);
      expect(input.onSubmitted, isNull);
      await tester.enterText(
        find.byKey(const Key('text-escape-input')),
        'line one\nline two',
      );
      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();

      expect(find.text(r'line one\nline two'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextEscapeResult_WhenInputOrModeChanges_ThenStaleActionsAreCleared',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/escape'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-escape-result')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('text-escape-input')), 'new');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-escape-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-escape-mode')),
          )
          .onChanged!('unicode');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-escape-result')), findsNothing);
      expect(find.byKey(const Key('text-escape-copy')), findsNothing);
      expect(find.byKey(const Key('text-escape-save')), findsNothing);
    },
  );

  testWidgets(
    'GivenDelayedTextLoad_WhenPending_ThenKeyboardSubmissionCannotRaceIt',
    (tester) async {
      final loadedValue = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/escape',
          textEscapeFilePicker: () => loadedValue.future,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-escape-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-escape-file')));
      await tester.pump();
      final pendingInput = tester.widget<TextField>(
        find.byKey(const Key('text-escape-input')),
      );
      expect(pendingInput.enabled, isFalse);
      expect(pendingInput.onSubmitted, isNull);
      expect(find.byKey(const Key('text-escape-result')), findsNothing);

      loadedValue.complete('&');
      await tester.pumpAndSettle();
      final completedInput = tester.widget<TextField>(
        find.byKey(const Key('text-escape-input')),
      );
      expect(completedInput.enabled, isTrue);
      expect(completedInput.controller!.text, '&');
      expect(find.byKey(const Key('text-escape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowTextEscapeViewport_WhenLargeText_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/text/escape'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Escapar texto'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextUnescapeHomeAction_WhenOpened_ThenAllModesAndSemanticsWork',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-text-unescape')));
      await tester.tap(find.byKey(const Key('open-text-unescape')));
      await tester.pumpAndSettle();
      expect(find.text('Unescape text'), findsWidgets);

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Hello, "Chimera"!'), findsOneWidget);

      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('text-unescape-mode')),
      );
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('text-unescape-mode')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value), <String>[
        'json',
        'unicode',
        'c',
        'html',
        'url',
      ]);
      selector.onChanged!('html');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        '&amp;&lt;',
      );
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(find.text('&<'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('text-unescape-result-semantics')),
      );
      expect(semantics.properties.value, '&<');
    },
  );

  testWidgets(
    'GivenMalformedUnescapeInput_WhenSubmitted_ThenLocalizedFailureHasNoResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/text/unescape'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        r'\q',
      );
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('O texto escapado, o modo ou as opções são inválidos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextUnescapeAdapters_WhenLoadPasteCopyAndSave_ThenExactContentTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/unescape',
          textUnescapeFilePicker: () async => '&amp;',
          textUnescapeClipboardReader: () async => '&lt;',
          textUnescapeClipboardWriter: (value) async => copied = value,
          textUnescapeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-unescape-mode')),
          )
          .onChanged!('html');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-unescape-file')));
      await tester.pumpAndSettle();
      var input = tester.widget<TextField>(
        find.byKey(const Key('text-unescape-input')),
      );
      expect(input.controller!.text, '&amp;');

      await tester.tap(find.byKey(const Key('text-unescape-paste')));
      await tester.pumpAndSettle();
      input = tester.widget<TextField>(
        find.byKey(const Key('text-unescape-input')),
      );
      expect(input.controller!.text, '&lt;');

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-unescape-copy')));
      await tester.tap(find.byKey(const Key('text-unescape-copy')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-unescape-save')));
      await tester.tap(find.byKey(const Key('text-unescape-save')));
      await tester.pumpAndSettle();

      expect(copied, '<');
      expect(savedName, 'chimera-unescaped-text.txt');
      expect(savedBytes, utf8.encode('<'));
      expect(find.text('Unescaped text saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenIsolatedSurrogateFromAdapter_WhenSubmitted_ThenNoResultIsRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/unescape',
          textUnescapeFilePicker: () async => r'\uD800',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-unescape-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The escaped text, mode, or options are invalid.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);
      expect(find.byKey(const Key('text-unescape-save')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextUnescapeAccessFailures_WhenAdaptersRun_ThenResultIsNotRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/unescape',
          textUnescapeFilePicker: () async => throw Exception('denied'),
          textUnescapeClipboardReader: () async => throw Exception('denied'),
          textUnescapeClipboardWriter: (_) async => throw Exception('denied'),
          textUnescapeFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-unescape-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-unescape-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-unescape-copy')));
      await tester.tap(find.byKey(const Key('text-unescape-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-unescape-save')));
      await tester.tap(find.byKey(const Key('text-unescape-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The unescaped text could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenMultilineEscapes_WhenSubmitted_ThenNewlinesDecodeAccessibly',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/unescape'),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(
        find.byKey(const Key('text-unescape-input')),
      );
      expect(input.keyboardType, TextInputType.multiline);
      expect(input.textInputAction, TextInputAction.newline);
      expect(input.onSubmitted, isNull);
      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        r'line one\nline two',
      );
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(find.text('line one\nline two'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextUnescapeResult_WhenInputModeOrPendingLoadChanges_ThenStaleClears',
    (tester) async {
      final loadedValue = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/unescape',
          textUnescapeFilePicker: () => loadedValue.future,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-unescape-result')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        r'new\n',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-unescape-mode')),
          )
          .onChanged!('unicode');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-unescape-file')));
      await tester.pump();
      final pendingInput = tester.widget<TextField>(
        find.byKey(const Key('text-unescape-input')),
      );
      expect(pendingInput.enabled, isFalse);
      expect(find.byKey(const Key('text-unescape-submit')), findsOneWidget);

      loadedValue.complete(r'\u0041');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('text-unescape-input')))
            .controller!
            .text,
        r'\u0041',
      );
      expect(find.byKey(const Key('text-unescape-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowTextUnescapeViewport_WhenLargeText_ThenFormDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/text/unescape'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Remover escape de texto'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenListCompareHomeAction_WhenOptionsSelected_ThenLocalizedSetsAndSemanticsRender',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-list-compare')));
      await tester.tap(find.byKey(const Key('open-list-compare')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('list-compare-left-input')))
            .controller!
            .text,
        'alpha\nbeta',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('list-compare-right-input')),
            )
            .controller!
            .text,
        'alpha\ngamma',
      );

      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        ' Alpha \nalpha\nleft',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'ALPHA\nright',
      );
      await tester.tap(find.byKey(const Key('list-compare-case')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Case insensitive').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-whitespace')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trim whitespace').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-duplicates')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distinct items').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
      expect(find.text(' Alpha '), findsOneWidget);
      expect(find.text('Equal: no'), findsOneWidget);
      expect(
        find.byKey(const Key('list-compare-intersection-semantics')),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTrailingBlankListItem_WhenCompared_ThenCountAndSemanticsExposeIt',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/list/compare'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'alpha\n',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'alpha',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('list-compare-left-only-semantics')),
          matching: find.text('Items: 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('list-compare-right-only-semantics')),
          matching: find.text('Items: 0'),
        ),
        findsOneWidget,
      );
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('list-compare-left-only-semantics')),
      );
      expect(semantics.properties.role, SemanticsRole.region);
      expect(semantics.properties.value, 'Items: 1\n');
    },
  );

  testWidgets(
    'GivenListCompareAdapters_WhenLoadedCopiedAndSaved_ThenExactPreviewTransfers',
    (tester) async {
      String? copied;
      List<int>? saved;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/list/compare',
          listCompareLeftFilePicker: () async => 'um\ndois',
          listCompareRightClipboardReader: () async => 'dois\ntrês',
          listCompareClipboardWriter: (value) async => copied = value,
          listCompareFileSaver: (_, bytes) async {
            saved = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('list-compare-left-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-right-paste')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();

      const preview =
          'Somente à esquerda:\num\n'
          'Somente à direita:\ntrês\n'
          'Interseção:\ndois\n'
          'Iguais: não\n';
      await tester.ensureVisible(find.byKey(const Key('list-compare-copy')));
      await tester.tap(find.byKey(const Key('list-compare-copy')));
      await tester.pumpAndSettle();
      expect(copied, preview);
      expect(find.text('Comparação de listas copiada.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('list-compare-save')));
      await tester.tap(find.byKey(const Key('list-compare-save')));
      await tester.pumpAndSettle();
      expect(utf8.decode(saved!), preview);
      expect(find.text('Comparação de listas salva.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenListCompareFailures_WhenActionsFail_ThenNoPartialResultIsRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/list/compare',
          listCompareLeftFilePicker: () async => throw Exception('secret'),
          listCompareClipboardWriter: (_) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'same',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'same',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-compare-copy')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('list-compare-copy')));
      await tester.tap(find.byKey(const Key('list-compare-copy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-compare-copy')), findsNothing);
      expect(find.text('The clipboard could not be written.'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('list-compare-left-file')),
      );
      await tester.tap(find.byKey(const Key('list-compare-left-file')));
      await tester.pumpAndSettle();
      expect(find.text('The list file could not be read.'), findsOneWidget);
      expect(find.byKey(const Key('list-compare-copy')), findsNothing);

      await tester.pumpWidget(
        ChimeraApp(
          key: UniqueKey(),
          localeTag: 'en',
          initialLocation: '/list/compare',
          listCompareService: const ListCompareService(
            comparator: ListComparator(maxResultItems: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'item',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('List comparison exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('list-compare-copy')), findsNothing);
    },
  );

  testWidgets(
    'GivenListCompareSaveFailure_WhenSaved_ThenResultClearsAndErrorAppears',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/list/compare',
          listCompareFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-compare-save')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('list-compare-save')));
      await tester.tap(find.byKey(const Key('list-compare-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('list-compare-save')), findsNothing);
      expect(
        find.text('The list comparison could not be saved.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenPendingListLoadOrChangedInput_WhenResultExists_ThenStaleClearsAndActionsDisable',
    (tester) async {
      final loaded = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/list/compare',
          listCompareLeftFilePicker: () => loaded.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'same',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'same',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-compare-copy')), findsOneWidget);

      await tester.tap(find.byKey(const Key('list-compare-left-file')));
      await tester.pump();
      expect(find.byKey(const Key('list-compare-copy')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('list-compare-submit')),
            )
            .onPressed,
        isNull,
      );
      loaded.complete('loaded');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'changed',
      );
      expect(find.byKey(const Key('list-compare-copy')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowListCompareViewport_WhenPortugueseFormRenders_ThenNoOverflowOccurs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/list/compare'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Comparar listas'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenTextAnalyzeHomeAction_WhenUnicodeSubmitted_ThenCountsAndSemanticsRender',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-text-analyze')));
      await tester.tap(find.byKey(const Key('open-text-analyze')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-analyze-input')),
        'Cafe\u0301 👩🏽‍💻\nOlá',
      );
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Characters: 10'), findsOneWidget);
      expect(find.text('Words: 2'), findsOneWidget);
      expect(find.text('Lines: 2'), findsOneWidget);
      expect(find.text('UTF-8 bytes: 27'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('text-analyze-result-semantics')),
      );
      expect(semantics.properties.role, SemanticsRole.region);
      expect(
        semantics.properties.value,
        'Characters: 10\nWords: 2\nLines: 2\nUTF-8 bytes: 27',
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextAnalyzeAdapters_WhenLoadedCopiedAndSaved_ThenExactPreviewTransfers',
    (tester) async {
      String? copied;
      List<int>? saved;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/analyze',
          textAnalyzeFilePicker: () async => 'arquivo',
          textAnalyzeClipboardReader: () async => 'A\nB',
          textAnalyzeClipboardWriter: (value) async => copied = value,
          textAnalyzeFileSaver: (_, bytes) async {
            saved = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-analyze-file')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('text-analyze-input')))
            .controller!
            .text,
        'arquivo',
      );
      await tester.tap(find.byKey(const Key('text-analyze-paste')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();

      const preview = 'Caracteres: 3\nPalavras: 2\nLinhas: 2\nBytes UTF-8: 3\n';
      await tester.ensureVisible(find.byKey(const Key('text-analyze-copy')));
      await tester.tap(find.byKey(const Key('text-analyze-copy')));
      await tester.pumpAndSettle();
      expect(copied, preview);
      expect(find.text('Análise de texto copiada.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('text-analyze-save')));
      await tester.tap(find.byKey(const Key('text-analyze-save')));
      await tester.pumpAndSettle();
      expect(utf8.decode(saved!), preview);
      expect(find.text('Análise de texto salva.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextAnalyzeFailures_WhenActionsFail_ThenNoPartialResultIsRetained',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/analyze',
          textAnalyzeFilePicker: () async => throw Exception('secret'),
          textAnalyzeClipboardReader: () async => throw Exception('denied'),
          textAnalyzeClipboardWriter: (_) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-analyze-copy')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('text-analyze-copy')));
      await tester.tap(find.byKey(const Key('text-analyze-copy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);
      expect(find.text('The clipboard could not be written.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('text-analyze-file')));
      await tester.tap(find.byKey(const Key('text-analyze-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);

      await tester.tap(find.byKey(const Key('text-analyze-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);

      await tester.pumpWidget(
        ChimeraApp(
          key: UniqueKey(),
          localeTag: 'en',
          initialLocation: '/text/analyze',
          textAnalyzeService: const TextAnalyzeService(
            analyzer: TextAnalyzer(maxInputCodeUnits: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Text analysis exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextAnalyzeSaveFailure_WhenSaved_ThenResultClearsAndErrorAppears',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/analyze',
          textAnalyzeFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-analyze-save')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('text-analyze-save')));
      await tester.tap(find.byKey(const Key('text-analyze-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('text-analyze-save')), findsNothing);
      expect(
        find.text('The text analysis could not be saved.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenPendingTextAnalyzeLoadOrChangedInput_WhenResultExists_ThenStaleClearsAndActionsDisable',
    (tester) async {
      final loaded = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/analyze',
          textAnalyzeFilePicker: () => loaded.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-analyze-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-analyze-copy')), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-analyze-file')));
      await tester.pump();
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('text-analyze-submit')),
            )
            .onPressed,
        isNull,
      );
      loaded.complete('loaded');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-analyze-input')),
        'changed',
      );
      expect(find.byKey(const Key('text-analyze-copy')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowTextAnalyzeViewport_WhenPortugueseFormRenders_ThenNoOverflowOccurs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/text/analyze'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Analisar texto'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextTransformHomeAction_WhenOpened_ThenAllModesAndSemanticsWork',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-text-transform')));
      await tester.tap(find.byKey(const Key('open-text-transform')));
      await tester.pumpAndSettle();
      expect(find.text('Transform text'), findsWidgets);

      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('text-transform-mode')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value), <String>[
        'lowercase',
        'uppercase',
        'normalize-whitespace',
        'sort-lines',
        'deduplicate-lines',
      ]);

      final cases = <String, (String, String)>{
        'lowercase': ('ÉCOLE', 'école'),
        'uppercase': ('straße', 'STRASSE'),
        'normalize-whitespace': (' one\t two ', 'one two'),
        'sort-lines': ('b\na', 'a\nb'),
        'deduplicate-lines': ('b\na\nb', 'b\na'),
      };
      for (final entry in cases.entries) {
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('text-transform-mode')),
            )
            .onChanged!(entry.key);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('text-transform-input')),
          entry.value.$1,
        );
        await tester.tap(find.byKey(const Key('text-transform-submit')));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find.byKey(const Key('text-transform-result-semantics')),
        );
        expect(semantics.properties.label, 'Transformed text');
        expect(semantics.properties.value, entry.value.$2, reason: entry.key);
      }
    },
  );

  testWidgets(
    'GivenTextTransformAdapters_WhenLoadPasteCopyAndSaveRun_ThenExactOutputTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/transform',
          textTransformFilePicker: () async => 'FILE',
          textTransformClipboardReader: () async => 'straße',
          textTransformClipboardWriter: (value) async => copied = value,
          textTransformFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-transform-file')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('text-transform-input')))
            .controller!
            .text,
        'FILE',
      );

      await tester.tap(find.byKey(const Key('text-transform-paste')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-transform-mode')),
          )
          .onChanged!('uppercase');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('text-transform-copy')));
      await tester.tap(find.byKey(const Key('text-transform-copy')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-transform-save')));
      await tester.tap(find.byKey(const Key('text-transform-save')));
      await tester.pumpAndSettle();

      expect(copied, 'STRASSE');
      expect(savedName, 'chimera-transformed-text.txt');
      expect(savedBytes, utf8.encode('STRASSE'));
      expect(find.text('Transformed text saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextTransformAccessFailures_WhenAdaptersRun_ThenResultIsCleared',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/transform',
          textTransformFilePicker: () async => throw Exception('denied'),
          textTransformClipboardReader: () async => throw Exception('denied'),
          textTransformClipboardWriter: (_) async => throw Exception('denied'),
          textTransformFileSaver: (_, _) async => throw Exception('denied'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-transform-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-transform-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-transform-copy')));
      await tester.tap(find.byKey(const Key('text-transform-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('text-transform-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-transform-save')));
      await tester.tap(find.byKey(const Key('text-transform-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The transformed text could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-transform-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextTransformResourceFailure_WhenSubmitted_ThenNoPartialOutputRemains',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/transform',
          textTransformService: TextTransformService(
            transformer: TextTransformer(maxOutputCodeUnits: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-transform-input')),
        'ß',
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-transform-mode')),
          )
          .onChanged!('uppercase');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('A transformação de texto excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-transform-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextTransformResult_WhenInputOrModeChanges_ThenStaleOutputClears',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/transform'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-transform-result')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('text-transform-input')),
        'x',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-transform-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-transform-submit')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-transform-mode')),
          )
          .onChanged!('uppercase');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-transform-result')), findsNothing);
      expect(find.byKey(const Key('text-transform-copy')), findsNothing);
      expect(find.byKey(const Key('text-transform-save')), findsNothing);
    },
  );

  testWidgets('GivenPendingTextTransformLoad_WhenBusy_ThenActionsCannotRace', (
    tester,
  ) async {
    final loaded = Completer<String?>();
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        initialLocation: '/text/transform',
        textTransformFilePicker: () => loaded.future,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('text-transform-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('text-transform-result')), findsOneWidget);

    await tester.tap(find.byKey(const Key('text-transform-file')));
    await tester.pump();
    expect(find.byKey(const Key('text-transform-result')), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('text-transform-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('text-transform-input')))
          .enabled,
      isFalse,
    );

    loaded.complete('loaded');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('text-transform-input')))
          .controller!
          .text,
      'loaded',
    );
  });

  testWidgets(
    'GivenNarrowTextTransformViewport_WhenPortugueseFormRenders_ThenNoOverflowOccurs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/transform',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Transformar texto'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextCompareHomeAction_WhenOpened_ThenGranularitiesAndSemanticsWork',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-text-compare')));
      await tester.tap(find.byKey(const Key('open-text-compare')));
      await tester.pumpAndSettle();
      expect(find.text('Compare text'), findsWidgets);

      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('text-compare-granularity')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value), <String>[
        'line',
        'word',
        'character',
      ]);

      for (final granularity in <String>['line', 'word', 'character']) {
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('text-compare-granularity')),
            )
            .onChanged!(granularity);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('text-compare-left-input')),
          'alpha beta',
        );
        await tester.enterText(
          find.byKey(const Key('text-compare-right-input')),
          'alpha brave beta',
        );
        await tester.tap(find.byKey(const Key('text-compare-submit')));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find.byKey(const Key('text-compare-result-semantics')),
        );
        expect(semantics.properties.role, SemanticsRole.region);
        expect(semantics.properties.label, 'Text comparison result');
        expect(semantics.properties.value, contains('Added'));
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'GivenTextCompareAdapters_WhenLoadedCopiedAndSaved_ThenExactJsonTransfers',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/compare',
          textCompareLeftFilePicker: () async => 'Hello world',
          textCompareRightClipboardReader: () async => 'Hello brave world',
          textCompareClipboardWriter: (value) async => copied = value,
          textCompareFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-compare-left-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-compare-right-paste')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-compare-granularity')),
          )
          .onChanged!('word');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();

      final expected = jsonEncode(const <String, Object?>{
        'granularity': 'word',
        'spans': <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'unchanged',
            'text': 'Hello ',
            'tokenCount': 2,
          },
          <String, Object?>{'kind': 'added', 'text': 'brave ', 'tokenCount': 2},
          <String, Object?>{
            'kind': 'unchanged',
            'text': 'world',
            'tokenCount': 1,
          },
        ],
        'summary': <String, Object?>{'added': 2, 'removed': 0, 'unchanged': 3},
      });
      await tester.ensureVisible(find.byKey(const Key('text-compare-copy')));
      await tester.tap(find.byKey(const Key('text-compare-copy')));
      await tester.pumpAndSettle();
      expect(copied, expected);
      expect(find.text('Comparação de textos copiada.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('text-compare-save')));
      await tester.tap(find.byKey(const Key('text-compare-save')));
      await tester.pumpAndSettle();
      expect(savedName, 'chimera-text-diff.json');
      expect(utf8.decode(savedBytes!), expected);
      expect(find.text('Comparação de textos salva.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextCompareAccessFailures_WhenAdaptersRun_ThenResultIsCleared',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/compare',
          textCompareLeftFilePicker: () async => throw Exception('secret'),
          textCompareRightClipboardReader: () async =>
              throw Exception('secret'),
          textCompareClipboardWriter: (_) async => throw Exception('secret'),
          textCompareFileSaver: (_, _) async => throw Exception('secret'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('text-compare-left-file')));
      await tester.pumpAndSettle();
      expect(find.text('The text file could not be read.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('text-compare-right-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-compare-copy')));
      await tester.tap(find.byKey(const Key('text-compare-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('text-compare-result')), findsNothing);

      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('text-compare-save')));
      await tester.tap(find.byKey(const Key('text-compare-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The text comparison could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-compare-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenTextCompareResourceFailure_WhenSubmitted_ThenNoPartialOutputRemains',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/text/compare',
          textCompareService: TextCompareService(
            comparer: TextComparer(maxWorkUnits: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-compare-left-input')),
        'a',
      );
      await tester.enterText(
        find.byKey(const Key('text-compare-right-input')),
        'b',
      );
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('A comparação de textos excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('text-compare-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingTextCompareLoadOrChangedInput_WhenResultExists_ThenStaleClearsAndActionsDisable',
    (tester) async {
      final loaded = Completer<String?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/text/compare',
          textCompareLeftFilePicker: () => loaded.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text-compare-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('text-compare-left-file')));
      await tester.pump();
      expect(find.byKey(const Key('text-compare-result')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('text-compare-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('text-compare-right-input')),
            )
            .enabled,
        isFalse,
      );
      loaded.complete('loaded');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-compare-right-input')),
        'changed',
      );
      expect(find.byKey(const Key('text-compare-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenNarrowTextCompareViewport_WhenPortugueseFormRenders_ThenNoOverflowOccurs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/text/compare'),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Comparar textos'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
