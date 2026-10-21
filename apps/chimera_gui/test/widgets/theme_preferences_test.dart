import 'dart:async';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTheme(
    WidgetTester tester, {
    String locale = 'en',
    required PreferenceGateway gateway,
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

  Future<void> selectTheme(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('theme-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(const Key('theme-selector'))))
          .brightness;

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}_WhenHomeOpens_ThenLocalizedLightAndDarkSelectorRenders',
      (tester) async {
        await pumpTheme(
          tester,
          locale: locale,
          gateway: _FakePreferenceGateway(),
        );

        expect(
          find.text(locale == 'en' ? 'Appearance' : 'Aparência'),
          findsOneWidget,
        );
        expect(find.text(locale == 'en' ? 'Theme' : 'Tema'), findsOneWidget);
        expect(brightness(tester), Brightness.light);
      },
    );

    testWidgets(
      'Given${locale}WriteFailure_WhenDarkSelected_ThenDarkAppliesAndLocalizedSessionStatusAppears',
      (tester) async {
        final gateway = _FakePreferenceGateway(writeFails: true);
        await pumpTheme(tester, locale: locale, gateway: gateway);

        await selectTheme(tester, locale == 'en' ? 'Dark' : 'Escuro');
        await tester.pumpAndSettle();

        expect(brightness(tester), Brightness.dark);
        expect(gateway.writes, <String>['dark']);
        expect(
          find.text(
            locale == 'en'
                ? 'Dark theme is active for this session, but the preference was not saved.'
                : 'O tema escuro está ativo nesta sessão, mas a preferência não foi salva.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'GivenPendingWrite_WhenDarkSelected_ThenThemeAppliesBeforePersistenceCompletes',
    (tester) async {
      final write = Completer<ChimeraResult<void>>();
      final gateway = _FakePreferenceGateway(pendingWrite: write);
      await pumpTheme(tester, gateway: gateway);

      await selectTheme(tester, 'Dark');

      expect(brightness(tester), Brightness.dark);
      expect(find.text('Applying and saving theme…'), findsOneWidget);
      write.complete(const ChimeraSuccess<void>(null));
      await tester.pumpAndSettle();
      expect(find.text('Dark theme applied and saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenStoredDarkTheme_WhenAppStartsAgain_ThenDarkThemeIsRestored',
    (tester) async {
      final gateway = _FakePreferenceGateway();
      await pumpTheme(tester, gateway: gateway);
      await selectTheme(tester, 'Dark');
      await tester.pumpAndSettle();
      expect(gateway.stored, 'dark');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(ChimeraApp(preferenceGateway: gateway));
      await tester.pumpAndSettle();

      expect(brightness(tester), Brightness.dark);
      expect(
        tester
            .widget<DropdownButtonFormField<ThemeMode>>(
              find.byKey(const Key('theme-selector')),
            )
            .initialValue,
        ThemeMode.dark,
      );
    },
  );

  testWidgets(
    'GivenInvalidStoredTheme_WhenAppStarts_ThenLightDefaultDoesNotFail',
    (tester) async {
      await pumpTheme(
        tester,
        gateway: _FakePreferenceGateway(stored: 'future-theme'),
      );

      expect(brightness(tester), Brightness.light);
      expect(find.byKey(const Key('theme-selector')), findsOneWidget);
      expect(find.byKey(const Key('theme-status')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenUnavailableStorage_WhenAppStarts_ThenLightAndSessionOnlyStatusRender',
    (tester) async {
      await pumpTheme(tester, gateway: _FakePreferenceGateway(readFails: true));

      expect(brightness(tester), Brightness.light);
      expect(
        find.text(
          'Light theme is active for this session, but the preference was not saved.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GivenNarrowLargeText_WhenThemeRendered_ThenSelectorIsAccessibleWithoutOverflow',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTheme(
        tester,
        gateway: _FakePreferenceGateway(),
        size: const Size(320, 800),
      );

      final selector = find.byKey(const Key('theme-selector'));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(selector).getSemanticsData().label,
        contains('Theme'),
      );
      semantics.dispose();
    },
  );
}

final class _FakePreferenceGateway implements PreferenceGateway {
  _FakePreferenceGateway({
    this.stored,
    this.readFails = false,
    this.writeFails = false,
    this.pendingWrite,
  });

  String? stored;
  final bool readFails;
  final bool writeFails;
  final Completer<ChimeraResult<void>>? pendingWrite;
  final List<String> writes = <String>[];

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async {
    if (readFails) {
      return const ChimeraFailure<String?>(
        kind: FailureKind.access,
        code: 'read_failed',
        messageKey: 'error.preference.access',
      );
    }
    return ChimeraSuccess<String?>(stored);
  }

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    writes.add(value);
    if (pendingWrite case final pending?) {
      final result = await pending.future;
      if (result is ChimeraSuccess<void>) stored = value;
      return result;
    }
    if (writeFails) {
      return const ChimeraFailure<void>(
        kind: FailureKind.access,
        code: 'write_failed',
        messageKey: 'error.preference.access',
      );
    }
    stored = value;
    return const ChimeraSuccess<void>(null);
  }
}
