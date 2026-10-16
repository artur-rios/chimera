import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'GivenFeatureOrigins_WhenChecked_ThenOnlyDevelopAncestryIsAccepted',
    () async {
      final checker = File('tool/check_branch_origin.dart').absolute;
      expect(checker.existsSync(), isTrue);

      final repository = Directory.systemTemp.createTempSync(
        'chimera-branch-origin-',
      );
      addTearDown(() => repository.deleteSync(recursive: true));

      await _git(repository, <String>['init', '--initial-branch=main']);
      await _git(repository, <String>['config', 'user.name', 'Chimera Test']);
      await _git(repository, <String>[
        'config',
        'user.email',
        'chimera@example.test',
      ]);
      await _commit(repository, 'foundation.txt', 'main', 'main');

      await _git(repository, <String>['switch', '-c', 'develop']);
      await _commit(repository, 'develop.txt', 'develop', 'develop');
      await _git(repository, <String>['switch', '-c', 'feature-valid']);
      await _commit(repository, 'valid.txt', 'valid', 'valid');

      final valid = await Process.run(Platform.resolvedExecutable, <String>[
        'run',
        checker.path,
        'main',
        'develop',
        'feature-valid',
      ], workingDirectory: repository.path);
      expect(valid.exitCode, 0, reason: valid.stderr as String);

      await _git(repository, <String>['switch', 'main']);
      await _git(repository, <String>['switch', '-c', 'feature-invalid']);
      await _commit(repository, 'invalid.txt', 'invalid', 'invalid');

      final invalid = await Process.run(Platform.resolvedExecutable, <String>[
        'run',
        checker.path,
        'main',
        'develop',
        'feature-invalid',
      ], workingDirectory: repository.path);
      expect(invalid.exitCode, isNot(0));
      expect(invalid.stderr, contains('branched from main'));
    },
  );
}

Future<void> _commit(
  Directory repository,
  String path,
  String contents,
  String message,
) async {
  File('${repository.path}${Platform.pathSeparator}$path')
      .writeAsStringSync(contents);
  await _git(repository, <String>['add', path]);
  await _git(repository, <String>['commit', '-m', message]);
}

Future<void> _git(Directory repository, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: repository.path,
  );
  expect(result.exitCode, 0, reason: result.stderr as String);
}
