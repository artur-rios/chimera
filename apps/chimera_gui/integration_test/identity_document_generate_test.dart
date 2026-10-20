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
    'GivenProductionService_WhenSsnGeneratedNativelyOffline_ThenSyntheticContractHolds',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/document/generate'),
      );
      await tester.tap(find.byKey(const Key('identity-document-generate')));
      await tester.pumpAndSettle();

      expect(find.text('219-09-9999'), findsOneWidget);
      expect(
        find.text('Synthetic identity test data - not proof of issuance'),
        findsOneWidget,
      );
      expect(network.attempts, 0);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    for (final fixture in const <String, String>{
      'numeric': '11222333000181',
      'alphanumeric': '12ABC34501DE35',
    }.entries) {
      testWidgets(
        'Given${locale}${fixture.key}CnpjBatch_WhenGeneratedOffline_ThenExactCopySaveAndDiscard',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          final directory = await Directory.systemTemp.createTemp(
            'identity-document-native-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final target = File('${directory.path}/documents.txt');
          await target.writeAsString('previous');
          String? copied;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/document/generate',
              identityDocumentService: _service(fixture.value),
              identityDocumentClipboardWriter: (value) async => copied = value,
              identityDocumentFileSaver: (name, bytes, mime) => saveLocalFile(
                name,
                bytes,
                mime,
                extensions: const ['txt'],
                chooseLocation: (_, _) async => target.path,
              ),
            ),
          );
          await _choose(
            tester,
            'identity-document-locale',
            locale == 'en' ? 'Brazil' : 'Brasil',
          );
          await _choose(tester, 'identity-document-type', 'CNPJ');
          await _choose(tester, 'identity-document-cnpj-format', switch ((
            locale,
            fixture.key,
          )) {
            ('en', 'numeric') => 'Numeric',
            ('en', _) => 'Alphanumeric',
            ('pt-BR', 'numeric') => 'Numérico',
            _ => 'Alfanumérico',
          });
          await tester.enterText(
            find.byKey(const Key('identity-document-count')),
            '2',
          );
          await tester.tap(find.byKey(const Key('identity-document-generate')));
          await tester.pumpAndSettle();
          final formatted = fixture.key == 'numeric'
              ? '11.222.333/0001-81'
              : '12.ABC.345/01DE-35';
          final values = '$formatted\n$formatted';
          final label = locale == 'en'
              ? 'Synthetic identity test data - not proof of issuance'
              : 'Dados sintéticos de identidade - não comprovam emissão oficial';
          final expected = '$label\n$values';
          expect(
            tester
                .widget<SelectableText>(
                  find.byKey(const Key('identity-document-output')),
                )
                .data,
            values,
          );
          await tester.ensureVisible(
            find.byKey(const Key('identity-document-copy')),
          );
          await tester.tap(find.byKey(const Key('identity-document-copy')));
          await tester.pumpAndSettle();
          expect(copied, expected);
          await tester.ensureVisible(
            find.byKey(const Key('identity-document-save')),
          );
          await tester.tap(find.byKey(const Key('identity-document-save')));
          await tester.pumpAndSettle();
          expect(await target.readAsBytes(), utf8.encode(expected));
          expect(directory.listSync(), hasLength(1));
          await tester.ensureVisible(
            find.byKey(const Key('identity-document-count')),
          );
          await tester.tap(find.byKey(const Key('identity-document-count')));
          tester.testTextInput.enterText('3');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('identity-document-output')),
            findsNothing,
          );
          expect(network.attempts, 0);
        },
      );
    }

    for (final failure in ['validation', 'processing']) {
      testWidgets(
        'Given${locale}${failure}Failure_WhenGeneratedOffline_ThenLocalizedErrorWithoutPartialValue',
        (tester) async {
          final network = _Offline();
          final previous = HttpOverrides.current;
          HttpOverrides.global = network;
          addTearDown(() => HttpOverrides.global = previous);
          var attempts = 0;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/document/generate',
              identityDocumentService: failure == 'processing'
                  ? IdentityDocumentService(
                      generator: IdentityDocumentGenerator.forTesting(
                        candidate: (_, _, _) =>
                            ++attempts == 1 ? '219099999' : 'PRIVATE INVALID',
                      ),
                    )
                  : _service('219099999'),
            ),
          );
          await tester.enterText(
            find.byKey(const Key('identity-document-count')),
            failure == 'validation' ? '0' : '2',
          );
          await tester.tap(find.byKey(const Key('identity-document-generate')));
          await tester.pumpAndSettle();
          if (failure == 'processing') expect(attempts, 33);
          expect(
            find.byKey(const Key('identity-document-error')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('identity-document-output')),
            findsNothing,
          );
          expect(find.textContaining('PRIVATE'), findsNothing);
          expect(find.textContaining('219-09-9999'), findsNothing);
          expect(network.attempts, 0);
        },
      );
    }
  }
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

IdentityDocumentService _service(String value) => IdentityDocumentService(
  generator: IdentityDocumentGenerator.forTesting(
    candidate: (_, _, _) => value,
  ),
);

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Must stay offline');
  }
}
