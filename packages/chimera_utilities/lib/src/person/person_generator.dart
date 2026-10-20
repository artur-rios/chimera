import 'dart:math';

import 'package:meta/meta.dart';

import '../identity_document/identity_document_generator.dart';

typedef PersonCandidateSource = SyntheticPerson Function(
  PersonRequest request,
  DateTime operationDate,
);
typedef PersonTodaySource = DateTime Function();
typedef PersonResultAllocator = List<SyntheticPerson> Function(int count);

enum PersonLocale { us, br }

enum PersonFailureKind { validation, processing, resource }

final class PersonGenerationException implements Exception {
  const PersonGenerationException(
    this.kind,
    this.code,
    this.field,
    this.reason,
  );

  final PersonFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'PersonGenerationException($code, $field, $reason)';
}

@immutable
final class PersonRequest {
  const PersonRequest({
    required this.locale,
    this.minAge = 18,
    this.maxAge = 90,
    this.count = 1,
  });

  final PersonLocale locale;
  final int minAge;
  final int maxAge;
  final int count;

  PersonRequest copyWith({
    PersonLocale? locale,
    int? minAge,
    int? maxAge,
    int? count,
  }) => PersonRequest(
    locale: locale ?? this.locale,
    minAge: minAge ?? this.minAge,
    maxAge: maxAge ?? this.maxAge,
    count: count ?? this.count,
  );
}

@immutable
final class PersonAddress {
  const PersonAddress({
    required this.street,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.countryCode,
  });

  final String street;
  final String city;
  final String region;
  final String postalCode;
  final String countryCode;

  @override
  bool operator ==(Object other) =>
      other is PersonAddress &&
      street == other.street &&
      city == other.city &&
      region == other.region &&
      postalCode == other.postalCode &&
      countryCode == other.countryCode;

  @override
  int get hashCode =>
      Object.hash(street, city, region, postalCode, countryCode);
}

@immutable
final class PersonIdentifier {
  const PersonIdentifier({required this.type, required this.value});

  final IdentityDocumentType type;
  final String value;
  bool get synthetic => true;

  @override
  bool operator ==(Object other) =>
      other is PersonIdentifier && type == other.type && value == other.value;

  @override
  int get hashCode => Object.hash(type, value);
}

@immutable
final class SyntheticPerson {
  SyntheticPerson({
    required this.locale,
    required this.givenName,
    required this.familyName,
    required this.birthDate,
    required this.address,
    required this.phone,
    required this.email,
    required List<PersonIdentifier> identifiers,
  }) : identifiers = List.unmodifiable(identifiers);

  final PersonLocale locale;
  final String givenName;
  final String familyName;
  final DateTime birthDate;
  final PersonAddress address;
  final String phone;
  final String email;
  final List<PersonIdentifier> identifiers;
  bool get synthetic => true;

  @override
  bool operator ==(Object other) =>
      other is SyntheticPerson &&
      locale == other.locale &&
      givenName == other.givenName &&
      familyName == other.familyName &&
      birthDate == other.birthDate &&
      address == other.address &&
      phone == other.phone &&
      email == other.email &&
      _listEquals(identifiers, other.identifiers);

  @override
  int get hashCode => Object.hash(
    locale,
    givenName,
    familyName,
    birthDate,
    address,
    phone,
    email,
    Object.hashAll(identifiers),
  );
}

@immutable
final class PersonResult {
  PersonResult({
    required List<SyntheticPerson> people,
    required this.locale,
    required this.minAge,
    required this.maxAge,
    required this.operationDate,
  }) : people = List.unmodifiable(people);

  final List<SyntheticPerson> people;
  final PersonLocale locale;
  final int minAge;
  final int maxAge;
  final DateTime operationDate;
  bool get synthetic => true;
}

final class _Location {
  const _Location({
    required this.city,
    required this.region,
    required this.postalCode,
    required this.countryCode,
    required this.areaCode,
  });

  final String city;
  final String region;
  final String postalCode;
  final String countryCode;
  final String areaCode;
}

const _usGivenNames = ['Avery', 'Jordan', 'Morgan', 'Riley'];
const _usFamilyNames = ['Reed', 'Parker', 'Taylor', 'Walker'];
const _brGivenNames = ['Ana', 'Bruno', 'Camila', 'Diego'];
const _brFamilyNames = ['Silva', 'Santos', 'Oliveira', 'Costa'];
const _usLocations = [
  _Location(
    city: 'San Francisco',
    region: 'CA',
    postalCode: '94105',
    countryCode: 'US',
    areaCode: '415',
  ),
  _Location(
    city: 'New York',
    region: 'NY',
    postalCode: '10001',
    countryCode: 'US',
    areaCode: '212',
  ),
  _Location(
    city: 'Austin',
    region: 'TX',
    postalCode: '78701',
    countryCode: 'US',
    areaCode: '512',
  ),
  _Location(
    city: 'Seattle',
    region: 'WA',
    postalCode: '98101',
    countryCode: 'US',
    areaCode: '206',
  ),
];
const _brLocations = [
  _Location(
    city: 'São Paulo',
    region: 'SP',
    postalCode: '01000-000',
    countryCode: 'BR',
    areaCode: '11',
  ),
  _Location(
    city: 'Rio de Janeiro',
    region: 'RJ',
    postalCode: '20000-000',
    countryCode: 'BR',
    areaCode: '21',
  ),
  _Location(
    city: 'Belo Horizonte',
    region: 'MG',
    postalCode: '30000-000',
    countryCode: 'BR',
    areaCode: '31',
  ),
  _Location(
    city: 'Porto Alegre',
    region: 'RS',
    postalCode: '90000-000',
    countryCode: 'BR',
    areaCode: '51',
  ),
];

final Random _secureRandom = Random.secure();
const _documentGenerator = IdentityDocumentGenerator();

List<SyntheticPerson> _allocateResults(int count) =>
    List<SyntheticPerson>.empty(growable: true);

DateTime _today() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
}

SyntheticPerson _secureCandidate(
  PersonRequest request,
  DateTime operationDate,
) {
  final us = request.locale == PersonLocale.us;
  final givenNames = us ? _usGivenNames : _brGivenNames;
  final familyNames = us ? _usFamilyNames : _brFamilyNames;
  final locations = us ? _usLocations : _brLocations;
  final givenName = givenNames[_secureRandom.nextInt(givenNames.length)];
  final familyName = familyNames[_secureRandom.nextInt(familyNames.length)];
  final location = locations[_secureRandom.nextInt(locations.length)];
  final number = 100 + _secureRandom.nextInt(9900);
  final emailSuffix = 1 + _secureRandom.nextInt(99);
  final birthDate = _randomBirthDate(request, operationDate);

  final identifiers = us
      ? [
          PersonIdentifier(
            type: IdentityDocumentType.ssn,
            value: _documentGenerator
                .generate(
                  const IdentityDocumentRequest(
                    locale: IdentityLocale.us,
                    type: IdentityDocumentType.ssn,
                  ),
                )
                .values
                .single,
          ),
        ]
      : _brazilIdentifiers();

  return SyntheticPerson(
    locale: request.locale,
    givenName: givenName,
    familyName: familyName,
    birthDate: birthDate,
    address: PersonAddress(
      street: us ? '$number Example Avenue' : 'Rua Exemplo, $number',
      city: location.city,
      region: location.region,
      postalCode: location.postalCode,
      countryCode: location.countryCode,
    ),
    phone: us ? _usPhone(location.areaCode) : _brPhone(location.areaCode),
    email:
        '${_slug(givenName)}.${_slug(familyName)}${emailSuffix.toString().padLeft(2, '0')}@example.com',
    identifiers: identifiers,
  );
}

List<PersonIdentifier> _brazilIdentifiers() {
  final value = _documentGenerator
      .generate(
        const IdentityDocumentRequest(
          locale: IdentityLocale.br,
          type: IdentityDocumentType.cpf,
        ),
      )
      .values
      .single;
  return [
    PersonIdentifier(type: IdentityDocumentType.cpf, value: value),
    PersonIdentifier(type: IdentityDocumentType.cin, value: value),
  ];
}

DateTime _randomBirthDate(PersonRequest request, DateTime operationDate) {
  final earliest = _addDays(
    _anniversary(
      operationDate.year - request.maxAge - 1,
      operationDate.month,
      operationDate.day,
    ),
    1,
  );
  final latest = _anniversary(
    operationDate.year - request.minAge,
    operationDate.month,
    operationDate.day,
  );
  final days = latest.difference(earliest).inDays;
  return _addDays(earliest, _secureRandom.nextInt(days + 1));
}

String _usPhone(String areaCode) {
  final line = 100 + _secureRandom.nextInt(100);
  return '+1 ($areaCode) 555-${line.toString().padLeft(4, '0')}';
}

String _brPhone(String areaCode) {
  final subscriber = _digits(8);
  return '+55 ($areaCode) 9${subscriber.substring(0, 4)}-${subscriber.substring(4)}';
}

String _digits(int count) {
  final output = StringBuffer();
  for (var index = 0; index < count; index++) {
    output.write(_secureRandom.nextInt(10));
  }
  return output.toString();
}

@immutable
final class PersonValidator {
  const PersonValidator();

  static const _documentValidator = IdentityDocumentValidator();

  bool isValid({
    required SyntheticPerson person,
    required PersonRequest request,
    required DateTime operationDate,
  }) {
    if (person.locale != request.locale ||
        person.givenName.trim().isEmpty ||
        person.familyName.trim().isEmpty ||
        !_namesMatchLocale(person)) {
      return false;
    }
    final age = _ageOn(person.birthDate, operationDate);
    if (age < request.minAge || age > request.maxAge) return false;

    final locations = request.locale == PersonLocale.us
        ? _usLocations
        : _brLocations;
    final location = locations.where(
      (item) => item.region == person.address.region,
    );
    if (location.length != 1) return false;
    final expected = location.single;
    if (person.address.city != expected.city ||
        person.address.postalCode != expected.postalCode ||
        person.address.countryCode != expected.countryCode ||
        !_validStreet(person)) {
      return false;
    }
    if (!_validPhone(person, expected.areaCode) || !_validEmail(person)) {
      return false;
    }
    return request.locale == PersonLocale.us
        ? _validUsIdentifiers(person.identifiers)
        : _validBrazilIdentifiers(person.identifiers);
  }

  bool _validUsIdentifiers(List<PersonIdentifier> identifiers) =>
      identifiers.length == 1 &&
      identifiers.single.type == IdentityDocumentType.ssn &&
      _documentValidator.isValid(
        locale: IdentityLocale.us,
        type: IdentityDocumentType.ssn,
        value: identifiers.single.value,
      );

  bool _validBrazilIdentifiers(List<PersonIdentifier> identifiers) {
    if (identifiers.length != 2 ||
        identifiers[0].type != IdentityDocumentType.cpf ||
        identifiers[1].type != IdentityDocumentType.cin ||
        _onlyDigits(identifiers[0].value) !=
            _onlyDigits(identifiers[1].value)) {
      return false;
    }
    return _documentValidator.isValid(
          locale: IdentityLocale.br,
          type: IdentityDocumentType.cpf,
          value: identifiers[0].value,
        ) &&
        _documentValidator.isValid(
          locale: IdentityLocale.br,
          type: IdentityDocumentType.cin,
          value: identifiers[1].value,
        );
  }
}

bool _namesMatchLocale(SyntheticPerson person) {
  final givenNames = person.locale == PersonLocale.us
      ? _usGivenNames
      : _brGivenNames;
  final familyNames = person.locale == PersonLocale.us
      ? _usFamilyNames
      : _brFamilyNames;
  return givenNames.contains(person.givenName) &&
      familyNames.contains(person.familyName);
}

bool _validStreet(SyntheticPerson person) => person.locale == PersonLocale.us
    ? RegExp(r'^\d{3,4} Example Avenue$').hasMatch(person.address.street)
    : RegExp(r'^Rua Exemplo, \d{3,4}$').hasMatch(person.address.street);

bool _validPhone(SyntheticPerson person, String areaCode) =>
    person.locale == PersonLocale.us
    ? RegExp('^\\+1 \\(${RegExp.escape(areaCode)}\\) 555-01\\d{2}\$')
          .hasMatch(person.phone)
    : RegExp('^\\+55 \\(${RegExp.escape(areaCode)}\\) 9\\d{4}-\\d{4}\$')
          .hasMatch(person.phone);

bool _validEmail(SyntheticPerson person) {
  final prefix = '${_slug(person.givenName)}.${_slug(person.familyName)}';
  return RegExp('^${RegExp.escape(prefix)}\\d{2}@example\\.com\$')
      .hasMatch(person.email);
}

String _slug(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

int _ageOn(DateTime birthDate, DateTime operationDate) {
  final birth = DateTime.utc(birthDate.year, birthDate.month, birthDate.day);
  final date = DateTime.utc(
    operationDate.year,
    operationDate.month,
    operationDate.day,
  );
  if (birth.isAfter(date)) return -1;
  var age = date.year - birth.year;
  if (date.month < birth.month ||
      (date.month == birth.month && date.day < birth.day)) {
    age--;
  }
  return age;
}

DateTime _anniversary(int year, int month, int day) {
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, min(day, lastDay));
}

DateTime _addDays(DateTime value, int days) =>
    DateTime.utc(value.year, value.month, value.day + days);

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class PersonGenerator {
  const PersonGenerator() : this._(_secureCandidate, _today, _allocateResults);

  const PersonGenerator._(this._candidate, this._todaySource, this._allocate);

  @visibleForTesting
  const PersonGenerator.forTesting({
    required PersonCandidateSource candidate,
    required PersonTodaySource today,
    PersonResultAllocator allocate = _allocateResults,
  }) : this._(candidate, today, allocate);

  static const _maximumCandidateAttempts = 32;
  static const _validator = PersonValidator();
  static const _maximumAge = 130;

  final PersonCandidateSource _candidate;
  final PersonTodaySource _todaySource;
  final PersonResultAllocator _allocate;

  PersonResult generate(PersonRequest request) {
    _validateRequest(request);
    final operationDate = _readOperationDate();
    final people = _allocateBatch(request.count);

    for (var index = 0; index < request.count; index++) {
      SyntheticPerson? accepted;
      for (var attempt = 0; attempt < _maximumCandidateAttempts; attempt++) {
        final candidate = _readCandidate(request, operationDate);
        if (_validator.isValid(
          person: candidate,
          request: request,
          operationDate: operationDate,
        )) {
          accepted = candidate;
          break;
        }
      }
      if (accepted == null) {
        throw const PersonGenerationException(
          PersonFailureKind.processing,
          'person.generation-failed',
          'person',
          'consistent-candidate-attempt-limit',
        );
      }
      try {
        people.add(accepted);
      } on OutOfMemoryError {
        _throwResourceLimit();
      } on RangeError {
        _throwResourceLimit();
      }
    }

    return PersonResult(
      people: people,
      locale: request.locale,
      minAge: request.minAge,
      maxAge: request.maxAge,
      operationDate: operationDate,
    );
  }

  void _validateRequest(PersonRequest request) {
    if (request.minAge < 0 || request.minAge > _maximumAge) {
      throw const PersonGenerationException(
        PersonFailureKind.validation,
        'person.invalid-min-age',
        'minAge',
        'integer-from-0-through-130-required',
      );
    }
    if (request.maxAge < 0 || request.maxAge > _maximumAge) {
      throw const PersonGenerationException(
        PersonFailureKind.validation,
        'person.invalid-max-age',
        'maxAge',
        'integer-from-0-through-130-required',
      );
    }
    if (request.minAge > request.maxAge) {
      throw const PersonGenerationException(
        PersonFailureKind.validation,
        'person.invalid-age-range',
        'ageRange',
        'minimum-must-not-exceed-maximum',
      );
    }
    if (request.count < 1) {
      throw const PersonGenerationException(
        PersonFailureKind.validation,
        'person.invalid-count',
        'count',
        'positive-integer-required',
      );
    }
  }

  DateTime _readOperationDate() {
    try {
      final value = _todaySource().toUtc();
      return DateTime.utc(value.year, value.month, value.day);
    } on Object {
      throw const PersonGenerationException(
        PersonFailureKind.processing,
        'person.clock-unavailable',
        'operationDate',
        'clock-source-failed',
      );
    }
  }

  List<SyntheticPerson> _allocateBatch(int count) {
    try {
      return _allocate(count);
    } on OutOfMemoryError {
      _throwResourceLimit();
    } on RangeError {
      _throwResourceLimit();
    }
  }

  SyntheticPerson _readCandidate(
    PersonRequest request,
    DateTime operationDate,
  ) {
    try {
      return _candidate(request, operationDate);
    } on OutOfMemoryError {
      _throwResourceLimit();
    } on PersonGenerationException {
      rethrow;
    } on Object {
      throw const PersonGenerationException(
        PersonFailureKind.processing,
        'person.source-unavailable',
        'person',
        'candidate-source-failed',
      );
    }
  }
}

Never _throwResourceLimit() => throw const PersonGenerationException(
  PersonFailureKind.resource,
  'person.resource-limit',
  'people',
  'allocation-limit',
);
