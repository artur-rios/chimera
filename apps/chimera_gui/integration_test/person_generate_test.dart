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
    'GivenProductionService_WhenPersonGeneratedNativelyOffline_ThenSyntheticContractHolds',
    (tester) async {
      final network = _Offline();
      final previous = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      await tester.pumpWidget(
        const ChimeraApp(initialLocation: '/person/generate'),
      );
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pumpAndSettle();

      final text = tester
          .widget<SelectableText>(find.byKey(const Key('person-output')))
          .data!;
      expect(text, contains('Person 1'));
      expect(text, contains('@example.com'));
      expect(text, contains('SSN:'));
      expect(
        find.text(
          'Synthetic person test data - not a real identity or proof of issuance',
        ),
        findsOneWidget,
      );
      expect(network.attempts, 0);
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}BrazilBatch_WhenGeneratedOffline_ThenExactCopySaveAndDiscard',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        final directory = await Directory.systemTemp.createTemp(
          'person-native-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/people.txt');
        await target.writeAsString('previous');
        String? copied;
        await tester.pumpWidget(
          ChimeraApp(
            localeTag: locale,
            initialLocation: '/person/generate',
            personService: _service(_brPerson()),
            personClipboardWriter: (value) async => copied = value,
            personFileSaver: (name, bytes, mime) => saveLocalFile(
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
          'person-locale',
          locale == 'en' ? 'Brazil' : 'Brasil',
        );
        await tester.enterText(find.byKey(const Key('person-count')), '2');
        await tester.tap(find.byKey(const Key('person-generate')));
        await tester.pumpAndSettle();
        final body = tester
            .widget<SelectableText>(find.byKey(const Key('person-output')))
            .data!;
        expect(body, contains('Ana Silva'));
        expect(body, contains('CPF: 280.012.389-38'));
        expect(body, contains('CIN: 280.012.389-38'));
        final label = locale == 'en'
            ? 'Synthetic person test data - not a real identity or proof of issuance'
            : 'Dados sintéticos de pessoa - não são identidade real nem comprovam emissão';
        final expected = '$label\n$body';
        await tester.ensureVisible(find.byKey(const Key('person-copy')));
        await tester.tap(find.byKey(const Key('person-copy')));
        await tester.pumpAndSettle();
        expect(copied, expected);
        await tester.ensureVisible(find.byKey(const Key('person-save')));
        await tester.tap(find.byKey(const Key('person-save')));
        await tester.pumpAndSettle();
        expect(await target.readAsBytes(), utf8.encode(expected));
        expect(directory.listSync(), hasLength(1));
        await tester.ensureVisible(find.byKey(const Key('person-count')));
        await tester.tap(find.byKey(const Key('person-count')));
        tester.testTextInput.enterText('3');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('person-output')), findsNothing);
        expect(network.attempts, 0);
      },
    );
  }

  for (final failure in ['validation', 'processing']) {
    testWidgets(
      'Given${failure}Failure_WhenGeneratedOffline_ThenNoPartialPerson',
      (tester) async {
        final network = _Offline();
        final previous = HttpOverrides.current;
        HttpOverrides.global = network;
        addTearDown(() => HttpOverrides.global = previous);
        var attempts = 0;
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/person/generate',
            personService: failure == 'processing'
                ? PersonService(
                    generator: PersonGenerator.forTesting(
                      candidate: (_, _) => ++attempts == 1
                          ? _usPerson()
                          : _usPerson(phone: '+1 (212) 555-0100'),
                      today: () => DateTime.utc(2026, 10, 20),
                    ),
                  )
                : _service(_usPerson()),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('person-count')),
          failure == 'validation' ? '0' : '2',
        );
        await tester.tap(find.byKey(const Key('person-generate')));
        await tester.pumpAndSettle();
        if (failure == 'processing') expect(attempts, 33);
        expect(find.byKey(const Key('person-error')), findsOneWidget);
        expect(find.byKey(const Key('person-output')), findsNothing);
        expect(find.textContaining('Avery'), findsNothing);
        expect(network.attempts, 0);
      },
    );
  }
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

PersonService _service(SyntheticPerson person) => PersonService(
  generator: PersonGenerator.forTesting(
    candidate: (_, _) => person,
    today: () => DateTime.utc(2026, 10, 20),
  ),
);

SyntheticPerson _usPerson({String phone = '+1 (415) 555-0100'}) =>
    SyntheticPerson(
      locale: PersonLocale.us,
      givenName: 'Avery',
      familyName: 'Reed',
      birthDate: DateTime.utc(1990, 6, 15),
      address: const PersonAddress(
        street: '100 Example Avenue',
        city: 'San Francisco',
        region: 'CA',
        postalCode: '94105',
        countryCode: 'US',
      ),
      phone: phone,
      email: 'avery.reed01@example.com',
      identifiers: const [
        PersonIdentifier(type: IdentityDocumentType.ssn, value: '219-09-9999'),
      ],
    );

SyntheticPerson _brPerson() => SyntheticPerson(
  locale: PersonLocale.br,
  givenName: 'Ana',
  familyName: 'Silva',
  birthDate: DateTime.utc(1992, 2, 29),
  address: const PersonAddress(
    street: 'Rua Exemplo, 100',
    city: 'São Paulo',
    region: 'SP',
    postalCode: '01000-000',
    countryCode: 'BR',
  ),
  phone: '+55 (11) 90000-0000',
  email: 'ana.silva01@example.com',
  identifiers: const [
    PersonIdentifier(type: IdentityDocumentType.cpf, value: '280.012.389-38'),
    PersonIdentifier(type: IdentityDocumentType.cin, value: '280.012.389-38'),
  ],
);

final class _Offline extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Must stay offline');
  }
}
