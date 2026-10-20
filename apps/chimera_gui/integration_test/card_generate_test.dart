import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/local_file_save.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GivenProductionService_WhenGeneratedNativelyOffline_ThenSafeVisaContractHolds',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/card/generate'),
      );
      await tester.tap(find.byKey(const Key('card-generate')));
      await tester.pumpAndSettle();

      final value = tester
          .widget<SelectableText>(find.byKey(const Key('card-output')))
          .data!;
      expect(value, isIn(cardTestNumberCatalogue[CardNetwork.visa]!));
      expect(
        find.text('Synthetic test data - not for real transactions'),
        findsOneWidget,
      );
      expect(network.attempts, 0);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}MastercardBatch_WhenGeneratedOffline_ThenExactCopySaveAndDiscard',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp('card-native-');
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/cards.txt');
        await target.writeAsString('previous');
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/card/generate',
            cardService: _service('5555555555554444'),
            cardClipboardWriter: (value) async => copied = value,
            cardFileSaver: (name, bytes, mime) => saveLocalFile(
              name,
              bytes,
              mime,
              extensions: const ['txt'],
              chooseLocation: (_, _) async => target.path,
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('card-network')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mastercard').last);
        await tester.enterText(find.byKey(const Key('card-count')), '2');
        await tester.tap(find.byKey(const Key('card-generate')));
        await tester.pumpAndSettle();
        const values = '5555555555554444\n5555555555554444';
        final label = locale == 'en'
            ? 'Synthetic test data - not for real transactions'
            : 'Dados sintéticos de teste - não usar em transações reais';
        final expected = '$label\n$values';
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('card-output')))
              .data,
          values,
        );
        await tester.ensureVisible(find.byKey(const Key('card-copy')));
        await tester.tap(find.byKey(const Key('card-copy')));
        await tester.pumpAndSettle();
        expect(copied, expected);
        await tester.ensureVisible(find.byKey(const Key('card-save')));
        await tester.tap(find.byKey(const Key('card-save')));
        await tester.pumpAndSettle();
        expect(await target.readAsBytes(), utf8.encode(expected));
        expect(directory.listSync(), hasLength(1));
        await tester.ensureVisible(find.byKey(const Key('card-count')));
        await tester.tap(find.byKey(const Key('card-count')));
        tester.testTextInput.enterText('3');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('card-output')), findsNothing);
        expect(network.attempts, 0);
      },
    );

    for (final failure in ['validation', 'processing']) {
      testWidgets(
        'Given${locale}${failure}Failure_WhenGeneratedOffline_ThenLocalizedErrorWithoutPartialPan',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/card/generate',
              cardService: failure == 'processing'
                  ? CardService(
                      generator: CardGenerator.forTesting(
                        candidate: (_) => throw StateError('PRIVATE PAN'),
                      ),
                    )
                  : _service('4242424242424242'),
            ),
          );
          if (failure == 'validation') {
            await tester.enterText(find.byKey(const Key('card-count')), '0');
          }
          await tester.tap(find.byKey(const Key('card-generate')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('card-error')), findsOneWidget);
          expect(find.byKey(const Key('card-output')), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(network.attempts, 0);
        },
      );
    }
  }
}

CardService _service(String value) =>
    CardService(generator: CardGenerator.forTesting(candidate: (_) => value));

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Must stay offline');
  }
}
