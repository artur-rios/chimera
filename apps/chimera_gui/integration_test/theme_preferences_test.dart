import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}ThemeSelection_WhenAppRestarts_ThenDarkThemeIsRestoredOffline',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final gateway = _MemoryPreferenceGateway();

        await tester.pumpWidget(
          ChimeraApp(localeTag: locale, preferenceGateway: gateway),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'en' ? 'Dark' : 'Escuro').last);
        await tester.pumpAndSettle();

        expect(
          Theme.of(tester.element(find.byKey(const Key('theme-selector'))))
              .brightness,
          Brightness.dark,
        );
        expect(gateway.values, <PreferenceKey, String>{
          PreferenceKey.theme: 'dark',
        });
        expect(
          find.text(
            locale == 'en'
                ? 'Dark theme applied and saved.'
                : 'Tema escuro aplicado e salvo.',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          ChimeraApp(localeTag: locale, preferenceGateway: gateway),
        );
        await tester.pumpAndSettle();

        expect(
          Theme.of(tester.element(find.byKey(const Key('theme-selector'))))
              .brightness,
          Brightness.dark,
        );
        expect(network.attempts, 0);
      },
    );
  }

  testWidgets(
    'GivenUnavailableStorage_WhenThemeSelected_ThenSessionChoiceRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(preferenceGateway: _MemoryPreferenceGateway(fails: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byKey(const Key('theme-selector'))))
            .brightness,
        Brightness.dark,
      );
      expect(
        find.text(
          'Dark theme is active for this session, but the preference was not saved.',
        ),
        findsOneWidget,
      );
    },
  );
}

final class _MemoryPreferenceGateway implements PreferenceGateway {
  _MemoryPreferenceGateway({this.fails = false});

  final bool fails;
  final Map<PreferenceKey, String> values = <PreferenceKey, String>{};

  @override
  Future<ChimeraResult<String?>> read(PreferenceKey key) async {
    if (fails) return _failure<String?>();
    return ChimeraSuccess<String?>(values[key]);
  }

  @override
  Future<ChimeraResult<void>> write(PreferenceKey key, String value) async {
    if (fails) return _failure<void>();
    values[key] = value;
    return const ChimeraSuccess<void>(null);
  }

  ChimeraFailure<T> _failure<T>() => ChimeraFailure<T>(
    kind: FailureKind.access,
    code: 'preference_unavailable',
    messageKey: 'error.preference.access',
  );
}

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network access is prohibited while changing theme.');
  }
}
