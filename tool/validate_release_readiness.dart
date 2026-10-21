import 'dart:io';

final class ReleaseReadinessIssue {
  const ReleaseReadinessIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;

  @override
  String toString() => '$code: $path: $message';
}

List<ReleaseReadinessIssue> validateReleaseReadiness({
  required Directory repository,
  required String version,
}) {
  final issues = <ReleaseReadinessIssue>[];
  if (!_canonicalVersion.hasMatch(version)) {
    issues.add(
      ReleaseReadinessIssue(
        code: 'invalid-version',
        path: 'version',
        message: "'$version' must be canonical X.Y.Z",
      ),
    );
    return issues;
  }

  _validateManifestVersion(
    repository: repository,
    relativePath: 'pubspec.yaml',
    version: version,
    allowBuildSuffix: false,
    issues: issues,
  );
  _validateManifestVersion(
    repository: repository,
    relativePath: 'apps/chimera_cli/pubspec.yaml',
    version: version,
    allowBuildSuffix: false,
    issues: issues,
  );
  _validateManifestVersion(
    repository: repository,
    relativePath: 'apps/chimera_gui/pubspec.yaml',
    version: version,
    allowBuildSuffix: true,
    issues: issues,
  );
  _validateChangelog(repository, version, issues);
  return List<ReleaseReadinessIssue>.unmodifiable(issues);
}

final RegExp _canonicalVersion = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
);

void _validateManifestVersion({
  required Directory repository,
  required String relativePath,
  required String version,
  required bool allowBuildSuffix,
  required List<ReleaseReadinessIssue> issues,
}) {
  final contents = _read(repository, relativePath, issues);
  if (contents == null) {
    return;
  }
  final matches = RegExp(
    r'^version:\s*([^\s#]+)\s*(?:#.*)?$',
    multiLine: true,
  ).allMatches(contents).toList(growable: false);
  if (matches.length != 1) {
    issues.add(
      ReleaseReadinessIssue(
        code: 'manifest-version-count',
        path: relativePath,
        message: 'expected exactly one top-level version field',
      ),
    );
    return;
  }

  final actual = matches.single.group(1)!;
  final expected = allowBuildSuffix
      ? RegExp('^${RegExp.escape(version)}(?:\\+[1-9]\\d*)?\$')
      : RegExp('^${RegExp.escape(version)}\$');
  if (!expected.hasMatch(actual)) {
    issues.add(
      ReleaseReadinessIssue(
        code: 'manifest-version-mismatch',
        path: relativePath,
        message: "version '$actual' does not identify release $version",
      ),
    );
  }
}

void _validateChangelog(
  Directory repository,
  String version,
  List<ReleaseReadinessIssue> issues,
) {
  const relativePath = 'CHANGELOG.md';
  final contents = _read(repository, relativePath, issues);
  if (contents == null) {
    return;
  }
  final matches = RegExp(
    '^## \\[${RegExp.escape(version)}\\] - (\\d{4}-\\d{2}-\\d{2})\\s*\$',
    multiLine: true,
  ).allMatches(contents).toList(growable: false);
  if (matches.isEmpty) {
    issues.add(
      const ReleaseReadinessIssue(
        code: 'missing-changelog-release',
        path: relativePath,
        message: 'missing a dated release heading',
      ),
    );
    return;
  }
  if (matches.length > 1) {
    issues.add(
      const ReleaseReadinessIssue(
        code: 'duplicate-changelog-release',
        path: relativePath,
        message: 'release heading must appear exactly once',
      ),
    );
    return;
  }

  final date = matches.single.group(1)!;
  if (!_isCalendarDate(date)) {
    issues.add(
      ReleaseReadinessIssue(
        code: 'invalid-changelog-date',
        path: relativePath,
        message: "'$date' is not a calendar date",
      ),
    );
  }
}

String? _read(
  Directory repository,
  String relativePath,
  List<ReleaseReadinessIssue> issues,
) {
  final file = File(
    '${repository.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    issues.add(
      ReleaseReadinessIssue(
        code: 'missing-release-source',
        path: relativePath,
        message: 'required release source is not readable',
      ),
    );
    return null;
  }
}

bool _isCalendarDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year == 0) {
    return false;
  }
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

void main(List<String> arguments) {
  final version = _valueAfter(arguments, '--version');
  final repositoryPath = _valueAfter(arguments, '--repository') ?? '.';
  if (version == null || _hasUnknownArguments(arguments)) {
    stderr.writeln(
      'Usage: dart tool/validate_release_readiness.dart '
      '--version <X.Y.Z> [--repository <path>]',
    );
    exitCode = 64;
    return;
  }

  final issues = validateReleaseReadiness(
    repository: Directory(repositoryPath),
    version: version,
  );
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln(issue);
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Release $version source readiness: OK');
}

String? _valueAfter(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  if (index < 0 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}

bool _hasUnknownArguments(List<String> arguments) {
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length ||
        (arguments[index] != '--version' &&
            arguments[index] != '--repository')) {
      return true;
    }
  }
  return false;
}
