import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime.utc(2026, 10, 20);

  test('GivenDefaults_WhenExecuted_ThenStableLabeledUsJsonReturns', () async {
    final result = await PersonService(
      generator: _generator(_usPerson(), today),
    ).execute(const PersonOperationRequest());

    final output = (result as ChimeraSuccess<PersonOutput>).value;
    expect(output.toJson(), {
      'locale': 'us',
      'count': 1,
      'synthetic': true,
      'label': 'synthetic-test-data',
      'constraints': {'minAge': 18, 'maxAge': 90},
      'people': [
        {
          'locale': 'us',
          'givenName': 'Avery',
          'familyName': 'Reed',
          'birthDate': '1990-06-15',
          'address': {
            'street': '100 Example Avenue',
            'city': 'San Francisco',
            'region': 'CA',
            'postalCode': '94105',
            'countryCode': 'US',
          },
          'phone': '+1 (415) 555-0100',
          'email': 'avery.reed01@example.com',
          'identifiers': [
            {'type': 'ssn', 'value': '219-09-9999', 'synthetic': true},
          ],
          'synthetic': true,
        },
      ],
    });
  });

  test(
    'GivenBrazilAndAgeConstraints_WhenExecuted_ThenMappedOutputReturns',
    () async {
      final result =
          await PersonService(generator: _generator(_brPerson(), today))
              .execute(
                const PersonOperationRequest(
                  locale: 'br',
                  minAge: '21',
                  maxAge: '40',
                  count: '2',
                ),
              );

      final output = (result as ChimeraSuccess<PersonOutput>).value;
      expect(output.locale, 'br');
      expect(output.minAge, 21);
      expect(output.maxAge, 40);
      expect(output.count, 2);
      expect(output.people.first.identifiers, [
        const PersonIdentifier(
          type: IdentityDocumentType.cpf,
          value: '280.012.389-38',
        ),
        const PersonIdentifier(
          type: IdentityDocumentType.cin,
          value: '280.012.389-38',
        ),
      ]);
    },
  );

  final invalid = <String, (PersonOperationRequest, String)>{
    'Locale': (
      const PersonOperationRequest(locale: 'ca'),
      'person.invalid-locale',
    ),
    'EmptyMinimumAge': (
      const PersonOperationRequest(minAge: ''),
      'person.invalid-min-age',
    ),
    'SignedMinimumAge': (
      const PersonOperationRequest(minAge: '+18'),
      'person.invalid-min-age',
    ),
    'WhitespaceMaximumAge': (
      const PersonOperationRequest(maxAge: ' 90'),
      'person.invalid-max-age',
    ),
    'MaximumAgeAboveLimit': (
      const PersonOperationRequest(maxAge: '131'),
      'person.invalid-max-age',
    ),
    'ReversedAgeRange': (
      const PersonOperationRequest(minAge: '91', maxAge: '18'),
      'person.invalid-age-range',
    ),
    'EmptyCount': (
      const PersonOperationRequest(count: ''),
      'person.invalid-count',
    ),
    'ZeroCount': (
      const PersonOperationRequest(count: '0'),
      'person.invalid-count',
    ),
    'DecimalCount': (
      const PersonOperationRequest(count: '1.0'),
      'person.invalid-count',
    ),
  };

  for (final entry in invalid.entries) {
    test('GivenInvalid${entry.key}_WhenExecuted_ThenTypedValidation', () async {
      var calls = 0;
      final result = await PersonService(
        generator: PersonGenerator.forTesting(
          candidate: (_, _) {
            calls++;
            return _usPerson();
          },
          today: () => today,
        ),
      ).execute(entry.value.$1);

      final failure = result as ChimeraFailure<PersonOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, entry.value.$2);
      expect(failure.messageKey, 'error.person.validation');
      expect(failure.details, containsPair('field', isA<String>()));
      expect(calls, 0);
    });
  }

  test(
    'GivenCandidateFailure_WhenExecuted_ThenRedactedProcessingFailure',
    () async {
      final result = await PersonService(
        generator: PersonGenerator.forTesting(
          candidate: (_, _) => throw StateError('PRIVATE PERSON'),
          today: () => today,
        ),
      ).execute(const PersonOperationRequest());

      final failure = result as ChimeraFailure<PersonOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'person.source-unavailable');
      expect(failure.messageKey, 'error.person.processing');
      expect(failure.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenInconsistentCandidates_WhenExecuted_ThenGenerationFailure',
    () async {
      final result = await PersonService(
        generator: PersonGenerator.forTesting(
          candidate: (_, _) => _usPerson(phone: '+1 (212) 555-0100'),
          today: () => today,
        ),
      ).execute(const PersonOperationRequest());

      final failure = result as ChimeraFailure<PersonOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'person.generation-failed');
      expect(failure.messageKey, 'error.person.processing');
    },
  );

  test('GivenResourceFailure_WhenExecuted_ThenTypedResourceFailure', () async {
    final result = await PersonService(
      generator: PersonGenerator.forTesting(
        candidate: (_, _) => _usPerson(),
        today: () => today,
        allocate: (_) => throw OutOfMemoryError(),
      ),
    ).execute(const PersonOperationRequest());

    final failure = result as ChimeraFailure<PersonOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'person.resource-limit');
    expect(failure.messageKey, 'error.person.resource');
  });
}

PersonGenerator _generator(SyntheticPerson person, DateTime today) =>
    PersonGenerator.forTesting(candidate: (_, _) => person, today: () => today);

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
