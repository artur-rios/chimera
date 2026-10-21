import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_platform/chimera_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenOfflineEnglishApp_WhenPortugueseSelectedAndRestarted_ThenPreferenceIsRestored',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      final gateway = _MemoryPreferenceGateway();

      await tester.pumpWidget(ChimeraApp(preferenceGateway: gateway));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brazilian Portuguese').last);
      await tester.pumpAndSettle();

      expect(find.text('Idioma'), findsOneWidget);
      expect(
        find.text('Portugu\u00eas (Brasil) aplicado e salvo.'),
        findsOneWidget,
      );
      expect(gateway.values[PreferenceKey.language], 'pt-BR');

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
      expect(network.attempts, 0);
    },
  );

  testWidgets(
    'GivenUnavailableStorage_WhenPortugueseSelected_ThenSessionChoiceRemains',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(preferenceGateway: _MemoryPreferenceGateway(fails: true)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brazilian Portuguese').last);
      await tester.pumpAndSettle();

      expect(find.text('Idioma'), findsOneWidget);
      expect(
        find.text(
          'Portugu\u00eas (Brasil) est\u00e1 ativo nesta sess\u00e3o, mas a prefer\u00eancia n\u00e3o foi salva.',
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
    throw StateError('Network access is prohibited while changing language.');
  }
}
