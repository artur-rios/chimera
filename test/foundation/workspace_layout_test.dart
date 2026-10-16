import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('GivenFoundationSpecification_WhenWorkspaceInspected_ThenRequiredProjectsAndSuitesExist', () {
    const requiredDirectories = <String>[
      'apps/chimera_gui',
      'apps/chimera_cli',
      'packages/chimera_core',
      'packages/chimera_utilities',
      'packages/chimera_platform',
      'packages/chimera_l10n',
      'tests/fixtures',
      'tests/web',
      'tests/deployment',
      'tests/update',
    ];

    for (final path in requiredDirectories) {
      expect(
        Directory(path).existsSync(),
        isTrue,
        reason: 'The required workspace directory $path is missing.',
      );
    }

    final workspaceManifest = File('pubspec.yaml');
    expect(workspaceManifest.existsSync(), isTrue);

    final melosSource = workspaceManifest.readAsStringSync();
    for (final script in <String>[
      'analyze',
      'test:unit',
      'test:cli',
      'test:gui',
      'test:web',
      'test:deployment',
      'test:all',
    ]) {
      expect(
        melosSource,
        contains('$script:'),
        reason: 'The required Melos script $script is missing.',
      );
    }

    expect(melosSource, contains('dart run tool/run_web_tests.dart'));
    expect(
      melosSource,
      contains(
        'dart test test && dart run melos exec --no-flutter '
        '--dir-exists=test -- "dart test"',
      ),
      reason: 'The aggregate unit suite must include repository-level tests.',
    );
    expect(File('tool/run_web_tests.dart').existsSync(), isTrue);
  });
}
