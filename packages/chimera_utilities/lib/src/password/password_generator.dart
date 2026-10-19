import 'dart:math';

import 'package:meta/meta.dart';

typedef PasswordRandomInt = int Function(int upperBound);

enum PasswordFailureKind { validation, processing, resource }

/// Contains only fixed, non-sensitive diagnostic identifiers.
final class PasswordException implements Exception {
  const PasswordException(this.kind, this.code, this.field, this.reason);

  final PasswordFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'PasswordException($code, $field, $reason)';
}

final class PasswordRequest {
  const PasswordRequest({
    this.length = 16,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;
}

final class PasswordResult {
  const PasswordResult({
    required this.password,
    required this.length,
    required this.characterClasses,
  });

  final String password;
  final int length;
  final List<String> characterClasses;
}

final Random _secureRandom = Random.secure();

int _secureRandomInt(int upperBound) => _secureRandom.nextInt(upperBound);

/// Stateless constrained password generation over an injectable entropy source.
final class PasswordGenerator {
  const PasswordGenerator() : this._(_secureRandomInt);

  const PasswordGenerator._(this._randomInt);

  @visibleForTesting
  const PasswordGenerator.forTesting({required PasswordRandomInt randomInt})
    : this._(randomInt);

  static const _classes = <String, String>{
    'lowercase': 'abcdefghijklmnopqrstuvwxyz',
    'uppercase': 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'digits': '0123456789',
    'symbols': r'!@#$%^&*()-_=+[]{}:,.?',
  };
  static const _maximumCandidateAttempts = 1024;

  final PasswordRandomInt _randomInt;

  PasswordResult generate(PasswordRequest request) {
    if (request.length < 1) {
      throw const PasswordException(
        PasswordFailureKind.validation,
        'password.invalid-length',
        'length',
        'positive-integer-required',
      );
    }
    final selected = <MapEntry<String, String>>[
      if (request.lowercase) MapEntry('lowercase', _classes['lowercase']!),
      if (request.uppercase) MapEntry('uppercase', _classes['uppercase']!),
      if (request.digits) MapEntry('digits', _classes['digits']!),
      if (request.symbols) MapEntry('symbols', _classes['symbols']!),
    ];
    if (selected.isEmpty) {
      throw const PasswordException(
        PasswordFailureKind.validation,
        'password.no-character-classes',
        'characterClasses',
        'at-least-one-required',
      );
    }
    if (request.length < selected.length) {
      throw const PasswordException(
        PasswordFailureKind.validation,
        'password.impossible-constraints',
        'length',
        'shorter-than-required-classes',
      );
    }

    try {
      final available = selected.map((entry) => entry.value).join();
      for (var attempt = 0; attempt < _maximumCandidateAttempts; attempt++) {
        final characters = List<String>.generate(
          request.length,
          (_) => _pick(available),
          growable: false,
        );
        if (!selected.every((entry) => characters.any(entry.value.contains))) {
          continue;
        }
        return PasswordResult(
          password: characters.join(),
          length: request.length,
          characterClasses: List.unmodifiable(
            selected.map((entry) => entry.key),
          ),
        );
      }
      throw const PasswordException(
        PasswordFailureKind.processing,
        'password.random-unavailable',
        'random',
        'coverage-attempt-limit',
      );
    } on PasswordException {
      rethrow;
    } on OutOfMemoryError {
      throw const PasswordException(
        PasswordFailureKind.resource,
        'password.resource-limit',
        'password',
        'allocation-limit',
      );
    } on Object {
      throw const PasswordException(
        PasswordFailureKind.processing,
        'password.random-unavailable',
        'random',
        'secure-random-failed',
      );
    }
  }

  String _pick(String characters) => characters[_draw(characters.length)];

  int _draw(int upperBound) {
    final value = _randomInt(upperBound);
    if (value < 0 || value >= upperBound) {
      throw const PasswordException(
        PasswordFailureKind.processing,
        'password.random-unavailable',
        'random',
        'out-of-range-value',
      );
    }
    return value;
  }
}
