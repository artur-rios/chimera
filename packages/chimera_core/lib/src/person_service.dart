import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class PersonOperationRequest {
  const PersonOperationRequest({
    this.locale = 'us',
    this.minAge = '18',
    this.maxAge = '90',
    this.count = '1',
  });

  final String locale;
  final String minAge;
  final String maxAge;
  final String count;
}

final class PersonOutput {
  const PersonOutput(this.result);

  final PersonResult result;

  String get locale => result.locale.name;
  int get minAge => result.minAge;
  int get maxAge => result.maxAge;
  int get count => result.people.length;
  bool get synthetic => result.synthetic;
  String get label => 'synthetic-test-data';
  List<SyntheticPerson> get people => result.people;

  Map<String, Object?> toJson() => {
    'locale': locale,
    'count': count,
    'synthetic': synthetic,
    'label': label,
    'constraints': {'minAge': minAge, 'maxAge': maxAge},
    'people': people.map(_personToJson).toList(growable: false),
  };
}

Map<String, Object?> _personToJson(SyntheticPerson person) => {
  'locale': person.locale.name,
  'givenName': person.givenName,
  'familyName': person.familyName,
  'birthDate': _dateText(person.birthDate),
  'address': {
    'street': person.address.street,
    'city': person.address.city,
    'region': person.address.region,
    'postalCode': person.address.postalCode,
    'countryCode': person.address.countryCode,
  },
  'phone': person.phone,
  'email': person.email,
  'identifiers': person.identifiers
      .map(
        (identifier) => {
          'locale': identifier.locale.name,
          'type': identifier.type.name,
          'value': identifier.value,
          'synthetic': identifier.synthetic,
        },
      )
      .toList(growable: false),
  'synthetic': person.synthetic,
};

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

final class PersonService
    implements OperationService<PersonOperationRequest, PersonOutput> {
  const PersonService({this.generator = const PersonGenerator()});

  final PersonGenerator generator;

  @override
  Future<ChimeraResult<PersonOutput>> execute(
    PersonOperationRequest request,
  ) async {
    final locale = switch (request.locale) {
      'us' => PersonLocale.us,
      'br' => PersonLocale.br,
      _ => null,
    };
    if (locale == null) {
      return _validation(
        'person.invalid-locale',
        'locale',
        'us-or-br-required',
      );
    }

    final minAge = _parseAge(request.minAge);
    if (minAge == null) {
      return _validation(
        'person.invalid-min-age',
        'minAge',
        'integer-from-0-through-130-required',
      );
    }
    final maxAge = _parseAge(request.maxAge);
    if (maxAge == null) {
      return _validation(
        'person.invalid-max-age',
        'maxAge',
        'integer-from-0-through-130-required',
      );
    }
    if (minAge > maxAge) {
      return _validation(
        'person.invalid-age-range',
        'ageRange',
        'minimum-must-not-exceed-maximum',
      );
    }
    final count = tryParsePositiveDecimalInteger(request.count);
    if (count == null) {
      return _validation(
        'person.invalid-count',
        'count',
        'positive-integer-required',
      );
    }

    try {
      return ChimeraSuccess(
        PersonOutput(
          generator.generate(
            PersonRequest(
              locale: locale,
              minAge: minAge,
              maxAge: maxAge,
              count: count,
            ),
          ),
        ),
      );
    } on PersonGenerationException catch (error) {
      final kind = switch (error.kind) {
        PersonFailureKind.validation => FailureKind.validation,
        PersonFailureKind.processing => FailureKind.processing,
        PersonFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        PersonFailureKind.validation => 'error.person.validation',
        PersonFailureKind.processing => 'error.person.processing',
        PersonFailureKind.resource => 'error.person.resource',
      };
      return ChimeraFailure(
        kind: kind,
        code: error.code,
        messageKey: messageKey,
        details: {'field': error.field, 'reason': error.reason},
      );
    } on OutOfMemoryError {
      return const ChimeraFailure(
        kind: FailureKind.resource,
        code: 'person.resource-limit',
        messageKey: 'error.person.resource',
      );
    }
  }
}

int? _parseAge(String value) {
  if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(value)) return null;
  final parsed = int.tryParse(value);
  return parsed != null && parsed <= 130 ? parsed : null;
}

ChimeraFailure<PersonOutput> _validation(
  String code,
  String field,
  String reason,
) => ChimeraFailure(
  kind: FailureKind.validation,
  code: code,
  messageKey: 'error.person.validation',
  details: {'field': field, 'reason': reason},
);
