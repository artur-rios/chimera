import 'dart:math';

import 'package:meta/meta.dart';

typedef CardCandidateSource = String Function(CardNetwork network);
typedef CardResultAllocator = List<String> Function(int count);

enum CardNetwork { visa, mastercard, americanExpress, discover }

enum CardGenerationFailureKind { validation, processing, resource }

/// Exact card numbers published for payment sandbox testing.
///
/// These values are deliberately a closed catalogue. Chimera does not create
/// arbitrary PAN suffixes that could collide with a real account.
const Map<CardNetwork, List<String>> cardTestNumberCatalogue = {
  CardNetwork.visa: [
    '4005520201264821',
    '4242424242424242',
    '4000056655665556',
  ],
  CardNetwork.mastercard: [
    '5500005555555559',
    '5555555555554444',
    '2223003122003222',
  ],
  CardNetwork.americanExpress: [
    '340353278080900',
    '378282246310005',
    '371449635398431',
  ],
  CardNetwork.discover: [
    '6011003179988686',
    '6011111111111117',
    '6011000990139424',
  ],
};

/// Contains only fixed, non-sensitive diagnostic identifiers.
final class CardGenerationException implements Exception {
  const CardGenerationException(this.kind, this.code, this.field, this.reason);

  final CardGenerationFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'CardGenerationException($code, $field, $reason)';
}

final class CardGenerationRequest {
  const CardGenerationRequest({
    this.network = CardNetwork.visa,
    this.count = 1,
  });

  final CardNetwork network;
  final int count;
}

final class CardGenerationResult {
  const CardGenerationResult({required this.values, required this.network});

  final List<String> values;
  final CardNetwork network;
  bool get synthetic => true;
}

final Random _secureRandom = Random.secure();

String _secureCandidate(CardNetwork network) {
  final values = cardTestNumberCatalogue[network]!;
  return values[_secureRandom.nextInt(values.length)];
}

List<String> _allocateResults(int count) =>
    List<String>.filled(count, '', growable: false);

/// Stateless selection and validation of published sandbox card numbers.
final class CardGenerator {
  const CardGenerator() : this._(_secureCandidate, _allocateResults);

  const CardGenerator._(this._candidate, this._allocate);

  @visibleForTesting
  const CardGenerator.forTesting({
    required CardCandidateSource candidate,
    CardResultAllocator allocate = _allocateResults,
  }) : this._(candidate, allocate);

  static const _maximumCandidateAttempts = 32;

  final CardCandidateSource _candidate;
  final CardResultAllocator _allocate;

  CardGenerationResult generate(CardGenerationRequest request) {
    if (request.count < 1) {
      throw const CardGenerationException(
        CardGenerationFailureKind.validation,
        'card.invalid-count',
        'count',
        'positive-integer-required',
      );
    }

    final values = _allocateBatch(request.count);
    for (var index = 0; index < request.count; index++) {
      var accepted = false;
      for (var attempt = 0; attempt < _maximumCandidateAttempts; attempt++) {
        final candidate = _readCandidate(request.network);
        if (!_isValidCandidate(request.network, candidate)) {
          continue;
        }
        values[index] = candidate;
        accepted = true;
        break;
      }
      if (!accepted) {
        throw const CardGenerationException(
          CardGenerationFailureKind.processing,
          'card.generation-failed',
          'number',
          'valid-candidate-attempt-limit',
        );
      }
    }

    return CardGenerationResult(
      values: List.unmodifiable(values),
      network: request.network,
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

  String _readCandidate(CardNetwork network) {
    try {
      return _candidate(network);
    } on Object {
      throw const CardGenerationException(
        CardGenerationFailureKind.processing,
        'card.source-unavailable',
        'number',
        'candidate-source-failed',
      );
    }
  }

  bool _isValidCandidate(CardNetwork network, String value) {
    return cardTestNumberCatalogue[network]!.contains(value) &&
        _matchesNetwork(network, value) &&
        _passesLuhn(value);
  }

  bool _matchesNetwork(CardNetwork network, String value) {
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return false;
    }
    return switch (network) {
      CardNetwork.visa => value.length == 16 && value.startsWith('4'),
      CardNetwork.mastercard =>
        value.length == 16 &&
            (_inRange(value, 2, 51, 55) || _inRange(value, 4, 2221, 2720)),
      CardNetwork.americanExpress =>
        value.length == 15 &&
            (value.startsWith('34') || value.startsWith('37')),
      CardNetwork.discover =>
        value.length == 16 &&
            (value.startsWith('6011') ||
                value.startsWith('65') ||
                _inRange(value, 3, 644, 649) ||
                _inRange(value, 6, 622126, 622925)),
    };
  }

  bool _inRange(String value, int width, int minimum, int maximum) {
    if (value.length < width) return false;
    final prefix = int.parse(value.substring(0, width));
    return prefix >= minimum && prefix <= maximum;
  }

  bool _passesLuhn(String value) {
    var sum = 0;
    var doubleDigit = false;
    for (var index = value.length - 1; index >= 0; index--) {
      var digit = int.parse(value[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }
}

Never _throwResourceLimit() => throw const CardGenerationException(
  CardGenerationFailureKind.resource,
  'card.resource-limit',
  'numbers',
  'allocation-limit',
);
