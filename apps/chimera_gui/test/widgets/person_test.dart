import 'dart:async';
import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_gui/app.dart';
import 'package:chimera_gui/person_page.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.utc(2026, 10, 20);

  for (final locale in ['en', 'pt-BR']) {
    testWidgets(
      'Given${locale}Defaults_WhenGeneratedCopiedSaved_ThenExactLabeledPerson',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          String? copied;
          List<int>? saved;
          await tester.pumpWidget(
            ChimeraApp(
              localeTag: locale,
              initialLocation: '/person/generate',
              personService: _service(_usPerson(), today),
              personClipboardWriter: (value) async => copied = value,
              personFileSaver: (name, bytes, mime) async {
                expect(name, 'chimera-synthetic-people.txt');
                expect(mime, 'text/plain; charset=utf-8');
                saved = bytes;
                return true;
              },
            ),
          );

          await tester.tap(find.byKey(const Key('person-generate')));
          await tester.pumpAndSettle();
          final label = const MessageCatalog().lookup(
            locale,
            'person.syntheticLabel',
          );
          expect(find.text(label), findsOneWidget);
          final body = tester
              .widget<SelectableText>(find.byKey(const Key('person-output')))
              .data!;
          expect(body, contains('Avery Reed'));
          expect(body, contains('1990-06-15'));
          expect(body, contains('+1 (415) 555-0100'));
          expect(body, contains('SSN: 219-09-9999'));
          expect(
            tester
                .getSemantics(find.byKey(const Key('person-result')))
                .getSemanticsData()
                .label,
            const MessageCatalog().lookup(locale, 'person.resultLabel'),
          );

          await tester.ensureVisible(find.byKey(const Key('person-copy')));
          await tester.tap(find.byKey(const Key('person-copy')));
          await tester.pumpAndSettle();
          expect(copied, '$label\n$body');
          await tester.ensureVisible(find.byKey(const Key('person-save')));
          await tester.tap(find.byKey(const Key('person-save')));
          await tester.pumpAndSettle();
          expect(saved, utf8.encode('$label\n$body'));
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'GivenBrazilLocaleAndAgeConstraints_WhenGenerated_ThenCoherentFieldsAppear',
    (tester) async {
      final recording = _RecordingService(_success(_brPerson(), 21, 40));
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/person/generate',
          personService: recording,
        ),
      );
      await _choose(tester, 'person-locale', 'Brazil');
      await tester.enterText(find.byKey(const Key('person-min-age')), '21');
      await tester.enterText(find.byKey(const Key('person-max-age')), '40');
      await tester.enterText(find.byKey(const Key('person-count')), '2');
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pumpAndSettle();

      expect(recording.last?.locale, 'br');
      expect(recording.last?.minAge, '21');
      expect(recording.last?.maxAge, '40');
      expect(recording.last?.count, '2');
      final text = tester
          .widget<SelectableText>(find.byKey(const Key('person-output')))
          .data!;
      expect(text, contains('Ana Silva'));
      expect(text, contains('+55 (11) 90000-0000'));
      expect(text, contains('CPF: 280.012.389-38'));
      expect(text, contains('CIN: 280.012.389-38'));
    },
  );

  testWidgets(
    'GivenConfigurationChange_WhenResultExists_ThenEphemeralResultIsDiscarded',
    (tester) async {
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/person/generate',
          personService: _service(_usPerson(), today),
        ),
      );
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-output')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('person-min-age')), '19');
      await tester.pump();
      expect(find.byKey(const Key('person-output')), findsNothing);
    },
  );

  for (final failure in [
    'validation',
    'processing',
    'copy',
    'save',
    'encode',
  ]) {
    testWidgets(
      'Given${failure}Failure_WhenActionRuns_ThenNoPartialPersonOrSecret',
      (tester) async {
        await tester.pumpWidget(
          ChimeraApp(
            initialLocation: '/person/generate',
            personService: failure == 'processing'
                ? PersonService(
                    generator: PersonGenerator.forTesting(
                      candidate: (_, _) => throw StateError('PRIVATE PERSON'),
                      today: () => today,
                    ),
                  )
                : _service(_usPerson(), today),
            personClipboardWriter: (_) async =>
                throw StateError('PRIVATE PERSON'),
            personFileSaver: (_, _, _) async =>
                throw StateError('PRIVATE PERSON'),
            personOutputEncoder: failure == 'encode'
                ? (_) => throw OutOfMemoryError()
                : encodePersonOutput,
          ),
        );
        if (failure == 'validation') {
          await tester.enterText(find.byKey(const Key('person-count')), '0');
        }
        await tester.tap(find.byKey(const Key('person-generate')));
        await tester.pumpAndSettle();
        if (failure == 'copy' || failure == 'save' || failure == 'encode') {
          final action = failure == 'copy' ? 'copy' : 'save';
          await tester.ensureVisible(find.byKey(Key('person-$action')));
          await tester.tap(find.byKey(Key('person-$action')));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('person-error')), findsOneWidget);
        expect(find.byKey(const Key('person-output')), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
      },
    );
  }

  testWidgets(
    'GivenValidFirstPersonThenRetryExhaustion_WhenGenerated_ThenNoPartialValue',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/person/generate',
          personService: PersonService(
            generator: PersonGenerator.forTesting(
              candidate: (_, _) => ++attempts == 1
                  ? _usPerson()
                  : _usPerson(phone: '+1 (212) 555-0100'),
              today: () => today,
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('person-count')), '2');
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pumpAndSettle();
      expect(attempts, 33);
      expect(find.byKey(const Key('person-error')), findsOneWidget);
      expect(find.byKey(const Key('person-output')), findsNothing);
      expect(find.textContaining('Avery'), findsNothing);
    },
  );

  testWidgets(
    'GivenPendingGeneration_WhenConfigurationChanges_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/person/generate', personService: service),
      );
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('person-generate')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('person-count')), '2');
      service.pending.complete(_success(_usPerson()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Avery'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GivenKeyboardSubmission_WhenGenerated_ThenResultReceivesFocus', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/person/generate',
        personService: _service(_usPerson(), today),
      ),
    );
    await tester.enterText(find.byKey(const Key('person-count')), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-output')), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Person result');
  });

  testWidgets('GivenCanceledSave_WhenInvoked_ThenResultRemainsWithoutNotice', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        initialLocation: '/person/generate',
        personService: _service(_usPerson(), today),
        personFileSaver: (_, _, _) async => false,
      ),
    );
    await tester.tap(find.byKey(const Key('person-generate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('person-save')));
    await tester.tap(find.byKey(const Key('person-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-output')), findsOneWidget);
    expect(find.byKey(const Key('person-notice')), findsNothing);
    expect(find.byKey(const Key('person-error')), findsNothing);
  });

  testWidgets(
    'GivenNarrowViewport_WhenPageRendered_ThenScrollableWithoutOverflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChimeraApp(
          initialLocation: '/person/generate',
          personService: _service(_usPerson(), today),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GivenPendingGeneration_WhenDisposed_ThenLateCompletionIsIgnored',
    (tester) async {
      final service = _Pending();
      await tester.pumpWidget(
        ChimeraApp(initialLocation: '/person/generate', personService: service),
      );
      await tester.tap(find.byKey(const Key('person-generate')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      service.pending.complete(_success(_usPerson()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in ['copy', 'save']) {
    for (final invalidation in ['dispose', 'configuration']) {
      testWidgets(
        'GivenPending${action}_When${invalidation}Invalidates_ThenIgnored',
        (tester) async {
          final clipboard = Completer<void>();
          final saver = Completer<bool>();
          await tester.pumpWidget(
            ChimeraApp(
              initialLocation: '/person/generate',
              personService: _service(_usPerson(), today),
              personClipboardWriter: (_) => clipboard.future,
              personFileSaver: (_, _, _) => saver.future,
            ),
          );
          await tester.tap(find.byKey(const Key('person-generate')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(Key('person-$action')));
          await tester.tap(find.byKey(Key('person-$action')));
          await tester.pump();
          if (invalidation == 'dispose') {
            await tester.pumpWidget(const SizedBox());
          } else {
            await tester.ensureVisible(find.byKey(const Key('person-count')));
            await tester.enterText(find.byKey(const Key('person-count')), '2');
          }
          if (action == 'copy') {
            clipboard.complete();
          } else {
            saver.complete(true);
          }
          await tester.pumpAndSettle();
          if (invalidation == 'configuration') {
            expect(find.byKey(const Key('person-output')), findsNothing);
            expect(find.byKey(const Key('person-notice')), findsNothing);
            expect(find.byKey(const Key('person-error')), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('GivenHome_WhenOpened_ThenPersonConfigurationIsAvailable', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp());
    await tester.ensureVisible(find.byKey(const Key('open-person')));
    await tester.tap(find.byKey(const Key('open-person')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-locale')), findsOneWidget);
    expect(find.byKey(const Key('person-min-age')), findsOneWidget);
    expect(find.byKey(const Key('person-max-age')), findsOneWidget);
    expect(find.byKey(const Key('person-count')), findsOneWidget);
  });
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

PersonService _service(SyntheticPerson person, DateTime today) => PersonService(
  generator: PersonGenerator.forTesting(
    candidate: (_, _) => person,
    today: () => today,
  ),
);

ChimeraResult<PersonOutput> _success(
  SyntheticPerson person, [
  int minAge = 18,
  int maxAge = 90,
]) => ChimeraSuccess(
  PersonOutput(
    PersonResult(
      people: [person],
      locale: person.locale,
      minAge: minAge,
      maxAge: maxAge,
      operationDate: DateTime.utc(2026, 10, 20),
    ),
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

final class _Pending
    implements OperationService<PersonOperationRequest, PersonOutput> {
  final pending = Completer<ChimeraResult<PersonOutput>>();

  @override
  Future<ChimeraResult<PersonOutput>> execute(PersonOperationRequest request) =>
      pending.future;
}

final class _RecordingService
    implements OperationService<PersonOperationRequest, PersonOutput> {
  _RecordingService(this.result);

  final ChimeraResult<PersonOutput> result;
  PersonOperationRequest? last;

  @override
  Future<ChimeraResult<PersonOutput>> execute(
    PersonOperationRequest request,
  ) async {
    last = request;
    return result;
  }
}
