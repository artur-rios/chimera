import 'package:meta/meta.dart';

enum LoremFailureKind { validation, resource }

/// Contains only fixed, non-sensitive diagnostic identifiers.
final class LoremException implements Exception {
  const LoremException(this.kind, this.code, this.field, this.reason);
  final LoremFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

final class LoremRequest {
  const LoremRequest({this.unit = 'paragraphs', this.count = 1});
  final String unit;
  final int count;
}

final class LoremResult {
  const LoremResult({
    required this.unit,
    required this.count,
    required this.text,
  });
  final String unit;
  final int count;
  final String text;
}

/// Deterministic public-domain Latin fragments; no randomness or retained state.
final class LoremGenerator {
  const LoremGenerator({this.maxOutputCharacters}) : _allocate = _generate;

  @visibleForTesting
  const LoremGenerator.forTesting({
    required this._allocate,
    this.maxOutputCharacters,
  });

  /// Optional test/caller budget. Production imposes no arbitrary count ceiling.
  final int? maxOutputCharacters;
  final String Function(LoremRequest) _allocate;

  LoremResult generate(LoremRequest request) {
    if (!const ['words', 'sentences', 'paragraphs'].contains(request.unit)) {
      throw const LoremException(
        LoremFailureKind.validation,
        'lorem.invalid-unit',
        'unit',
        'unsupported-unit',
      );
    }
    if (request.count < 1) {
      throw const LoremException(
        LoremFailureKind.validation,
        'lorem.invalid-count',
        'count',
        'positive-integer-required',
      );
    }
    try {
      // Divide instead of multiplying so extremely large valid counts cannot
      // overflow native integer arithmetic during budget preflight.
      final minimum = switch (request.unit) {
        'words' => 3,
        'sentences' => 27,
        _ => 55,
      };
      if (maxOutputCharacters case final maximum?
          when request.count > maximum ~/ minimum) {
        _resource('output-limit');
      }
      final text = _allocate(request);
      if (maxOutputCharacters case final maximum? when text.length > maximum) {
        _resource('output-limit');
      }
      return LoremResult(unit: request.unit, count: request.count, text: text);
    } on OutOfMemoryError {
      _resource('allocation-limit');
    }
  }
}

Never _resource(String reason) => throw LoremException(
  LoremFailureKind.resource,
  'lorem.resource-limit',
  'text',
  reason,
);

String _generate(LoremRequest request) {
  const words = [
    'Lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'consectetur',
    'adipiscing',
    'elit',
  ];
  const sentences = [
    'Lorem ipsum dolor sit amet.',
    'Consectetur adipiscing elit.',
  ];
  const paragraph = 'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.';
  final buffer = StringBuffer();
  for (var index = 0; index < request.count; index++) {
    if (index != 0) buffer.write(request.unit == 'paragraphs' ? '\n\n' : ' ');
    buffer.write(switch (request.unit) {
      'words' => words[index % words.length],
      'sentences' => sentences[index % sentences.length],
      _ => paragraph,
    });
  }
  return buffer.toString();
}
