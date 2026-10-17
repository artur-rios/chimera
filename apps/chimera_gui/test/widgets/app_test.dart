import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui' show SemanticsRole;

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/base64_decode_page.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}ConvertHomeAction_WhenActivated_ThenConversionRouteOpens',
      (tester) async {
        await tester.pumpWidget(ChimeraApp(localeTag: locale));
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('open-certificate-convert'));
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('certificate-convert-input')),
          findsOneWidget,
        );
        expect(
          find.text(
            locale == 'en' ? 'Convert certificate' : 'Converter certificado',
          ),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'GivenCertificateHomeAction_WhenActivated_ThenInspectionRouteOpens',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp());
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('open-certificate-inspect'));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('certificate-inspect-input')),
        findsOneWidget,
      );
      expect(find.text('Inspect certificate'), findsOneWidget);
    },
  );

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
    'GivenMixedTextCompareSpans_WhenRendered_ThenKindsAreVisibleAndContrastPasses',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/compare'),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-compare-granularity')),
          )
          .onChanged!('word');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-compare-left-input')),
        'same old',
      );
      await tester.enterText(
        find.byKey(const Key('text-compare-right-input')),
        'same new',
      );
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('text-compare-span-0-kind')), findsOneWidget);
      expect(find.byKey(const Key('text-compare-span-1-kind')), findsOneWidget);
      expect(find.byKey(const Key('text-compare-span-2-kind')), findsOneWidget);
      expect(find.text('Unchanged'), findsOneWidget);
      expect(find.text('Removed'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );

  testWidgets(
    'GivenManyTextCompareSpans_WhenRendered_ThenOnlyVisibleCardsAreBuilt',
    (tester) async {
      final left = List<String>.filled(200, 'ab').join();
      final right = List<String>.filled(200, 'ac').join();
      final spanCount = const TextComparer()
          .compare(left: left, right: right, granularity: 'character')
          .spans
          .length;
      expect(spanCount, greaterThan(100));

      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/compare'),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('text-compare-granularity')),
          )
          .onChanged!('character');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-compare-left-input')),
        left,
      );
      await tester.enterText(
        find.byKey(const Key('text-compare-right-input')),
        right,
      );
      await tester.tap(find.byKey(const Key('text-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('text-compare-spans')), findsOneWidget);
      final renderedCards = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            RegExp(r'^text-compare-span-\d+$').hasMatch(key.value);
      });
      expect(renderedCards.evaluate().length, lessThan(spanCount));
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

  testWidgets(
    'GivenBase64EncodeHomeAction_WhenOpened_ThenTextEncodesWithBoundedSemantics',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-base64-encode')));
      await tester.tap(find.byKey(const Key('open-base64-encode')));
      await tester.pumpAndSettle();

      expect(find.text('Base64 encode'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('base64-encode-input')),
        'Hello',
      );
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('SGVsbG8='), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('base64-encode-result-semantics')),
      );
      expect(semantics.properties.role, SemanticsRole.region);
      expect(
        semantics.properties.value,
        contains('Base64 encoding succeeded.'),
      );
      expect(semantics.properties.value, contains('Input bytes: 5'));
      expect(semantics.properties.value, contains('Output characters: 8'));
      expect(semantics.properties.value, isNot(contains('SGVsbG8=')));
    },
  );

  testWidgets(
    'GivenPortugueseBase64Result_WhenEncoded_ThenBoundedSemanticsAnnounceSuccess',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'pt-BR', initialLocation: '/base64/encode'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('base64-encode-input')),
        'Olá',
      );
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('base64-encode-result-semantics')),
      );
      expect(
        semantics.properties.value,
        contains('Codificação Base64 concluída.'),
      );
      expect(semantics.properties.value, contains('Bytes de entrada: 4'));
      expect(semantics.properties.value, contains('Caracteres de saída: 8'));
      expect(semantics.properties.value, isNot(contains('T2zDoQ==')));
    },
  );

  testWidgets(
    'GivenBinaryFileAndClipboard_WhenSourcesChange_ThenModesAreExclusiveAndTransfersAreExact',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeFilePicker: () async => <int>[0, 255],
          base64EncodeClipboardReader: () async => 'Olá',
          base64EncodeClipboardWriter: (value) async => copied = value,
          base64EncodeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-encode-file')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('base64-encode-file-summary')),
        findsOneWidget,
      );
      expect(find.text('Input bytes: 2'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-encode-input')))
            .controller!
            .text,
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('AP8='), findsOneWidget);
      await tester.tap(find.byKey(const Key('base64-encode-copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-encode-save')));
      await tester.pumpAndSettle();
      expect(copied, 'AP8=');
      expect(savedName, 'chimera-base64.txt');
      expect(savedBytes, utf8.encode('AP8='));

      await tester.tap(find.byKey(const Key('base64-encode-paste')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('base64-encode-file-summary')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-encode-input')))
            .controller!
            .text,
        'Olá',
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('T2zDoQ=='), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('base64-encode-input')),
        'text',
      );
      await tester.pump();
      expect(find.byKey(const Key('base64-encode-file-summary')), findsNothing);
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenSelectedEmptyText_WhenEncoded_ThenEmptyBase64IsAValidResult',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/base64/encode'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('base64-encode-input')), '');
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      final result = tester.widget<SelectableText>(
        find.byKey(const Key('base64-encode-result')),
      );
      expect(result.data, '');
      expect(find.text('Input bytes: 0'), findsOneWidget);
      expect(find.text('Output characters: 0'), findsOneWidget);
      expect(find.byKey(const Key('base64-encode-copy')), findsOneWidget);
      expect(find.byKey(const Key('base64-encode-save')), findsOneWidget);
    },
  );

  testWidgets(
    'GivenBase64AdapterAccessFailures_WhenActionsRun_ThenLocalizedErrorsClearResults',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeFilePicker: () async => throw Exception('private path'),
          base64EncodeClipboardReader: () async => throw Exception('secret'),
          base64EncodeClipboardWriter: (_) async => throw Exception('secret'),
          base64EncodeFileSaver: (_, _) async => throw Exception('secret'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-encode-file')));
      await tester.pumpAndSettle();
      expect(find.text('The input file could not be read.'), findsOneWidget);
      expect(find.textContaining('private path'), findsNothing);

      await tester.tap(find.byKey(const Key('base64-encode-paste')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be read.'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);

      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-encode-copy')));
      await tester.pumpAndSettle();
      expect(find.text('The clipboard could not be written.'), findsOneWidget);
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);

      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-encode-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('The Base64 result could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenAllocationOrEncoderLimits_WhenActionsRun_ThenResourceErrorHasNoPartialResult',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/base64/encode',
          base64EncodeService: const Base64EncodeService(
            encoder: Base64ByteEncoder(maxInputBytes: 0),
          ),
          base64EncodeFilePicker: () async => throw OutOfMemoryError(),
          base64EncodeClipboardReader: () async => throw OutOfMemoryError(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-encode-file')));
      await tester.pumpAndSettle();
      expect(
        find.text('A codificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('base64-encode-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('A codificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('base64-encode-input')), 'a');
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('A codificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenClipboardWriterAllocationFailure_WhenCopied_ThenResourceErrorClearsResultAndBusyState',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeClipboardWriter: (_) async => throw OutOfMemoryError(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('base64-encode-input')), 'a');
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('base64-encode-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('base64-encode-copy')));
      await tester.pumpAndSettle();

      expect(
        find.text('Base64 encoding exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-encode-input')))
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('base64-encode-submit')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'GivenFileSaverAllocationFailure_WhenSaved_ThenResourceErrorClearsResultAndBusyState',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/base64/encode',
          base64EncodeFileSaver: (_, _) async => throw OutOfMemoryError(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('base64-encode-input')), 'a');
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('base64-encode-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('base64-encode-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('A codificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('base64-encode-submit')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'GivenOutputBufferAllocationFailure_WhenSaved_ThenNoPartialFileOrResultRemains',
    (tester) async {
      var saverCalled = false;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeOutputEncoder: (_) => throw OutOfMemoryError(),
          base64EncodeFileSaver: (_, _) async {
            saverCalled = true;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('base64-encode-input')), 'a');
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-encode-save')));
      await tester.pumpAndSettle();

      expect(saverCalled, isFalse);
      expect(
        find.text('Base64 encoding exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('base64-encode-submit')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'GivenPendingBase64FileLoad_WhenResultExists_ThenStaleOutputClearsAndRacesDisable',
    (tester) async {
      final loaded = Completer<List<int>?>();
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeFilePicker: () => loaded.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-encode-input')),
        'old',
      );
      await tester.tap(find.byKey(const Key('base64-encode-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('base64-encode-result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('base64-encode-file')));
      await tester.pump();
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-encode-input')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('base64-encode-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('base64-encode-paste')),
            )
            .onPressed,
        isNull,
      );

      loaded.complete(<int>[0, 255]);
      await tester.pumpAndSettle();
      expect(find.text('Input bytes: 2'), findsOneWidget);
      expect(find.byKey(const Key('base64-encode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenKeyboardTraversal_WhenBase64ControlsActivate_ThenOrderIsTextFilePasteEncode',
    (tester) async {
      var fileReads = 0;
      var clipboardReads = 0;
      String? copied;
      String? saved;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/encode',
          base64EncodeFilePicker: () async {
            fileReads++;
            return <int>[65];
          },
          base64EncodeClipboardReader: () async {
            clipboardReads++;
            return 'B';
          },
          base64EncodeClipboardWriter: (value) async => copied = value,
          base64EncodeFileSaver: (name, bytes) async {
            saved = '$name:${utf8.decode(bytes)}';
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fileReads, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(clipboardReads, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Qg=='), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, 'Qg==');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saved, 'chimera-base64.txt:Qg==');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    },
  );

  testWidgets(
    'GivenNarrowBase64Viewport_WhenBothLocalesUseLargeText_ThenContentDoesNotOverflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final locale in <String>['en', 'pt-BR']) {
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<String>(locale),
            localeTag: locale,
            initialLocation: '/base64/encode',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(
              locale == 'en' ? 'Base64 encode' : 'Codificar em Base64',
            ),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'GivenEncodedBase64Result_WhenBothLocalesRender_ThenAccessibilityGuidelinesPass',
    (tester) async {
      for (final locale in <String>['en', 'pt-BR']) {
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<String>('guidelines-$locale'),
            localeTag: locale,
            initialLocation: '/base64/encode',
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('base64-encode-input')),
          'Hello',
        );
        await tester.tap(find.byKey(const Key('base64-encode-submit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('base64-encode-result')), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    },
  );

  testWidgets(
    'GivenBase64DecodeHomeAction_WhenOpened_ThenUtf8TextDecodesWithBoundedSemantics',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('open-base64-decode')));
      await tester.tap(find.byKey(const Key('open-base64-decode')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'T2zDoQ==',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Olá'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('base64-decode-result-semantics')),
      );
      expect(semantics.properties.role, SemanticsRole.region);
      expect(
        semantics.properties.value,
        contains('Base64 decoding succeeded.'),
      );
      expect(semantics.properties.value, contains('Input characters: 8'));
      expect(semantics.properties.value, contains('Output bytes: 4'));
      expect(semantics.properties.value, isNot(contains('Olá')));
    },
  );

  testWidgets(
    'GivenFileClipboardAndEmptyText_WhenSourcesChange_ThenTransfersStayExact',
    (tester) async {
      String? copied;
      String? savedName;
      List<int>? savedBytes;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeFilePicker: () async => utf8.encode('AP8='),
          base64DecodeClipboardReader: () async => 'SGVsbG8=',
          base64DecodeClipboardWriter: (value) async => copied = value,
          base64DecodeFileSaver: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return true;
          },
          base64DecodePreviewDecoder: (_, {required mediaType}) async => null,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('base64-decode-file')));
      await tester.pumpAndSettle();
      expect(find.text('Input characters: 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Output bytes: 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(savedName, 'chimera-decoded.bin');
      expect(savedBytes, <int>[0, 255]);
      expect(find.byKey(const Key('base64-decode-copy')), findsNothing);

      await tester.tap(find.byKey(const Key('base64-decode-paste')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('base64-decode-file-summary')), findsNothing);
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      await tester.tap(find.byKey(const Key('base64-decode-mode-text')));
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'Hello');
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(savedName, 'chimera-decoded.txt');
      expect(savedBytes, utf8.encode('Hello'));

      await tester.enterText(find.byKey(const Key('base64-decode-input')), '');
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('base64-decode-result')),
            )
            .data,
        '',
      );
    },
  );

  testWidgets(
    'GivenRenderedImageCandidate_WhenSourceModeOrRouteChanges_ThenOwnedPreviewIsDisposed',
    (tester) async {
      final images = <_RecordingPreview>[];
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: (_, {required mediaType}) async {
            final preview = await _RecordingPreview.create(mediaType);
            images.add(preview);
            return preview;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(RawImage), findsOneWidget);
      expect(find.text('Image preview available.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'AP8=',
      );
      await tester.pump();
      expect(images.single.disposeCount, 1);
      expect(find.byType(RawImage), findsNothing);

      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(images, hasLength(2));
      expect(images.last.disposeCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(images.last.disposeCount, 1);
    },
  );

  testWidgets(
    'GivenRejectedCorruptOrFailingPreview_WhenDecoded_ThenBytesRemainSaveableWithBinFallback',
    (tester) async {
      for (final failure in <Object?>[
        null,
        Exception('private decoder detail'),
        OutOfMemoryError(),
      ]) {
        String? savedName;
        List<int>? savedBytes;
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<Object?>(failure),
            localeTag: 'en',
            initialLocation: '/base64/decode',
            base64DecodePreviewDecoder: (_, {required mediaType}) async {
              if (failure != null) throw failure;
              return null;
            },
            base64DecodeFileSaver: (name, bytes) async {
              savedName = name;
              savedBytes = bytes;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
        await tester.enterText(
          find.byKey(const Key('base64-decode-input')),
          'iVBORw0KGgo=',
        );
        await tester.tap(find.byKey(const Key('base64-decode-submit')));
        await tester.pumpAndSettle();

        expect(find.text('Image preview unavailable.'), findsOneWidget);
        expect(find.textContaining('private decoder detail'), findsNothing);
        expect(find.text('Output bytes: 8'), findsOneWidget);
        await tester.tap(find.byKey(const Key('base64-decode-save')));
        await tester.pumpAndSettle();
        expect(savedName, 'chimera-decoded.bin');
        expect(savedBytes, base64.decode('iVBORw0KGgo='));
      }
    },
  );

  testWidgets(
    'GivenStalePreviewCompletion_WhenSourceChanges_ThenLateOwnedImageIsDisposed',
    (tester) async {
      final completed = Completer<Base64DecodePreview?>();
      final preview = await _RecordingPreview.create('image/png');
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: (_, {required mediaType}) =>
              completed.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .enabled,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());
      completed.complete(preview);
      await tester.pump();
      expect(preview.disposeCount, 1);
    },
  );

  testWidgets(
    'GivenOwnedPreview_WhenReplacedModeChangesOrLoadFails_ThenItIsDisposedOnce',
    (tester) async {
      final previews = <_RecordingPreview>[];
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeFilePicker: () async => throw Exception('private path'),
          base64DecodePreviewDecoder: (_, {required mediaType}) async {
            final preview = await _RecordingPreview.create(mediaType);
            previews.add(preview);
            return preview;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );

      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(previews, hasLength(1));
      expect(previews[0].disposeCount, 0);

      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(previews, hasLength(2));
      expect(previews[0].disposeCount, 1);
      expect(previews[1].disposeCount, 0);

      await tester.tap(find.byKey(const Key('base64-decode-mode-text')));
      await tester.pump();
      expect(previews[1].disposeCount, 1);

      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(previews, hasLength(3));
      await tester.tap(find.byKey(const Key('base64-decode-file')));
      await tester.pumpAndSettle();
      expect(previews[2].disposeCount, 1);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('The input file could not be read.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenConfirmedImageTypes_WhenSaved_ThenExactBytesUseConfirmedExtensions',
    (tester) async {
      const extensions = <String, String>{
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/gif': 'gif',
        'image/webp': 'webp',
      };
      for (final MapEntry(:key, :value) in extensions.entries) {
        String? savedName;
        List<int>? savedBytes;
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<String>(key),
            localeTag: 'en',
            initialLocation: '/base64/decode',
            base64DecodePreviewDecoder: (_, {required mediaType}) =>
                _RecordingPreview.create(mediaType),
            base64DecodeFileSaver: (name, bytes) async {
              savedName = name;
              savedBytes = bytes;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
        await tester.enterText(
          find.byKey(const Key('base64-decode-input')),
          _validBase64ImageFixtures[key]!,
        );
        await tester.tap(find.byKey(const Key('base64-decode-submit')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
        await tester.tap(find.byKey(const Key('base64-decode-save')));
        await tester.pumpAndSettle();

        expect(savedName, 'chimera-decoded.$value', reason: key);
        expect(
          savedBytes,
          base64.decode(_validBase64ImageFixtures[key]!),
          reason: key,
        );
      }
    },
  );

  testWidgets(
    'GivenSharedImageCandidateType_WhenRendererDisagreesOrBytesAreUnsupported_ThenOnlyCoreTypeDrivesPreviewAndExtension',
    (tester) async {
      var previewCalls = 0;
      String? receivedMediaType;
      String? savedName;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: (_, {required mediaType}) async {
            previewCalls++;
            receivedMediaType = mediaType;
            return _RecordingPreview.create('image/jpeg');
          },
          base64DecodeFileSaver: (name, _) async {
            savedName = name;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(previewCalls, 1);
      expect(receivedMediaType, 'image/png');
      expect(find.byType(RawImage), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(savedName, 'chimera-decoded.png');

      var unsupportedPreviewCalls = 0;
      await tester.pumpWidget(
        ChimeraApp(
          key: const ValueKey<String>('unsupported-image-bytes'),
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: (_, {required mediaType}) async {
            unsupportedPreviewCalls++;
            return _RecordingPreview.create('image/png');
          },
          base64DecodeFileSaver: (name, _) async {
            savedName = name;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'AP8=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(unsupportedPreviewCalls, 0);
      expect(find.byType(RawImage), findsNothing);
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(savedName, 'chimera-decoded.bin');
    },
  );

  testWidgets(
    'GivenCopyOrSaveFailure_WhenActionCompletes_ThenStaleOutputAndPreviewClear',
    (tester) async {
      final preview = await _RecordingPreview.create('image/png');
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: (_, {required mediaType}) async =>
              preview,
          base64DecodeFileSaver: (_, _) async => throw Exception('private'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('The decoded bytes could not be saved.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(preview.disposeCount, 1);
      expect(find.textContaining('private'), findsNothing);

      await tester.pumpWidget(
        ChimeraApp(
          key: const ValueKey<String>('copy-failure'),
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeClipboardWriter: (_) async => throw OutOfMemoryError(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'SGk=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-copy')));
      await tester.pumpAndSettle();

      expect(
        find.text('Base64 decoding exceeded its resource limit.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'GivenMalformedOrResourceBoundInput_WhenDecoded_ThenLocalizedFailureIsRedacted',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/base64/decode'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'private-invalid%',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('The Base64 decoding request is invalid.'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('base64-decode-error'))).data,
        isNot(contains('private-invalid')),
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);

      await tester.pumpWidget(
        const ChimeraApp(
          key: ValueKey<String>('resource-limit'),
          localeTag: 'pt-BR',
          initialLocation: '/base64/decode',
          base64DecodeService: Base64DecodeService(
            decoder: Base64ByteDecoder(maxInputCharacters: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'SGVsbG8=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('A decodificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
    },
  );

  testWidgets(
    'GivenKeyboardTraversal_WhenDecodeCompletes_ThenResultCopyAndSaveFollow',
    (tester) async {
      String? copied;
      String? saved;
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodeFilePicker: () async => utf8.encode('QQ=='),
          base64DecodeClipboardReader: () async => 'Qg==',
          base64DecodeClipboardWriter: (value) async => copied = value,
          base64DecodeFileSaver: (name, bytes) async {
            saved = '$name:${utf8.decode(bytes)}';
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Input characters: 4'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .controller!
            .text,
        'Qg==',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'Base64 decoded result',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, 'B');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(saved, 'chimera-decoded.txt:B');
    },
  );

  testWidgets(
    'GivenDecodedInvalidUtf8_WhenTextModeRuns_ThenFailureIsRedactedAndBusyResets',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/base64/decode'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        '/w==',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('The Base64 decoding request is invalid.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('base64-decode-error'))).data,
        isNot(contains('/w==')),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'GivenDecodeAdapterFailures_WhenActionsRun_ThenLocalizedErrorsClearBusyState',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          localeTag: 'pt-BR',
          initialLocation: '/base64/decode',
          base64DecodeFilePicker: () async => throw Exception('path'),
          base64DecodeClipboardReader: () async => throw OutOfMemoryError(),
          base64DecodeClipboardWriter: (_) async => throw Exception('secret'),
          base64DecodeFileSaver: (_, _) async => throw OutOfMemoryError(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-file')));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível ler o arquivo de entrada.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('base64-decode-paste')));
      await tester.pumpAndSettle();
      expect(
        find.text('A decodificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .enabled,
        isTrue,
      );

      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'SGk=',
      );
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-copy')));
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível gravar na área de transferência.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      expect(find.textContaining('secret'), findsNothing);

      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('A decodificação Base64 excedeu o limite de recursos.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('base64-decode-result')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('base64-decode-input')))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'GivenNarrowDecodeViewport_WhenBothLocalesUseLargeText_ThenContentIsAccessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final locale in <String>['en', 'pt-BR']) {
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<String>('decode-$locale'),
            localeTag: locale,
            initialLocation: '/base64/decode',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    },
  );

  testWidgets(
    'GivenRealImageFixtures_WhenDecodedInPage_ThenPreviewSemanticsAndExactSaveMatch',
    (tester) async {
      late Completer<void> previewFinished;
      Future<Base64DecodePreview?> realPreviewDecoder(
        Uint8List bytes, {
        required String mediaType,
      }) async {
        Base64DecodePreview? preview;
        Object? decodeError;
        StackTrace? decodeStackTrace;
        try {
          await tester.runAsync(() async {
            try {
              preview = await decodeBase64Preview(bytes, mediaType: mediaType);
            } on Object catch (error, stackTrace) {
              decodeError = error;
              decodeStackTrace = stackTrace;
            }
          });
          if (decodeError case final error?) {
            Error.throwWithStackTrace(error, decodeStackTrace!);
          }
          return preview;
        } finally {
          previewFinished.complete();
        }
      }

      const extensions = <String, String>{
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'image/gif': 'gif',
        'image/webp': 'webp',
      };
      for (final MapEntry(:key, :value) in _validBase64ImageFixtures.entries) {
        String? savedName;
        List<int>? savedBytes;
        await tester.pumpWidget(
          ChimeraApp(
            key: ValueKey<String>('real-$key'),
            localeTag: 'en',
            initialLocation: '/base64/decode',
            base64DecodePreviewDecoder: realPreviewDecoder,
            base64DecodeFileSaver: (name, bytes) async {
              savedName = name;
              savedBytes = bytes;
              return true;
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
        await tester.enterText(
          find.byKey(const Key('base64-decode-input')),
          value,
        );
        previewFinished = Completer<void>();
        await tester.tap(find.byKey(const Key('base64-decode-submit')));
        await tester.pump();
        await previewFinished.future;
        await tester.pumpAndSettle();

        expect(find.byType(RawImage), findsOneWidget, reason: key);
        expect(find.text('Image preview available.'), findsOneWidget);
        expect(
          tester
              .widget<Semantics>(
                find.byKey(const Key('base64-decode-result-semantics')),
              )
              .properties
              .value,
          contains('Image preview available.'),
          reason: key,
        );
        await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
        await tester.tap(find.byKey(const Key('base64-decode-save')));
        await tester.pumpAndSettle();
        expect(savedName, 'chimera-decoded.${extensions[key]}', reason: key);
        expect(savedBytes, base64.decode(value), reason: key);
      }

      String? fallbackName;
      List<int>? fallbackBytes;
      await tester.pumpWidget(
        ChimeraApp(
          key: const ValueKey<String>('real-corrupt-png'),
          localeTag: 'en',
          initialLocation: '/base64/decode',
          base64DecodePreviewDecoder: realPreviewDecoder,
          base64DecodeFileSaver: (name, bytes) async {
            fallbackName = name;
            fallbackBytes = bytes;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('base64-decode-mode-binary')));
      await tester.enterText(
        find.byKey(const Key('base64-decode-input')),
        'iVBORw0KGgo=',
      );
      previewFinished = Completer<void>();
      await tester.tap(find.byKey(const Key('base64-decode-submit')));
      await tester.pump();
      await previewFinished.future;
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('Image preview unavailable.'), findsOneWidget);
      expect(find.text('Output bytes: 8'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('base64-decode-save')));
      await tester.tap(find.byKey(const Key('base64-decode-save')));
      await tester.pumpAndSettle();
      expect(fallbackName, 'chimera-decoded.bin');
      expect(fallbackBytes, base64.decode('iVBORw0KGgo='));
    },
  );

  testWidgets(
    'GivenValidPngJpegGifAndWebpFixtures_WhenPreviewed_ThenRendererOwnsEachImage',
    (tester) async {
      await tester.runAsync(() async {
        for (final MapEntry(:key, :value)
            in _validBase64ImageFixtures.entries) {
          final Base64DecodePreview? preview;
          try {
            preview = await decodeBase64Preview(
              base64.decode(value),
              mediaType: key,
            );
          } on Object catch (error) {
            throw StateError('$key: $error');
          }
          expect(preview, isNotNull, reason: key);
          expect(preview!.mediaType, key);
          expect(preview.image.width, 1);
          expect(preview.image.height, 1);
          preview.dispose();
        }
      });
    },
  );
}

const _validBase64ImageFixtures = <String, String>{
  'image/png': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'image/jpeg': '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EH//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EH//2Q==',
  'image/gif': 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
  'image/webp': 'UklGRjwAAABXRUJQVlA4IDAAAADQAQCdASoBAAEAAgA0JaACdLoB+AADsAD+8Oj3/yC5YXXI1/8gP+QH/ID/+PIAAAA=',
};

final class _RecordingPreview implements Base64DecodePreview {
  _RecordingPreview._(this.image, this.mediaType);

  static Future<_RecordingPreview> create(String mediaType) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    return _RecordingPreview._(image, mediaType);
  }

  @override
  final ui.Image image;

  @override
  final String mediaType;

  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    image.dispose();
  }
}
