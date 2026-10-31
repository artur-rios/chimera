import 'dart:math';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

typedef UuidRandomBytes = List<int> Function();
typedef UuidClock = int Function();
typedef UuidResultAllocator = List<String> Function(int count);

enum UuidVersion { v4, v7 }

enum UuidRepresentation { uuid, guid }

enum UuidGenerationFailureKind { validation, processing, resource }

/// Contains only fixed, non-sensitive diagnostic identifiers.
final class UuidGenerationException implements Exception {
  const UuidGenerationException(this.kind, this.code, this.field, this.reason);

  final UuidGenerationFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'UuidGenerationException($code, $field, $reason)';
}

final class UuidGenerationRequest {
  const UuidGenerationRequest({
    this.version = UuidVersion.v4,
    this.representation = UuidRepresentation.uuid,
    this.count = 1,
  });

  final UuidVersion version;
  final UuidRepresentation representation;
  final int count;
}

final class UuidGenerationResult {
  const UuidGenerationResult({
    required this.values,
    required this.version,
    required this.representation,
  });

  final List<String> values;
  final UuidVersion version;
  final UuidRepresentation representation;
}

final Random _secureRandom = Random.secure();

List<int> _secureRandomBytes() =>
    List<int>.generate(16, (_) => _secureRandom.nextInt(256), growable: false);

int _currentMilliseconds() => DateTime.timestamp().millisecondsSinceEpoch;

List<String> _allocateResults(int count) =>
    List<String>.filled(count, '', growable: false);

/// Stateless UUID/GUID generation over injectable entropy and clock boundaries.
final class UuidGenerator {
  const UuidGenerator()
    : this._(_secureRandomBytes, _currentMilliseconds, _allocateResults);

  const UuidGenerator._(
    this._randomBytes,
    this._nowMilliseconds,
    this._allocate,
  );

  @visibleForTesting
  const UuidGenerator.forTesting({
    required UuidRandomBytes randomBytes,
    required UuidClock nowMilliseconds,
    UuidResultAllocator allocate = _allocateResults,
  }) : this._(randomBytes, nowMilliseconds, allocate);

  static const _maximumCollisionAttempts = 1024;

  final UuidRandomBytes _randomBytes;
  final UuidClock _nowMilliseconds;
  final UuidResultAllocator _allocate;

  UuidGenerationResult generate(UuidGenerationRequest request) {
    if (request.count < 1) {
      throw const UuidGenerationException(
        UuidGenerationFailureKind.validation,
        'uuid.invalid-count',
        'count',
        'positive-integer-required',
      );
    }

    final values = _allocateBatch(request.count);
    final generated = <String>{};
    for (var index = 0; index < request.count; index++) {
      var accepted = false;
      for (var attempt = 0; attempt < _maximumCollisionAttempts; attempt++) {
        final canonical = _generateCanonical(request.version);
        if (!generated.add(canonical)) {
          continue;
        }
        values[index] = _represent(canonical, request.representation);
        accepted = true;
        break;
      }
      if (!accepted) {
        throw const UuidGenerationException(
          UuidGenerationFailureKind.processing,
          'uuid.generation-failed',
          'random',
          'collision-attempt-limit',
        );
      }
    }

    return UuidGenerationResult(
      values: List.unmodifiable(values),
      version: request.version,
      representation: request.representation,
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

  String _generateCanonical(UuidVersion version) {
    final bytes = _readRandomBytes();
    if (version == UuidVersion.v4) {
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
    } else {
      final milliseconds = _readMilliseconds();
      var remainingMilliseconds = milliseconds;
      for (var index = 5; index >= 0; index--) {
        bytes[index] = remainingMilliseconds % 256;
        remainingMilliseconds ~/= 256;
      }
      bytes[6] = (bytes[6] & 0x0f) | 0x70;
    }
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    try {
      return Uuid.unparse(bytes);
    } on Object {
      throw const UuidGenerationException(
        UuidGenerationFailureKind.processing,
        'uuid.generation-failed',
        'identifier',
        'formatting-failed',
      );
    }
  }

  List<int> _readRandomBytes() {
    try {
      final bytes = List<int>.of(_randomBytes(), growable: false);
      if (bytes.length != 16 || bytes.any((byte) => byte < 0 || byte > 255)) {
        throw const UuidGenerationException(
          UuidGenerationFailureKind.processing,
          'uuid.random-unavailable',
          'random',
          'sixteen-byte-value-required',
        );
      }
      return bytes;
    } on UuidGenerationException {
      rethrow;
    } on Object {
      throw const UuidGenerationException(
        UuidGenerationFailureKind.processing,
        'uuid.random-unavailable',
        'random',
        'secure-random-failed',
      );
    }
  }

  int _readMilliseconds() {
    try {
      final milliseconds = _nowMilliseconds();
      if (milliseconds < 0 || milliseconds > 0xffffffffffff) {
        throw const UuidGenerationException(
          UuidGenerationFailureKind.processing,
          'uuid.time-unavailable',
          'time',
          'unix-milliseconds-out-of-range',
        );
      }
      return milliseconds;
    } on UuidGenerationException {
      rethrow;
    } on Object {
      throw const UuidGenerationException(
        UuidGenerationFailureKind.processing,
        'uuid.time-unavailable',
        'time',
        'clock-failed',
      );
    }
  }

  String _represent(String canonical, UuidRepresentation representation) {
    return switch (representation) {
      UuidRepresentation.uuid => canonical,
      UuidRepresentation.guid => '{${canonical.toUpperCase()}}',
    };
  }
}

Never _throwResourceLimit() => throw const UuidGenerationException(
  UuidGenerationFailureKind.resource,
  'uuid.resource-limit',
  'identifiers',
  'allocation-limit',
);
