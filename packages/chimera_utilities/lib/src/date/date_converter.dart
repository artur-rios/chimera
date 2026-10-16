import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

enum DateRepresentation {
  iso8601('iso8601'),
  unixSeconds('unix-seconds'),
  unixMilliseconds('unix-milliseconds'),
  customPattern('custom');

  const DateRepresentation(this.identifier);

  final String identifier;

  static DateRepresentation? tryParse(String source) {
    final normalized = source.trim().toLowerCase();
    for (final value in values) {
      if (value.identifier == normalized) {
        return value;
      }
    }
    return null;
  }
}

enum DateConversionFailureKind { validation, range }

final class DateConversionException implements Exception {
  const DateConversionException({required this.kind, required this.code});

  final DateConversionFailureKind kind;
  final String code;

  @override
  String toString() => 'DateConversionException($kind, $code)';
}

final class DateConversionRequest {
  const DateConversionRequest({
    required this.value,
    required this.sourceRepresentation,
    required this.targetRepresentation,
    required this.sourceTimeZone,
    required this.targetTimeZone,
    this.sourcePattern,
    this.targetPattern,
  });

  final String value;
  final DateRepresentation sourceRepresentation;
  final DateRepresentation targetRepresentation;
  final String sourceTimeZone;
  final String targetTimeZone;
  final String? sourcePattern;
  final String? targetPattern;
}

final class DateConversion {
  const DateConversion({
    required this.convertedValue,
    required this.instantUtc,
    required this.sourceRepresentation,
    required this.targetRepresentation,
    required this.sourceTimeZone,
    required this.targetTimeZone,
    required this.targetOffset,
  });

  final String convertedValue;
  final DateTime instantUtc;
  final DateRepresentation sourceRepresentation;
  final DateRepresentation targetRepresentation;
  final String sourceTimeZone;
  final String targetTimeZone;
  final String targetOffset;

  String get utcIso8601 => instantUtc.toUtc().toIso8601String();
}

final class DateConverter {
  const DateConverter();

  DateConversion convert(DateConversionRequest request) {
    final sourceLocation = _resolveLocation(request.sourceTimeZone);
    final targetLocation = _resolveLocation(request.targetTimeZone);
    final instant = _parseInstant(request, sourceLocation).toUtc();
    _ensureSupportedInstant(instant);
    final target = time_zone.TZDateTime.from(instant, targetLocation);
    if (request.targetRepresentation == DateRepresentation.iso8601 ||
        request.targetRepresentation == DateRepresentation.customPattern) {
      _ensureSupportedLocalYear(target.year);
    }
    final converted = switch (request.targetRepresentation) {
      DateRepresentation.iso8601 => _formatIso(target),
      DateRepresentation.unixSeconds => _floorSeconds(
        instant.millisecondsSinceEpoch,
      ).toString(),
      DateRepresentation.unixMilliseconds =>
        instant.millisecondsSinceEpoch.toString(),
      DateRepresentation.customPattern => _formatCustom(
        target,
        request.targetPattern,
      ),
    };

    return DateConversion(
      convertedValue: converted,
      instantUtc: instant,
      sourceRepresentation: request.sourceRepresentation,
      targetRepresentation: request.targetRepresentation,
      sourceTimeZone: request.sourceTimeZone.trim(),
      targetTimeZone: request.targetTimeZone.trim(),
      targetOffset: _formatOffset(target.timeZoneOffset),
    );
  }

  DateTime _parseInstant(
    DateConversionRequest request,
    time_zone.Location sourceLocation,
  ) => switch (request.sourceRepresentation) {
    DateRepresentation.iso8601 => _parseIso(
      request.value.trim(),
      sourceLocation,
    ),
    DateRepresentation.unixSeconds => _parseEpoch(
      request.value,
      multiplier: 1000,
    ),
    DateRepresentation.unixMilliseconds => _parseEpoch(
      request.value,
      multiplier: 1,
    ),
    DateRepresentation.customPattern => _parseCustom(
      request.value.trim(),
      request.sourcePattern,
      sourceLocation,
    ),
  };
}

DateTime _parseIso(String source, time_zone.Location location) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?)?([zZ]|[+-]\d{2}:?\d{2})?$',
  ).firstMatch(source);
  if (match == null) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.invalid-value',
    );
  }
  final parts = _partsFromMatch(match);
  _validateParts(parts);
  if (match.group(8) != null) {
    final parsed = DateTime.tryParse(source);
    if (parsed == null) {
      throw const DateConversionException(
        kind: DateConversionFailureKind.validation,
        code: 'date.invalid-value',
      );
    }
    return parsed.toUtc();
  }
  return _resolveWallClock(parts, location);
}

DateTime _parseCustom(
  String source,
  String? pattern,
  time_zone.Location location,
) {
  final approved = _validatePattern(pattern);
  if (!approved.inputExpression.hasMatch(source)) {
    _invalidValue();
  }
  try {
    final parsed = DateFormat(
      approved.source,
      'en_US',
    ).parseStrict(source, true);
    return _resolveWallClock(
      _DateParts(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      ),
      location,
    );
  } on DateConversionException {
    rethrow;
  } on FormatException {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.invalid-value',
    );
  }
}

DateTime _parseEpoch(String source, {required int multiplier}) {
  final trimmed = source.trim();
  if (!RegExp(r'^-?\d+$').hasMatch(trimmed)) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.invalid-epoch',
    );
  }
  final milliseconds = BigInt.parse(trimmed) * BigInt.from(multiplier);
  _ensureSupportedBigIntRange(milliseconds);
  return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt(), isUtc: true);
}

String _formatCustom(time_zone.TZDateTime value, String? pattern) {
  final approved = _validatePattern(pattern);
  return DateFormat(approved.source, 'en_US').format(value);
}

_ApprovedPattern _validatePattern(String? source) {
  final pattern = source?.trim() ?? '';
  if (pattern.isEmpty) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.invalid-pattern',
    );
  }
  const tokens = <String>['yyyy', 'SSS', 'MM', 'dd', 'HH', 'mm', 'ss'];
  final counts = <String, int>{};
  final expression = StringBuffer('^');
  var index = 0;
  while (index < pattern.length) {
    if (pattern[index] == "'") {
      index++;
      final literal = StringBuffer();
      var closed = false;
      while (index < pattern.length) {
        if (pattern[index] != "'") {
          literal.write(pattern[index]);
          index++;
          continue;
        }
        if (index + 1 < pattern.length && pattern[index + 1] == "'") {
          literal.write("'");
          index += 2;
          continue;
        }
        index++;
        closed = true;
        break;
      }
      if (!closed) {
        _invalidPattern();
      }
      expression.write(RegExp.escape(literal.toString()));
      continue;
    }

    String? matchedToken;
    for (final token in tokens) {
      if (pattern.startsWith(token, index)) {
        matchedToken = token;
        break;
      }
    }
    if (matchedToken != null) {
      counts[matchedToken] = (counts[matchedToken] ?? 0) + 1;
      final width = matchedToken == 'yyyy'
          ? 4
          : matchedToken == 'SSS'
          ? 3
          : 2;
      expression.write('[0-9]{$width}');
      index += matchedToken.length;
      continue;
    }

    final literal = pattern[index];
    if (!RegExp(r'^[ T:/.-]$').hasMatch(literal)) {
      _invalidPattern();
    }
    expression.write(RegExp.escape(literal));
    index++;
  }
  expression.write(r'$');
  final hasRequiredDate =
      counts['yyyy'] == 1 && counts['MM'] == 1 && counts['dd'] == 1;
  final hasDuplicate = counts.values.any((count) => count > 1);
  if (!hasRequiredDate || hasDuplicate) {
    _invalidPattern();
  }
  return _ApprovedPattern(pattern, RegExp(expression.toString()));
}

time_zone.Location _resolveLocation(String source) {
  _initializeDateTimeZones();
  final identifier = source.trim();
  if (identifier == 'UTC') {
    return time_zone.UTC;
  }
  try {
    return time_zone.getLocation(identifier);
  } on time_zone.LocationNotFoundException {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.invalid-time-zone',
    );
  }
}

DateTime _resolveWallClock(_DateParts parts, time_zone.Location location) {
  final wallClockMilliseconds = DateTime.utc(
    parts.year,
    parts.month,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
    parts.millisecond,
  ).millisecondsSinceEpoch;
  final offsets = <int>{
    for (final zone in location.zones) zone.offset.inMilliseconds,
    location.timeZone(wallClockMilliseconds).offset.inMilliseconds,
  };
  final matches = <DateTime>[];
  final seen = <int>{};
  for (final offset in offsets) {
    final instantMilliseconds = wallClockMilliseconds - offset;
    final local = time_zone.TZDateTime.fromMillisecondsSinceEpoch(
      location,
      instantMilliseconds,
    );
    if (local.year == parts.year &&
        local.month == parts.month &&
        local.day == parts.day &&
        local.hour == parts.hour &&
        local.minute == parts.minute &&
        local.second == parts.second &&
        local.millisecond == parts.millisecond &&
        seen.add(instantMilliseconds)) {
      matches.add(local.toUtc());
    }
  }
  if (matches.isEmpty) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.nonexistent-local-time',
    );
  }
  if (matches.length > 1) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.validation,
      code: 'date.ambiguous-local-time',
    );
  }
  return matches.single;
}

_DateParts _partsFromMatch(RegExpMatch match) {
  final fraction = (match.group(7) ?? '').padRight(3, '0');
  return _DateParts(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4) ?? '0'),
    int.parse(match.group(5) ?? '0'),
    int.parse(match.group(6) ?? '0'),
    fraction.isEmpty ? 0 : int.parse(fraction),
  );
}

void _validateParts(_DateParts parts) {
  if (parts.year < 1 ||
      parts.month < 1 ||
      parts.month > 12 ||
      parts.day < 1 ||
      parts.hour > 23 ||
      parts.minute > 59 ||
      parts.second > 59) {
    _invalidValue();
  }
  final normalized = DateTime.utc(parts.year, parts.month, parts.day);
  if (normalized.year != parts.year ||
      normalized.month != parts.month ||
      normalized.day != parts.day) {
    _invalidValue();
  }
}

Never _invalidValue() => throw const DateConversionException(
  kind: DateConversionFailureKind.validation,
  code: 'date.invalid-value',
);

int _floorSeconds(int milliseconds) =>
    milliseconds >= 0 ? milliseconds ~/ 1000 : -((-milliseconds + 999) ~/ 1000);

String _formatIso(time_zone.TZDateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  String three(int part) => part.toString().padLeft(3, '0');
  return '${value.year.toString().padLeft(4, '0')}-'
      '${two(value.month)}-${two(value.day)}T${two(value.hour)}:'
      '${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}'
      '${_formatOffset(value.timeZoneOffset)}';
}

String _formatOffset(Duration offset) {
  String two(int part) => part.toString().padLeft(2, '0');
  final minutes = offset.inMinutes;
  final absolute = minutes.abs();
  return '${minutes < 0 ? '-' : '+'}${two(absolute ~/ 60)}:'
      '${two(absolute % 60)}';
}

final class _DateParts {
  const _DateParts(
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
    this.second,
    this.millisecond,
  );

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;
  final int millisecond;
}

final class _ApprovedPattern {
  const _ApprovedPattern(this.source, this.inputExpression);

  final String source;
  final RegExp inputExpression;
}

final BigInt _minimumMilliseconds = BigInt.from(
  DateTime.utc(1).millisecondsSinceEpoch,
);
final BigInt _maximumMilliseconds = BigInt.from(
  DateTime.utc(9999, 12, 31, 23, 59, 59, 999).millisecondsSinceEpoch,
);

void _ensureSupportedBigIntRange(BigInt milliseconds) {
  if (milliseconds < _minimumMilliseconds ||
      milliseconds > _maximumMilliseconds) {
    throw const DateConversionException(
      kind: DateConversionFailureKind.range,
      code: 'date.out-of-range',
    );
  }
}

void _ensureSupportedInstant(DateTime instant) {
  if (instant.isBefore(_minimumInstant) || instant.isAfter(_maximumInstant)) {
    _outOfRange();
  }
}

final DateTime _minimumInstant = DateTime.utc(1);
final DateTime _maximumInstant = DateTime.utc(9999, 12, 31, 23, 59, 59, 999);

void _ensureSupportedLocalYear(int year) {
  if (year < 1 || year > 9999) {
    _outOfRange();
  }
}

Never _outOfRange() => throw const DateConversionException(
  kind: DateConversionFailureKind.range,
  code: 'date.out-of-range',
);

Never _invalidPattern() => throw const DateConversionException(
  kind: DateConversionFailureKind.validation,
  code: 'date.invalid-pattern',
);

bool _dateTimeZonesInitialized = false;

void _initializeDateTimeZones() {
  if (_dateTimeZonesInitialized) {
    return;
  }
  time_zone_data.initializeTimeZones();
  _dateTimeZonesInitialized = true;
}
