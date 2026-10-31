import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLanguage(
    WidgetTester tester, {
    required PreferenceGateway gateway,
    String locale = 'en',
    Size size = const Size(900, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChimeraApp(localeTag: locale, preferenceGateway: gateway),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectLanguage(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GivenEnglishHome_WhenBrazilianPortugueseSelected_ThenWholeShellAndRouteLocalize',
    (tester) async {
      final gateway = _MemoryPreferenceGateway();
      await pumpLanguage(tester, gateway: gateway);

      expect(find.text('Language'), findsOneWidget);
      await selectLanguage(tester, 'Brazilian Portuguese');

      expect(find.text('Idioma'), findsOneWidget);
      expect(find.text('Apar\u00eancia'), findsOneWidget);
      expect(gateway.values[PreferenceKey.language], 'pt-BR');
      expect(
        find.text('Portugu\u00eas (Brasil) aplicado e salvo.'),
        findsOneWidget,
      );

      final open = find.text('Codificar HTML');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(find.text('Codificar HTML', skipOffstage: false), findsWidgets);
      expect(find.text('Texto para codificar'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenStoredPortuguese_WhenAppStartsAgain_ThenPortugueseIsRestored',
    (tester) async {
      final gateway = _MemoryPreferenceGateway();
      await pumpLanguage(tester, gateway: gateway);
      await selectLanguage(tester, 'Brazilian Portuguese');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(ChimeraApp(preferenceGateway: gateway));
      await tester.pumpAndSettle();

      expect(find.text('Idioma'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byKey(const Key('language-selector')),
            )
            .selected,
        <String>{'pt-BR'},
      );
    },
  );

  testWidgets(
    'GivenKeyboardFocus_WhenLanguageChanges_ThenFocusRemainsOnSelectedOption',
    (tester) async {
      await pumpLanguage(tester, gateway: _MemoryPreferenceGateway());
      final portugueseLabel = find.text('Brazilian Portuguese').last;
      await tester.ensureVisible(portugueseLabel);
      await tester.pumpAndSettle();
      final focus = tester.widget<Focus>(
        find.ancestor(of: portugueseLabel, matching: find.byType(Focus)).first,
      );
      focus.focusNode?.requestFocus();
      await tester.pump();
      final selectedFocus = FocusManager.instance.primaryFocus;

      await tester.tap(portugueseLabel);
      await tester.pumpAndSettle();

      expect(find.text('Idioma'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(selectedFocus));
      expect(selectedFocus?.hasFocus, isTrue);
      expect(
        find.text('Portugu\u00eas (Brasil) aplicado e salvo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenLanguageWriteFailure_WhenPortugueseSelected_ThenSessionLanguageAndLocalizedStatusRemain',
    (tester) async {
      final gateway = _MemoryPreferenceGateway(
        failingWrite: PreferenceKey.language,
      );
      await pumpLanguage(tester, gateway: gateway);

      await selectLanguage(tester, 'Brazilian Portuguese');

      expect(find.text('Idioma'), findsOneWidget);
      expect(
        find.text(
          'Portugu\u00eas (Brasil) est\u00e1 ativo nesta sess\u00e3o, mas a prefer\u00eancia n\u00e3o foi salva.',
        ),
        findsOneWidget,
      );
      expect(gateway.values[PreferenceKey.language], isNull);
    },
  );

  testWidgets(
    'GivenInvalidStoredLanguage_WhenAppStarts_ThenEnglishDefaultDoesNotFail',
    (tester) async {
      final gateway = _MemoryPreferenceGateway(
        values: <PreferenceKey, String>{PreferenceKey.language: 'fr'},
      );

      await pumpLanguage(tester, gateway: gateway);

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenNarrowLargeText_WhenLanguageRendered_ThenSelectorHasNoOverflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLanguage(
        tester,
        gateway: _MemoryPreferenceGateway(),
        size: const Size(320, 800),
      );

      final selector = find.byKey(const Key('language-selector'));
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Brazilian Portuguese'), findsOneWidget);
    },
  );
}

final class _MemoryPreferenceGateway implements PreferenceGateway {
  _MemoryPreferenceGateway({
    Map<PreferenceKey, String>? values,
    this.failingWrite,
  }) : values = values ?? <PreferenceKey, String>{};

  final Map<PreferenceKey, String> values;
  final PreferenceKey? failingWrite;

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async =>
      ChimeraSuccess<String?>(values[key]);

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    if (key == failingWrite) {
      return const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'write_failed',
        messageKey: 'error.preference.access',
      );
    }
    values[key] = value;
    return const ChimeraSuccess<void>(null);
  }
}
