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
}
