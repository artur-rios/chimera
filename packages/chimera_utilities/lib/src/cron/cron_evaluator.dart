import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

enum CronEvaluationFailureKind { validation, resource }

final class CronEvaluationException implements Exception {
  const CronEvaluationException({required this.kind, required this.code});

  final CronEvaluationFailureKind kind;
  final String code;

  @override
  String toString() => 'CronEvaluationException($kind, $code)';
}

final class CronEvaluationRequest {
  const CronEvaluationRequest({
    required this.expression,
    required this.timeZone,
    required this.occurrenceCount,
    required this.referenceUtc,
  });

  final String expression;
  final String timeZone;
  final int occurrenceCount;
  final DateTime referenceUtc;
}

final class CronOccurrence {
  const CronOccurrence({
    required this.instantUtc,
    required this.localIso8601,
    required this.timeZoneAbbreviation,
  });

  final DateTime instantUtc;
  final String localIso8601;
  final String timeZoneAbbreviation;

  String get utcIso8601 => instantUtc.toUtc().toIso8601String();
}

final class CronEvaluation {
  CronEvaluation({
    required this.normalizedExpression,
    required this.timeZone,
    required this.hasSeconds,
    required Map<String, String> fields,
    required List<CronOccurrence> previous,
    required List<CronOccurrence> next,
  }) : fields = Map<String, String>.unmodifiable(fields),
       previous = List<CronOccurrence>.unmodifiable(previous),
       next = List<CronOccurrence>.unmodifiable(next);

  final String normalizedExpression;
  final String timeZone;
  final bool hasSeconds;
  final Map<String, String> fields;
  final List<CronOccurrence> previous;
  final List<CronOccurrence> next;
}

final class CronEvaluator {
  const CronEvaluator({this.maxSearchDays = 292194});

  final int maxSearchDays;

  CronEvaluation evaluate(CronEvaluationRequest request) {
    if (request.occurrenceCount < 1 || request.occurrenceCount > 100) {
      throw const CronEvaluationException(
        kind: CronEvaluationFailureKind.validation,
        code: 'cron.invalid-count',
      );
    }
    if (maxSearchDays < 1) {
      throw const CronEvaluationException(
        kind: CronEvaluationFailureKind.resource,
        code: 'cron.search-limit',
      );
    }

    final schedule = _CronSchedule.parse(request.expression);
    final location = _resolveLocation(request.timeZone);
    final referenceUtc = request.referenceUtc.toUtc();
    final previous = _findOccurrences(
      schedule: schedule,
      location: location,
      referenceUtc: referenceUtc,
      count: request.occurrenceCount,
      direction: _SearchDirection.previous,
    );
    final next = _findOccurrences(
      schedule: schedule,
      location: location,
      referenceUtc: referenceUtc,
      count: request.occurrenceCount,
      direction: _SearchDirection.next,
    );

    return CronEvaluation(
      normalizedExpression: schedule.normalizedExpression,
      timeZone: request.timeZone.trim(),
      hasSeconds: schedule.hasSeconds,
      fields: schedule.normalizedFields,
      previous: previous,
      next: next,
    );
  }

  time_zone.Location _resolveLocation(String identifier) {
    _initializeTimeZones();
    if (identifier.trim() == 'UTC') {
      return time_zone.UTC;
    }
    try {
      return time_zone.getLocation(identifier.trim());
    } on time_zone.LocationNotFoundException {
      throw const CronEvaluationException(
        kind: CronEvaluationFailureKind.validation,
        code: 'cron.invalid-time-zone',
      );
    }
  }

  List<CronOccurrence> _findOccurrences({
    required _CronSchedule schedule,
    required time_zone.Location location,
    required DateTime referenceUtc,
    required int count,
    required _SearchDirection direction,
  }) {
    final referenceLocal = time_zone.TZDateTime.from(referenceUtc, location);
    final startDate = DateTime.utc(
      referenceLocal.year,
      referenceLocal.month,
      referenceLocal.day,
    );
    final occurrences = <CronOccurrence>[];

    for (var dayOffset = 0; dayOffset < maxSearchDays; dayOffset++) {
      final date = startDate.add(
        Duration(
          days: direction == _SearchDirection.next ? dayOffset : -dayOffset,
        ),
      );
      if (!schedule.matchesDate(date)) {
        continue;
      }

      final matchingDayInstants = <time_zone.TZDateTime>[];
      for (final hour in schedule.hours.values) {
        for (final minute in schedule.minutes.values) {
          for (final second in schedule.seconds.values) {
            matchingDayInstants.addAll(
              _matchingWallClocks(
                location: location,
                year: date.year,
                month: date.month,
                day: date.day,
                hour: hour,
                minute: minute,
                second: second,
              ),
            );
          }
        }
      }
      matchingDayInstants.sort((left, right) => left.compareTo(right));
      final orderedDayInstants = direction == _SearchDirection.next
          ? matchingDayInstants
          : matchingDayInstants.reversed;
      for (final local in orderedDayInstants) {
        final instant = local.toUtc();
        final isOnRequestedSide = direction == _SearchDirection.next
            ? instant.isAfter(referenceUtc)
            : instant.isBefore(referenceUtc);
        if (!isOnRequestedSide) {
          continue;
        }

        occurrences.add(
          CronOccurrence(
            instantUtc: instant,
            localIso8601: _formatLocal(local),
            timeZoneAbbreviation: local.timeZoneName,
          ),
        );
        if (occurrences.length == count) {
          return occurrences;
        }
      }
    }

    throw const CronEvaluationException(
      kind: CronEvaluationFailureKind.resource,
      code: 'cron.search-limit',
    );
  }
}

List<time_zone.TZDateTime> _matchingWallClocks({
  required time_zone.Location location,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int second,
}) {
  final wallClockMilliseconds = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).millisecondsSinceEpoch;
  final offsets = <int>{
    for (final zone in location.zones) zone.offset.inMilliseconds,
    location.timeZone(wallClockMilliseconds).offset.inMilliseconds,
  };
  final matches = <time_zone.TZDateTime>[];
  final seenInstants = <int>{};

  for (final offset in offsets) {
    final instantMilliseconds = wallClockMilliseconds - offset;
    final local = time_zone.TZDateTime.fromMillisecondsSinceEpoch(
      location,
      instantMilliseconds,
    );
    if (local.year == year &&
        local.month == month &&
        local.day == day &&
        local.hour == hour &&
        local.minute == minute &&
        local.second == second &&
        seenInstants.add(instantMilliseconds)) {
      matches.add(local);
    }
  }

  matches.sort((left, right) => left.compareTo(right));
  return matches;
}

enum _SearchDirection { previous, next }

String _formatLocal(time_zone.TZDateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  String three(int part) => part.toString().padLeft(3, '0');
  final offsetMinutes = value.timeZoneOffset.inMinutes;
  final offsetSign = offsetMinutes < 0 ? '-' : '+';
  final absoluteOffset = offsetMinutes.abs();
  final offset =
      '$offsetSign${two(absoluteOffset ~/ 60)}:'
      '${two(absoluteOffset % 60)}';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${two(value.month)}-${two(value.day)}T${two(value.hour)}:'
      '${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}'
      '$offset';
}

bool _timeZonesInitialized = false;

void _initializeTimeZones() {
  if (_timeZonesInitialized) {
    return;
  }
  time_zone_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

final class _CronSchedule {
  _CronSchedule({
    required this.hasSeconds,
    required this.seconds,
    required this.minutes,
    required this.hours,
    required this.daysOfMonth,
    required this.months,
    required this.daysOfWeek,
  });

  factory _CronSchedule.parse(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5 && parts.length != 6) {
      throw const CronEvaluationException(
        kind: CronEvaluationFailureKind.validation,
        code: 'cron.invalid-field-count',
      );
    }

    final hasSeconds = parts.length == 6;
    final offset = hasSeconds ? 0 : -1;
    final seconds = hasSeconds
        ? _CronField.parse(parts[0], _CronFieldDefinition.seconds)
        : _CronField.single(0, _CronFieldDefinition.seconds);
    return _CronSchedule(
      hasSeconds: hasSeconds,
      seconds: seconds,
      minutes: _CronField.parse(
        parts[1 + offset],
        _CronFieldDefinition.minutes,
      ),
      hours: _CronField.parse(parts[2 + offset], _CronFieldDefinition.hours),
      daysOfMonth: _CronField.parse(
        parts[3 + offset],
        _CronFieldDefinition.daysOfMonth,
      ),
      months: _CronField.parse(parts[4 + offset], _CronFieldDefinition.months),
      daysOfWeek: _CronField.parse(
        parts[5 + offset],
        _CronFieldDefinition.daysOfWeek,
      ),
    );
  }

  final bool hasSeconds;
  final _CronField seconds;
  final _CronField minutes;
  final _CronField hours;
  final _CronField daysOfMonth;
  final _CronField months;
  final _CronField daysOfWeek;

  String get normalizedExpression {
    final values = <String>[
      if (hasSeconds) seconds.normalized,
      minutes.normalized,
      hours.normalized,
      daysOfMonth.normalized,
      months.normalized,
      daysOfWeek.normalized,
    ];
    return values.join(' ');
  }

  Map<String, String> get normalizedFields => <String, String>{
    'seconds': seconds.normalized,
    'minute': minutes.normalized,
    'hour': hours.normalized,
    'dayOfMonth': daysOfMonth.normalized,
    'month': months.normalized,
    'dayOfWeek': daysOfWeek.normalized,
  };

  bool matchesDate(DateTime date) {
    if (!months.values.contains(date.month)) {
      return false;
    }
    final dayOfMonthMatches = daysOfMonth.values.contains(date.day);
    final cronWeekday = date.weekday == DateTime.sunday ? 0 : date.weekday;
    final dayOfWeekMatches = daysOfWeek.values.contains(cronWeekday);
    if (daysOfMonth.startsWithWildcard && daysOfWeek.startsWithWildcard) {
      return true;
    }
    if (daysOfMonth.startsWithWildcard) {
      return dayOfWeekMatches;
    }
    if (daysOfWeek.startsWithWildcard) {
      return dayOfMonthMatches;
    }
    return dayOfMonthMatches || dayOfWeekMatches;
  }
}

final class _CronField {
  _CronField({
    required this.values,
    required this.normalized,
    required this.startsWithWildcard,
  });

  factory _CronField.single(int value, _CronFieldDefinition definition) =>
      _CronField(
        values: <int>{value},
        normalized: value.toString(),
        startsWithWildcard: false,
      );

  factory _CronField.parse(String source, _CronFieldDefinition definition) {
    try {
      final values = <int>{};
      final normalizedSegments = <String>[];
      for (final rawSegment in source.split(',')) {
        if (rawSegment.isEmpty) {
          throw const FormatException();
        }
        final stepParts = rawSegment.split('/');
        if (stepParts.length > 2 || stepParts.first.isEmpty) {
          throw const FormatException();
        }
        final step = stepParts.length == 2 ? int.parse(stepParts[1]) : 1;
        if (step < 1) {
          throw const FormatException();
        }

        final base = stepParts.first;
        late int start;
        late int end;
        String normalizedBase;
        if (base == '*') {
          start = definition.minimum;
          end = definition.maximum;
          normalizedBase = '*';
        } else if (base.contains('-')) {
          final range = base.split('-');
          if (range.length != 2) {
            throw const FormatException();
          }
          start = definition.parseValue(range[0]);
          end = definition.parseValue(range[1]);
          if (start > end) {
            throw const FormatException();
          }
          normalizedBase = '$start-$end';
        } else {
          start = definition.parseValue(base);
          end = stepParts.length == 2 ? definition.maximum : start;
          normalizedBase = '$start';
        }

        for (var value = start; value <= end; value += step) {
          values.add(definition.normalize(value));
        }
        normalizedSegments.add(
          stepParts.length == 2 ? '$normalizedBase/$step' : normalizedBase,
        );
      }

      if (values.isEmpty) {
        throw const FormatException();
      }
      return _CronField(
        values: Set<int>.unmodifiable(values),
        normalized: normalizedSegments.join(','),
        startsWithWildcard: source.startsWith('*'),
      );
    } on FormatException {
      throw const CronEvaluationException(
        kind: CronEvaluationFailureKind.validation,
        code: 'cron.invalid-field',
      );
    }
  }

  final Set<int> values;
  final String normalized;
  final bool startsWithWildcard;
}

enum _CronFieldDefinition {
  seconds(0, 59),
  minutes(0, 59),
  hours(0, 23),
  daysOfMonth(1, 31),
  months(1, 12),
  daysOfWeek(0, 7);

  const _CronFieldDefinition(this.minimum, this.maximum);

  final int minimum;
  final int maximum;

  static const Map<String, int> _monthNames = <String, int>{
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };
  static const Map<String, int> _weekdayNames = <String, int>{
    'SUN': 0,
    'MON': 1,
    'TUE': 2,
    'WED': 3,
    'THU': 4,
    'FRI': 5,
    'SAT': 6,
  };

  int parseValue(String source) {
    final upper = source.toUpperCase();
    final alias = switch (this) {
      _CronFieldDefinition.months => _monthNames[upper],
      _CronFieldDefinition.daysOfWeek => _weekdayNames[upper],
      _ => null,
    };
    final value = alias ?? int.parse(source);
    if (value < minimum || value > maximum) {
      throw const FormatException();
    }
    return value;
  }

  int normalize(int value) {
    if (this == _CronFieldDefinition.daysOfWeek && value == 7) {
      return 0;
    }
    return value;
  }
}
