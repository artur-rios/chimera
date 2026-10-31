import 'dart:io';

import 'package:test/test.dart';

import '../../tool/validate_release_readiness.dart';

void main() {
  late Directory repository;

  setUp(() {
    repository = Directory.systemTemp.createTempSync(
      'chimera-release-readiness-',
    );
    _write(
      repository,
      'pubspec.yaml',
      'name: chimera_workspace\nversion: 1.2.3\n',
    );
    _write(
      repository,
      'apps/chimera_cli/pubspec.yaml',
      'name: chimera_cli\nversion: 1.2.3\n',
    );
    _write(
      repository,
      'apps/chimera_gui/pubspec.yaml',
      'name: chimera_gui\nversion: 1.2.3+7\n',
    );
    _write(
      repository,
      'CHANGELOG.md',
      '# Changelog\n\n## [Unreleased]\n\n## [1.2.3] - 2026-10-21\n',
    );
  });

  tearDown(() {
    repository.deleteSync(recursive: true);
  });

  test(
    'GivenPreparedRelease_WhenReadinessIsValidated_ThenNoIssuesAreReported',
    () {
      expect(
        validateReleaseReadiness(repository: repository, version: '1.2.3'),
        isEmpty,
      );
    },
  );

  test(
    'GivenNonCanonicalVersion_WhenReadinessIsValidated_ThenVersionIsRejected',
    () {
      final issues = validateReleaseReadiness(
        repository: repository,
        version: '01.2.3',
      );

      expect(issues.map((issue) => issue.code), contains('invalid-version'));
    },
  );

  test(
    'GivenManifestDrift_WhenReadinessIsValidated_ThenEveryMismatchIsReported',
    () {
      _write(
        repository,
        'pubspec.yaml',
        'name: chimera_workspace\nversion: 1.2.2\n',
      );
      _write(
        repository,
        'apps/chimera_cli/pubspec.yaml',
        'name: chimera_cli\nversion: 1.2.4\n',
      );
      _write(
        repository,
        'apps/chimera_gui/pubspec.yaml',
        'name: chimera_gui\nversion: 1.2.3+0\n',
      );

      final issues = validateReleaseReadiness(
        repository: repository,
        version: '1.2.3',
      );

      expect(
        issues.map((issue) => issue.path),
        containsAll(<String>[
          'pubspec.yaml',
          'apps/chimera_cli/pubspec.yaml',
          'apps/chimera_gui/pubspec.yaml',
        ]),
      );
    },
  );

  test('GivenMissingOrDuplicateReleaseNotes_WhenReadinessIsValidated_ThenChangelogIsRejected', () {
    _write(
      repository,
      'CHANGELOG.md',
      '# Changelog\n\n'
          '## [1.2.3] - 2026-10-21\n\n'
          '## [1.2.3] - 2026-10-22\n',
    );

    final duplicate = validateReleaseReadiness(
      repository: repository,
      version: '1.2.3',
    );
    final missing = validateReleaseReadiness(
      repository: repository,
      version: '1.2.4',
    );

    expect(
      duplicate.map((issue) => issue.code),
      contains('duplicate-changelog-release'),
    );
    expect(
      missing.map((issue) => issue.code),
      contains('missing-changelog-release'),
    );
  });

  test(
    'GivenInvalidReleaseDate_WhenReadinessIsValidated_ThenChangelogIsRejected',
    () {
      _write(
        repository,
        'CHANGELOG.md',
        '# Changelog\n\n## [1.2.3] - 2026-02-31\n',
      );

      final issues = validateReleaseReadiness(
        repository: repository,
        version: '1.2.3',
      );

      expect(
        issues.map((issue) => issue.code),
        contains('invalid-changelog-date'),
      );
    },
  );
}

void _write(Directory root, String relativePath, String contents) {
  final file = File('${root.path}${Platform.pathSeparator}$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}
