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

  UuidService deterministic() {
    var call = 0;
    return UuidService(
      generator: UuidGenerator.forTesting(
        randomBytes: () => List<int>.filled(16, call++),
        nowMilliseconds: () => 0x0123456789ab,
      ),
    );
  }

  testWidgets(
    'GivenProductionService_WhenGeneratedNativelyOffline_ThenSecureV4ContractHolds',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/uuid/generate'),
      );
      await tester.tap(find.byKey(const Key('uuid-generate')));
      await tester.pumpAndSettle();

      final value = tester
          .widget<SelectableText>(find.byKey(const Key('uuid-output')))
          .data!;
      expect(
        value,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(network.attempts, 0);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}V7GuidBatch_WhenGeneratedOffline_ThenExactCopySaveAndDiscard',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp('uuid-native-');
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/identifiers.txt');
        await target.writeAsString('previous');
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/uuid/generate',
            uuidService: deterministic(),
            uuidClipboardWriter: (value) async => copied = value,
            uuidFileSaver: (name, bytes, mime) => saveLocalFile(
              name,
              bytes,
              mime,
              extensions: const ['txt'],
              chooseLocation: (_, _) async => target.path,
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('uuid-version')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                locale == 'en'
                    ? 'Version 7 (time ordered)'
                    : 'Versão 7 (ordenada por tempo)',
              )
              .last,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('uuid-representation')),
        );
        await tester.tap(find.byKey(const Key('uuid-representation')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                locale == 'en'
                    ? 'GUID (uppercase braces)'
                    : 'GUID (maiúsculo entre chaves)',
              )
              .last,
        );
        await tester.enterText(find.byKey(const Key('uuid-count')), '2');
        await tester.tap(find.byKey(const Key('uuid-generate')));
        await tester.pumpAndSettle();
        const expected =
            '{01234567-89AB-7000-8000-000000000000}\n{01234567-89AB-7101-8101-010101010101}';
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('uuid-output')))
              .data,
          expected,
        );
        await tester.ensureVisible(find.byKey(const Key('uuid-copy')));
        await tester.tap(find.byKey(const Key('uuid-copy')));
        await tester.pumpAndSettle();
        expect(copied, expected);
        await tester.ensureVisible(find.byKey(const Key('uuid-save')));
        await tester.tap(find.byKey(const Key('uuid-save')));
        await tester.pumpAndSettle();
        expect(await target.readAsBytes(), utf8.encode(expected));
        expect(directory.listSync(), hasLength(1));
        await tester.ensureVisible(find.byKey(const Key('uuid-count')));
        await tester.tap(find.byKey(const Key('uuid-count')));
        tester.testTextInput.enterText('3');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('uuid-output')), findsNothing);
        expect(network.attempts, 0);
      },
    );

    for (final failure in ['validation', 'processing']) {
      testWidgets(
        'Given$locale${failure}Failure_WhenGeneratedOffline_ThenLocalizedErrorWithoutPartialIdentifiers',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/uuid/generate',
              uuidService: failure == 'processing'
                  ? UuidService(
                      generator: UuidGenerator.forTesting(
                        randomBytes: () => throw StateError('PRIVATE'),
                        nowMilliseconds: () => 0,
                      ),
                    )
                  : deterministic(),
            ),
          );
          if (failure == 'validation') {
            await tester.enterText(find.byKey(const Key('uuid-count')), '0');
          }
          await tester.tap(find.byKey(const Key('uuid-generate')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('uuid-error')), findsOneWidget);
          expect(find.byKey(const Key('uuid-output')), findsNothing);
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(network.attempts, 0);
        },
      );
    }
  }
}

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Must stay offline');
  }
}
