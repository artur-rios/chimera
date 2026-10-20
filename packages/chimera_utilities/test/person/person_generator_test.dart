import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime.utc(2026, 10, 20);
  final validator = PersonValidator();

  for (final entry in <String, (PersonRequest, SyntheticPerson)>{
    'Us': (const PersonRequest(locale: PersonLocale.us), _usPerson()),
    'Brazil': (const PersonRequest(locale: PersonLocale.br), _brPerson()),
  }.entries) {
    test('GivenConsistent${entry.key}Person_WhenValidated_ThenAccepted', () {
      expect(
        validator.isValid(
          person: entry.value.$2,
          request: entry.value.$1,
          operationDate: today,
        ),
        isTrue,
      );
    });

    test(
      'GivenConsistent${entry.key}Candidate_WhenGenerated_ThenImmutableLabeledBatchReturns',
      () {
        final result = PersonGenerator.forTesting(
          candidate: (_, _) => entry.value.$2,
          today: () => today,
        ).generate(entry.value.$1.copyWith(count: 2));

        expect(result.people, hasLength(2));
        expect(result.locale, entry.value.$1.locale);
        expect(result.minAge, 18);
        expect(result.maxAge, 90);
        expect(result.synthetic, isTrue);
        expect(result.people.every((person) => person.synthetic), isTrue);
        expect(() => result.people.add(entry.value.$2), throwsUnsupportedError);
        expect(
          () => result.people.first.identifiers.add(
            const PersonIdentifier(
              type: IdentityDocumentType.ssn,
              value: 'PRIVATE',
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );
  }

  test('GivenUsPerson_WhenValidated_ThenReservedSafeFieldsAreCoherent', () {
    final person = _usPerson();

    expect(person.phone, matches(r'^\+1 \(415\) 555-01\d{2}$'));
    expect(person.email, endsWith('@example.com'));
    expect(person.address.region, 'CA');
    expect(person.identifiers.single.type, IdentityDocumentType.ssn);
    expect(
      const IdentityDocumentValidator().isValid(
        locale: IdentityLocale.us,
        type: person.identifiers.single.type,
        value: person.identifiers.single.value,
      ),
      isTrue,
    );
  });

  test('GivenBrazilPerson_WhenValidated_ThenCpfAndCinRegistrationMatches', () {
    final person = _brPerson();

    expect(person.phone, matches(r'^\+55 \(11\) 9\d{4}-\d{4}$'));
    expect(person.address.region, 'SP');
    expect(person.identifiers.map((item) => item.type), [
      IdentityDocumentType.cpf,
      IdentityDocumentType.cin,
    ]);
    expect(
      _digits(person.identifiers[0].value),
      _digits(person.identifiers[1].value),
    );
  });

  for (final entry in <String, SyntheticPerson>{
    'LocaleMismatch': _usPerson(locale: PersonLocale.br),
    'BlankGivenName': _usPerson(givenName: ' '),
    'BlankFamilyName': _usPerson(familyName: ''),
    'AddressRegionMismatch': _usPerson(
      address: const PersonAddress(
        street: '100 Example Avenue',
        city: 'San Francisco',
        region: 'NY',
        postalCode: '94105',
        countryCode: 'US',
      ),
    ),
    'PhoneRegionMismatch': _usPerson(phone: '+1 (212) 555-0100'),
    'EmailNameMismatch': _usPerson(email: 'someone.else01@example.com'),
    'NonReservedEmail': _usPerson(email: 'avery.reed01@example.net'),
    'WrongIdentifierType': _usPerson(
      identifiers: const [
        PersonIdentifier(type: IdentityDocumentType.itin, value: '900-70-0000'),
      ],
    ),
    'InvalidIdentifier': _usPerson(
      identifiers: const [
        PersonIdentifier(type: IdentityDocumentType.ssn, value: '000-00-0000'),
      ],
    ),
    'MismatchedBrazilRegistration': _brPerson(
      identifiers: const [
        PersonIdentifier(
          type: IdentityDocumentType.cpf,
          value: '280.012.389-38',
        ),
        PersonIdentifier(
          type: IdentityDocumentType.cin,
          value: '111.444.777-35',
        ),
      ],
    ),
  }.entries) {
    test('Given${entry.key}_WhenValidated_ThenRejected', () {
      expect(
        validator.isValid(
          person: entry.value,
          request: PersonRequest(locale: entry.value.locale),
          operationDate: today,
        ),
        isFalse,
      );
    });
  }

  test('GivenInclusiveAgeBounds_WhenValidated_ThenExactBirthdaysAccepted', () {
    for (final age in [18, 90]) {
      final person = _usPerson(
        birthDate: DateTime.utc(today.year - age, today.month, today.day),
      );
      expect(
        validator.isValid(
          person: person,
          request: const PersonRequest(
            locale: PersonLocale.us,
            minAge: 18,
            maxAge: 90,
          ),
          operationDate: today,
        ),
        isTrue,
      );
    }
  });

  test('GivenBirthDateOutsideAgeBounds_WhenValidated_ThenRejected', () {
    for (final birthDate in [
      DateTime.utc(2008, 10, 21),
      DateTime.utc(1935, 10, 19),
      DateTime.utc(2026, 10, 21),
    ]) {
      expect(
        validator.isValid(
          person: _usPerson(birthDate: birthDate),
          request: const PersonRequest(locale: PersonLocale.us),
          operationDate: today,
        ),
        isFalse,
      );
    }
  });

  test('GivenLeapDayBirth_WhenAgeCalculated_ThenCalendarBoundaryIsStable', () {
    final person = _usPerson(birthDate: DateTime.utc(2004, 2, 29));
    expect(
      validator.isValid(
        person: person,
        request: const PersonRequest(
          locale: PersonLocale.us,
          minAge: 20,
          maxAge: 20,
        ),
        operationDate: DateTime.utc(2025, 2, 28),
      ),
      isTrue,
    );
    expect(
      validator.isValid(
        person: person,
        request: const PersonRequest(
          locale: PersonLocale.us,
          minAge: 21,
          maxAge: 21,
        ),
        operationDate: DateTime.utc(2025, 3),
      ),
      isTrue,
    );
  });

  final invalidRequests = <String, PersonRequest>{
    'NegativeMinimumAge': const PersonRequest(
      locale: PersonLocale.us,
      minAge: -1,
    ),
    'MaximumAgeAboveLimit': const PersonRequest(
      locale: PersonLocale.us,
      maxAge: 131,
    ),
    'ReversedAgeRange': const PersonRequest(
      locale: PersonLocale.us,
      minAge: 91,
      maxAge: 18,
    ),
    'ZeroCount': const PersonRequest(locale: PersonLocale.us, count: 0),
  };

  for (final entry in invalidRequests.entries) {
    test(
      'Given${entry.key}_WhenGenerated_ThenValidationPrecedesDependencies',
      () {
        var candidates = 0;
        var allocations = 0;
        final generator = PersonGenerator.forTesting(
          candidate: (_, _) {
            candidates++;
            return _usPerson();
          },
          today: () => today,
          allocate: (_) {
            allocations++;
            return <SyntheticPerson>[];
          },
        );

        expect(
          () => generator.generate(entry.value),
          throwsA(
            isA<PersonGenerationException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  PersonFailureKind.validation,
                )
                .having((error) => error.code, 'code', startsWith('person.')),
          ),
        );
        expect(candidates, 0);
        expect(allocations, 0);
      },
    );
  }

  test('GivenRejectedCandidate_WhenRetried_ThenOnlyValidPersonReturns', () {
    var calls = 0;
    final result = PersonGenerator.forTesting(
      candidate: (_, _) {
        calls++;
        return calls == 1 ? _usPerson(phone: '+1 (212) 555-0100') : _usPerson();
      },
      today: () => today,
    ).generate(const PersonRequest(locale: PersonLocale.us));

    expect(calls, 2);
    expect(result.people, [_usPerson()]);
  });

  test('GivenOnlyInconsistentCandidates_WhenGenerated_ThenAtomicFailure', () {
    var calls = 0;
    final generator = PersonGenerator.forTesting(
      candidate: (_, _) {
        calls++;
        return _usPerson(phone: '+1 (212) 555-0100');
      },
      today: () => today,
    );

    expect(
      () => generator.generate(
        const PersonRequest(locale: PersonLocale.us, count: 2),
      ),
      throwsA(
        isA<PersonGenerationException>()
            .having((error) => error.kind, 'kind', PersonFailureKind.processing)
            .having((error) => error.code, 'code', 'person.generation-failed'),
      ),
    );
    expect(calls, 32);
  });

  test('GivenCandidateSourceFailure_WhenGenerated_ThenDetailsAreRedacted', () {
    final generator = PersonGenerator.forTesting(
      candidate: (_, _) => throw StateError('PRIVATE PERSON'),
      today: () => today,
    );

    expect(
      () => generator.generate(const PersonRequest(locale: PersonLocale.us)),
      throwsA(
        isA<PersonGenerationException>()
            .having((error) => error.code, 'code', 'person.source-unavailable')
            .having(
              (error) => error.toString(),
              'redacted',
              isNot(contains('PRIVATE')),
            ),
      ),
    );
  });

  test('GivenAllocationFailure_WhenGenerated_ThenResourceFailureReturns', () {
    final generator = PersonGenerator.forTesting(
      candidate: (_, _) => _usPerson(),
      today: () => today,
      allocate: (_) => throw OutOfMemoryError(),
    );

    expect(
      () => generator.generate(const PersonRequest(locale: PersonLocale.us)),
      throwsA(
        isA<PersonGenerationException>()
            .having((error) => error.kind, 'kind', PersonFailureKind.resource)
            .having((error) => error.code, 'code', 'person.resource-limit'),
      ),
    );
  });

  for (final locale in PersonLocale.values) {
    test(
      'Given${locale.name}Defaults_WhenGenerated_ThenEveryInvariantHolds',
      () {
        final request = PersonRequest(locale: locale, count: 12);
        final result = const PersonGenerator().generate(request);

        expect(result.people, hasLength(12));
        for (final person in result.people) {
          expect(
            validator.isValid(
              person: person,
              request: request,
              operationDate: result.operationDate,
            ),
            isTrue,
          );
        }
      },
    );
  }
}

SyntheticPerson _usPerson({
  PersonLocale locale = PersonLocale.us,
  String givenName = 'Avery',
  String familyName = 'Reed',
  DateTime? birthDate,
  PersonAddress? address,
  String phone = '+1 (415) 555-0100',
  String email = 'avery.reed01@example.com',
  List<PersonIdentifier>? identifiers,
}) => SyntheticPerson(
  locale: locale,
  givenName: givenName,
  familyName: familyName,
  birthDate: birthDate ?? DateTime.utc(1990, 6, 15),
  address:
      address ??
      const PersonAddress(
        street: '100 Example Avenue',
        city: 'San Francisco',
        region: 'CA',
        postalCode: '94105',
        countryCode: 'US',
      ),
  phone: phone,
  email: email,
  identifiers:
      identifiers ??
      const [
        PersonIdentifier(type: IdentityDocumentType.ssn, value: '219-09-9999'),
      ],
);

SyntheticPerson _brPerson({
  DateTime? birthDate,
  List<PersonIdentifier>? identifiers,
}) => SyntheticPerson(
  locale: PersonLocale.br,
  givenName: 'Ana',
  familyName: 'Silva',
  birthDate: birthDate ?? DateTime.utc(1992, 2, 29),
  address: const PersonAddress(
    street: 'Rua Exemplo, 100',
    city: 'São Paulo',
    region: 'SP',
    postalCode: '01000-000',
    countryCode: 'BR',
  ),
  phone: '+55 (11) 90000-0000',
  email: 'ana.silva01@example.com',
  identifiers:
      identifiers ??
      const [
        PersonIdentifier(
          type: IdentityDocumentType.cpf,
          value: '280.012.389-38',
        ),
        PersonIdentifier(
          type: IdentityDocumentType.cin,
          value: '280.012.389-38',
        ),
      ],
);

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
