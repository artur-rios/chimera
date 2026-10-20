import 'dart:math';

import 'package:meta/meta.dart';

typedef IdentityDocumentCandidateSource = String Function(
  IdentityLocale locale,
  IdentityDocumentType type,
  CnpjFormat cnpjFormat,
);
typedef IdentityDocumentResultAllocator = List<String> Function(int count);

enum IdentityLocale { us, br }

enum IdentityDocumentType { ssn, itin, ein, cpf, cnpj, cnh, cin }

enum CnpjFormat { numeric, alphanumeric }

enum IdentityDocumentFailureKind { validation, processing, resource }

final class IdentityDocumentGenerationException implements Exception {
  const IdentityDocumentGenerationException(
    this.kind,
    this.code,
    this.field,
    this.reason,
  );

  final IdentityDocumentFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() =>
      'IdentityDocumentGenerationException($code, $field, $reason)';
}

final class IdentityDocumentRequest {
  const IdentityDocumentRequest({
    required this.locale,
    required this.type,
    this.cnpjFormat = CnpjFormat.alphanumeric,
    this.count = 1,
  });

  final IdentityLocale locale;
  final IdentityDocumentType type;
  final CnpjFormat cnpjFormat;
  final int count;
}

final class IdentityDocumentResult {
  const IdentityDocumentResult({
    required this.values,
    required this.locale,
    required this.type,
    required this.cnpjFormat,
  });

  final List<String> values;
  final IdentityLocale locale;
  final IdentityDocumentType type;
  final CnpjFormat cnpjFormat;
  bool get synthetic => true;
}

const _einPrefixes = <String>{
  '01',
  '02',
  '03',
  '04',
  '05',
  '06',
  '10',
  '11',
  '12',
  '13',
  '14',
  '15',
  '16',
  '20',
  '21',
  '22',
  '23',
  '24',
  '25',
  '26',
  '27',
  '30',
  '31',
  '32',
  '33',
  '34',
  '35',
  '36',
  '37',
  '38',
  '39',
  '40',
  '41',
  '42',
  '43',
  '44',
  '45',
  '46',
  '47',
  '48',
  '50',
  '51',
  '52',
  '53',
  '54',
  '55',
  '56',
  '57',
  '58',
  '59',
  '60',
  '61',
  '62',
  '63',
  '64',
  '65',
  '66',
  '67',
  '68',
  '71',
  '72',
  '73',
  '74',
  '75',
  '76',
  '77',
  '80',
  '81',
  '82',
  '83',
  '84',
  '85',
  '86',
  '87',
  '88',
  '90',
  '91',
  '92',
  '93',
  '94',
  '95',
  '98',
  '99',
};

const _ssnSpecimens = ['219099999'];
const _fictitiousAlphanumericCnpjs = ['AHS62MGW000114', '12ABC34501DE35'];
final Random _secureRandom = Random.secure();

List<String> _allocateResults(int count) =>
    List<String>.filled(count, '', growable: false);

String _digits(int count) {
  final output = StringBuffer();
  for (var index = 0; index < count; index++) {
    output.write(_secureRandom.nextInt(10));
  }
  return output.toString();
}

String _secureCandidate(
  IdentityLocale locale,
  IdentityDocumentType type,
  CnpjFormat cnpjFormat,
) {
  return switch (type) {
    IdentityDocumentType.ssn =>
      _ssnSpecimens[_secureRandom.nextInt(_ssnSpecimens.length)],
    IdentityDocumentType.itin => _generateItin(),
    IdentityDocumentType.ein => _generateEin(),
    IdentityDocumentType.cpf || IdentityDocumentType.cin => _generateCpf(),
    IdentityDocumentType.cnpj =>
      cnpjFormat == CnpjFormat.alphanumeric
          ? _fictitiousAlphanumericCnpjs[_secureRandom.nextInt(
              _fictitiousAlphanumericCnpjs.length,
            )]
          : _generateNumericCnpj(),
    IdentityDocumentType.cnh => _generateCnh(),
  };
}

String _generateItin() {
  const groups = [
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    90,
    91,
    92,
    94,
    95,
    96,
    97,
    98,
    99,
  ];
  final group = groups[_secureRandom.nextInt(groups.length)];
  return '9${_digits(2)}${group.toString().padLeft(2, '0')}${_digits(4)}';
}

String _generateEin() {
  final prefixes = _einPrefixes.toList(growable: false);
  return '${prefixes[_secureRandom.nextInt(prefixes.length)]}${_digits(7)}';
}

String _generateCpf() {
  var base = _digits(9);
  while (_allSame(base)) {
    base = _digits(9);
  }
  final first = _cpfDigit(base);
  final second = _cpfDigit('$base$first');
  return '$base$first$second';
}

String _generateNumericCnpj() {
  var base = '${_digits(8)}0001';
  while (_allSame(base)) {
    base = '${_digits(8)}0001';
  }
  final first = _cnpjDigit(base);
  final second = _cnpjDigit('$base$first');
  return '$base$first$second';
}

String _generateCnh() {
  var base = _digits(9);
  while (_allSame(base)) {
    base = _digits(9);
  }
  final digits = _cnhDigits(base);
  return '$base${digits.$1}${digits.$2}';
}

@immutable
final class IdentityDocumentValidator {
  const IdentityDocumentValidator();

  bool isValid({
    required IdentityLocale locale,
    required IdentityDocumentType type,
    required String value,
    CnpjFormat cnpjFormat = CnpjFormat.alphanumeric,
  }) {
    if (!_supports(locale, type)) return false;
    final normalized = _normalize(value);
    return switch (type) {
      IdentityDocumentType.ssn => _validSsn(normalized),
      IdentityDocumentType.itin => _validItin(normalized),
      IdentityDocumentType.ein => _validEin(normalized),
      IdentityDocumentType.cpf ||
      IdentityDocumentType.cin => _validCpf(normalized),
      IdentityDocumentType.cnpj => _validCnpj(normalized, cnpjFormat),
      IdentityDocumentType.cnh => _validCnh(normalized),
    };
  }

  String format(IdentityDocumentType type, String value) {
    final normalized = _normalize(value);
    return switch (type) {
      IdentityDocumentType.ssn || IdentityDocumentType.itin =>
        '${normalized.substring(0, 3)}-${normalized.substring(3, 5)}-${normalized.substring(5)}',
      IdentityDocumentType.ein =>
        '${normalized.substring(0, 2)}-${normalized.substring(2)}',
      IdentityDocumentType.cpf || IdentityDocumentType.cin =>
        '${normalized.substring(0, 3)}.${normalized.substring(3, 6)}.${normalized.substring(6, 9)}-${normalized.substring(9)}',
      IdentityDocumentType.cnpj =>
        '${normalized.substring(0, 2)}.${normalized.substring(2, 5)}.${normalized.substring(5, 8)}/${normalized.substring(8, 12)}-${normalized.substring(12)}',
      IdentityDocumentType.cnh => normalized,
    };
  }
}

bool _supports(IdentityLocale locale, IdentityDocumentType type) =>
    switch (locale) {
      IdentityLocale.us => const {
        IdentityDocumentType.ssn,
        IdentityDocumentType.itin,
        IdentityDocumentType.ein,
      }.contains(type),
      IdentityLocale.br => const {
        IdentityDocumentType.cpf,
        IdentityDocumentType.cnpj,
        IdentityDocumentType.cnh,
        IdentityDocumentType.cin,
      }.contains(type),
    };

String _normalize(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[.\-/\s]'), '');

bool _validSsn(String value) {
  if (!RegExp(r'^\d{9}$').hasMatch(value)) return false;
  final area = int.parse(value.substring(0, 3));
  return area != 0 &&
      area != 666 &&
      area < 900 &&
      value.substring(3, 5) != '00' &&
      value.substring(5) != '0000';
}

bool _validItin(String value) {
  if (!RegExp(r'^9\d{8}$').hasMatch(value)) return false;
  final group = int.parse(value.substring(3, 5));
  return (group >= 50 && group <= 65) ||
      (group >= 70 && group <= 88) ||
      (group >= 90 && group <= 92) ||
      (group >= 94 && group <= 99);
}

bool _validEin(String value) =>
    RegExp(r'^\d{9}$').hasMatch(value) &&
    _einPrefixes.contains(value.substring(0, 2));

bool _validCpf(String value) {
  if (!RegExp(r'^\d{11}$').hasMatch(value) || _allSame(value)) return false;
  final first = _cpfDigit(value.substring(0, 9));
  final second = _cpfDigit(value.substring(0, 10));
  return value.endsWith('$first$second');
}

int _cpfDigit(String base) {
  var sum = 0;
  final weight = base.length + 1;
  for (var index = 0; index < base.length; index++) {
    sum += int.parse(base[index]) * (weight - index);
  }
  final remainder = sum % 11;
  return remainder < 2 ? 0 : 11 - remainder;
}

bool _validCnpj(String value, CnpjFormat format) {
  if (!RegExp(r'^[0-9A-Z]{12}\d{2}$').hasMatch(value) ||
      _allSame(value.substring(0, 12))) {
    return false;
  }
  final hasLetter = RegExp(r'[A-Z]').hasMatch(value.substring(0, 12));
  if (format == CnpjFormat.numeric && hasLetter) return false;
  if (format == CnpjFormat.alphanumeric && !hasLetter) return false;
  final first = _cnpjDigit(value.substring(0, 12));
  final second = _cnpjDigit(value.substring(0, 13));
  return value.endsWith('$first$second');
}

int _cnpjDigit(String base) {
  var sum = 0;
  var weight = 2;
  for (var index = base.length - 1; index >= 0; index--) {
    final code = base.codeUnitAt(index) - 48;
    sum += code * weight;
    weight = weight == 9 ? 2 : weight + 1;
  }
  final remainder = sum % 11;
  return remainder < 2 ? 0 : 11 - remainder;
}

bool _validCnh(String value) {
  if (!RegExp(r'^\d{11}$').hasMatch(value) || _allSame(value)) return false;
  final digits = _cnhDigits(value.substring(0, 9));
  return value.endsWith('${digits.$1}${digits.$2}');
}

(int, int) _cnhDigits(String base) {
  var firstSum = 0;
  var secondSum = 0;
  for (var index = 0; index < 9; index++) {
    final digit = int.parse(base[index]);
    firstSum += digit * (9 - index);
    secondSum += digit * (index + 1);
  }
  var adjustment = 0;
  var first = firstSum % 11;
  if (first == 10) {
    first = 0;
    adjustment = -2;
  }
  var second = (secondSum + adjustment) % 11;
  if (second < 0) second += 11;
  if (second == 10) second = 0;
  return (first, second);
}

bool _allSame(String value) =>
    value.isNotEmpty &&
    value.codeUnits.every((unit) => unit == value.codeUnitAt(0));

final class IdentityDocumentGenerator {
  const IdentityDocumentGenerator()
    : this._(_secureCandidate, _allocateResults);

  const IdentityDocumentGenerator._(this._candidate, this._allocate);

  @visibleForTesting
  const IdentityDocumentGenerator.forTesting({
    required IdentityDocumentCandidateSource candidate,
    IdentityDocumentResultAllocator allocate = _allocateResults,
  }) : this._(candidate, allocate);

  static const _maximumCandidateAttempts = 32;
  static const _validator = IdentityDocumentValidator();

  final IdentityDocumentCandidateSource _candidate;
  final IdentityDocumentResultAllocator _allocate;

  IdentityDocumentResult generate(IdentityDocumentRequest request) {
    if (!_supports(request.locale, request.type)) {
      throw const IdentityDocumentGenerationException(
        IdentityDocumentFailureKind.validation,
        'document.locale-type-mismatch',
        'type',
        'type-must-match-locale',
      );
    }
    if (request.count < 1) {
      throw const IdentityDocumentGenerationException(
        IdentityDocumentFailureKind.validation,
        'document.invalid-count',
        'count',
        'positive-integer-required',
      );
    }

    final values = _allocateBatch(request.count);
    for (var index = 0; index < request.count; index++) {
      var accepted = false;
      for (var attempt = 0; attempt < _maximumCandidateAttempts; attempt++) {
        final candidate = _readCandidate(request);
        if (!_validator.isValid(
          locale: request.locale,
          type: request.type,
          cnpjFormat: request.cnpjFormat,
          value: candidate,
        )) {
          continue;
        }
        values[index] = _validator.format(request.type, candidate);
        accepted = true;
        break;
      }
      if (!accepted) {
        throw const IdentityDocumentGenerationException(
          IdentityDocumentFailureKind.processing,
          'document.generation-failed',
          'value',
          'valid-candidate-attempt-limit',
        );
      }
    }

    return IdentityDocumentResult(
      values: List.unmodifiable(values),
      locale: request.locale,
      type: request.type,
      cnpjFormat: request.cnpjFormat,
    );
  }

  List<String> _allocateBatch(int count) {
    try {
      return _allocate(count);
    } on OutOfMemoryError {
      _throwResourceLimit();
    } on RangeError {
      _throwResourceLimit();
    }
  }

  String _readCandidate(IdentityDocumentRequest request) {
    try {
      return _candidate(request.locale, request.type, request.cnpjFormat);
    } on Object {
      throw const IdentityDocumentGenerationException(
        IdentityDocumentFailureKind.processing,
        'document.source-unavailable',
        'value',
        'candidate-source-failed',
      );
    }
  }
}

Never _throwResourceLimit() => throw const IdentityDocumentGenerationException(
  IdentityDocumentFailureKind.resource,
  'document.resource-limit',
  'values',
  'allocation-limit',
);
