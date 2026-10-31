enum ListCompareFailureKind { validation, resource }

final class ListCompareException implements Exception {
  const ListCompareException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final ListCompareFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class ListCompareRequest {
  const ListCompareRequest({
    required this.left,
    required this.right,
    this.caseMode = 'sensitive',
    this.whitespaceMode = 'preserve',
    this.duplicateMode = 'preserve',
  });

  final String left;
  final String right;
  final String caseMode;
  final String whitespaceMode;
  final String duplicateMode;
}

final class ListCompareResult {
  const ListCompareResult({
    required this.leftOnly,
    required this.rightOnly,
    required this.intersection,
    required this.equal,
    required this.caseMode,
    required this.whitespaceMode,
    required this.duplicateMode,
  });

  final List<String> leftOnly;
  final List<String> rightOnly;
  final List<String> intersection;
  final bool equal;
  final String caseMode;
  final String whitespaceMode;
  final String duplicateMode;
}

final class ListComparator {
  const ListComparator({
    this.maxInputCharacters,
    this.maxInputItems,
    this.maxResultItems,
  }) : assert(
         maxInputCharacters == null || maxInputCharacters >= 0,
         'maxInputCharacters must not be negative',
       ),
       assert(
         maxInputItems == null || maxInputItems >= 0,
         'maxInputItems must not be negative',
       ),
       assert(
         maxResultItems == null || maxResultItems >= 0,
         'maxResultItems must not be negative',
       );

  static const supportedCaseModes = {'sensitive', 'insensitive'};
  static const supportedWhitespaceModes = {'preserve', 'trim'};
  static const supportedDuplicateModes = {'preserve', 'distinct'};

  final int? maxInputCharacters;
  final int? maxInputItems;
  final int? maxResultItems;

  ListCompareResult compare(ListCompareRequest request) {
    _validateOption(request.caseMode, supportedCaseModes, 'caseMode');
    _validateOption(
      request.whitespaceMode,
      supportedWhitespaceModes,
      'whitespaceMode',
    );
    _validateOption(
      request.duplicateMode,
      supportedDuplicateModes,
      'duplicateMode',
    );

    if (maxInputCharacters case final maximum?
        when request.left.length + request.right.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'character-limit');
    }

    try {
      var left = _normalize(request.left, request);
      var right = _normalize(request.right, request);
      if (maxInputItems case final maximum?
          when left.length + right.length > maximum) {
        _throwResourceLimit(field: 'input', reason: 'item-limit');
      }

      if (request.duplicateMode == 'distinct') {
        left = _distinct(left);
        right = _distinct(right);
      }

      final rightCounts = _counts(right);
      final intersection = <String>[];
      final leftOnly = <String>[];
      for (final item in left) {
        final available = rightCounts[item.key] ?? 0;
        if (available > 0) {
          intersection.add(item.original);
          rightCounts[item.key] = available - 1;
        } else {
          leftOnly.add(item.original);
        }
      }

      final leftCounts = _counts(left);
      final rightOnly = <String>[];
      for (final item in right) {
        final available = leftCounts[item.key] ?? 0;
        if (available > 0) {
          leftCounts[item.key] = available - 1;
        } else {
          rightOnly.add(item.original);
        }
      }

      if (maxResultItems case final maximum?
          when leftOnly.length + rightOnly.length + intersection.length >
              maximum) {
        _throwResourceLimit(field: 'result', reason: 'result-limit');
      }

      return ListCompareResult(
        leftOnly: List.unmodifiable(leftOnly),
        rightOnly: List.unmodifiable(rightOnly),
        intersection: List.unmodifiable(intersection),
        equal: leftOnly.isEmpty && rightOnly.isEmpty,
        caseMode: request.caseMode,
        whitespaceMode: request.whitespaceMode,
        duplicateMode: request.duplicateMode,
      );
    } on ListCompareException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'result', reason: 'result-limit');
    }
  }

  List<_NormalizedItem> _normalize(String input, ListCompareRequest request) {
    final lines = input.isEmpty
        ? <String>[]
        : input.split(RegExp(r'\r\n|\r|\n'));
    return [
      for (final line in lines)
        _NormalizedItem(original: line, key: _normalizedKey(line, request)),
    ];
  }

  String _normalizedKey(String value, ListCompareRequest request) {
    var key = request.whitespaceMode == 'trim' ? value.trim() : value;
    if (request.caseMode == 'insensitive') key = key.toLowerCase();
    return key;
  }

  List<_NormalizedItem> _distinct(List<_NormalizedItem> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.key)) item,
    ];
  }

  Map<String, int> _counts(List<_NormalizedItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts.update(item.key, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  void _validateOption(String value, Set<String> supported, String field) {
    if (!supported.contains(value)) {
      throw ListCompareException(
        kind: ListCompareFailureKind.validation,
        code: 'list-compare.invalid-option',
        field: field,
        reason: 'unsupported-option',
      );
    }
  }

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw ListCompareException(
        kind: ListCompareFailureKind.resource,
        code: 'list-compare.resource-limit',
        field: field,
        reason: reason,
      );
}

final class _NormalizedItem {
  const _NormalizedItem({required this.original, required this.key});

  final String original;
  final String key;
}
