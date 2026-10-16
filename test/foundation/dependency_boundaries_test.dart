import 'dart:io';

import 'package:test/test.dart';

import '../../tool/check_boundaries.dart';

void main() {
  test('GivenForbiddenInternalDependency_WhenChecked_ThenDirectionViolationIsReturned', () {
    final violations = checkDependencyMap(<String, Set<String>>{
      'chimera_core': <String>{'chimera_gui'},
    });

    expect(
      violations.map((violation) => violation.code),
      contains('forbidden-internal-dependency'),
    );
  });

  test('GivenDatabaseAndAnalyticsDependencies_WhenChecked_ThenPrivacyViolationsAreReturned', () {
    final violations = checkDependencyMap(<String, Set<String>>{
      'chimera_gui': <String>{'drift', 'firebase_analytics'},
    });

    expect(
      violations.map((violation) => violation.code),
      containsAll(<String>['database-dependency', 'analytics-dependency']),
    );
  });

  test(
    'GivenApprovedDependencyDirections_WhenChecked_ThenNoViolationsAreReturned',
    () {
      final violations = checkDependencyMap(<String, Set<String>>{
        'chimera_gui': <String>{
          'chimera_core',
          'chimera_l10n',
          'chimera_platform',
          'chimera_utilities',
        },
        'chimera_cli': <String>{
          'chimera_core',
          'chimera_l10n',
          'chimera_platform',
          'chimera_utilities',
        },
        'chimera_platform': <String>{'chimera_core'},
        'chimera_core': <String>{},
        'chimera_l10n': <String>{},
        'chimera_utilities': <String>{},
      });

      expect(violations, isEmpty);
    },
  );

  test('GivenRepositoryWorkspace_WhenChecked_ThenDependencyPolicyPasses', () {
    expect(checkWorkspaceBoundaries(Directory.current), isEmpty);
  });
}
