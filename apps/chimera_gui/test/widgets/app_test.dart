import 'package:chimera_gui/app.dart';
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
}
