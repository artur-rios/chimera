enum NumberBaseFailureKind { validation, resource }

final class NumberBaseException implements Exception {
  const NumberBaseException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final NumberBaseFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class NumberBaseRequest {
  const NumberBaseRequest({
    required this.value,
    required this.sourceBase,
    required this.targetBase,
  });

  final String value;
  final int sourceBase;
  final int targetBase;
}

final class NumberBaseResult {
  const NumberBaseResult({
    required this.converted,
    required this.sourceBase,
    required this.targetBase,
  });

  final String converted;
  final int sourceBase;
  final int targetBase;
}

final class NumberBaseConverter {
  const NumberBaseConverter({this.maxInputCharacters, this.maxOutputCharacters})
    : assert(
        maxInputCharacters == null || maxInputCharacters >= 0,
        'maxInputCharacters must not be negative',
      ),
      assert(
        maxOutputCharacters == null || maxOutputCharacters >= 0,
        'maxOutputCharacters must not be negative',
      );

  final int? maxInputCharacters;
  final int? maxOutputCharacters;

  NumberBaseResult convert(NumberBaseRequest request) {
    _validateBase(request.sourceBase, 'sourceBase');
    _validateBase(request.targetBase, 'targetBase');

    if (maxInputCharacters case final maximum?
        when request.value.length > maximum) {
      _throwResourceLimit(field: 'value', reason: 'input-limit');
    }

    final value = request.value.trim();
    if (value.isEmpty ||
        value == '+' ||
        value == '-' ||
        value.length == 1 && _isSign(value.codeUnitAt(0))) {
      _throwInvalidValue('missing-value');
    }

    var digitStart = 0;
    if (_isSign(value.codeUnitAt(0))) digitStart = 1;
    for (var index = digitStart; index < value.length; index++) {
      final digit = _digitValue(value.codeUnitAt(index));
      if (digit < 0 || digit >= request.sourceBase) {
        _throwInvalidValue('invalid-digit');
      }
    }

    try {
      final parsed = BigInt.parse(value, radix: request.sourceBase);
      final converted = maxOutputCharacters == null
          ? parsed.toRadixString(request.targetBase)
          : _encodeWithinBudget(
              parsed,
              request.targetBase,
              maxOutputCharacters!,
            );
      return NumberBaseResult(
        converted: converted,
        sourceBase: request.sourceBase,
        targetBase: request.targetBase,
      );
    } on NumberBaseException {
      rethrow;
    } on FormatException {
      _throwInvalidValue('invalid-digit');
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'converted', reason: 'output-limit');
    }
  }

  void _validateBase(int base, String field) {
    if (base < 2 || base > 36) {
      throw NumberBaseException(
        kind: NumberBaseFailureKind.validation,
        code: 'number-base.invalid-base',
        field: field,
        reason: 'out-of-range-base',
      );
    }
  }

  String _encodeWithinBudget(BigInt value, int base, int maximumLength) {
    if (value == BigInt.zero) {
      if (maximumLength < 1) {
        _throwResourceLimit(field: 'converted', reason: 'output-limit');
      }
      return '0';
    }

    final negative = value.isNegative;
    final digitBudget = maximumLength - (negative ? 1 : 0);
    if (digitBudget < 1) {
      _throwResourceLimit(field: 'converted', reason: 'output-limit');
    }

    final radix = BigInt.from(base);
    final reversedDigits = <int>[];
    var remaining = value.abs();
    while (remaining > BigInt.zero) {
      if (reversedDigits.length >= digitBudget) {
        _throwResourceLimit(field: 'converted', reason: 'output-limit');
      }
      final digit = (remaining % radix).toInt();
      reversedDigits.add(digit < 10 ? 0x30 + digit : 0x61 + digit - 10);
      remaining ~/= radix;
    }

    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    for (var index = reversedDigits.length - 1; index >= 0; index--) {
      buffer.writeCharCode(reversedDigits[index]);
    }
    return buffer.toString();
  }

  bool _isSign(int codeUnit) => codeUnit == 0x2B || codeUnit == 0x2D;

  int _digitValue(int codeUnit) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
    if (codeUnit >= 0x41 && codeUnit <= 0x5A) return codeUnit - 0x41 + 10;
    if (codeUnit >= 0x61 && codeUnit <= 0x7A) return codeUnit - 0x61 + 10;
    return -1;
  }

  Never _throwInvalidValue(String reason) => throw NumberBaseException(
    kind: NumberBaseFailureKind.validation,
    code: 'number-base.invalid-value',
    field: 'value',
    reason: reason,
  );

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw NumberBaseException(
        kind: NumberBaseFailureKind.resource,
        code: 'number-base.resource-limit',
        field: field,
        reason: reason,
      );
}
