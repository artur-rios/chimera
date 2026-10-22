import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_commands.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/windows_short_path.dart';

void main() {
  late Directory sandbox;
  late Directory source;
  late File solution;
  const discovery = NativeProjectDiscovery();
  setUp(() async {
    final created = await Directory.systemTemp.createTemp(
      'chimera-solution-alias-',
    );
    sandbox = Directory(await created.resolveSymbolicLinks());
    source = await Directory(p.join(sandbox.path, 'Runner Home')).create();
    solution = await File(p.join(source.path, 'Nested', 'Example.sln'))
        .create(recursive: true);
  });
  tearDown(() async => sandbox.delete(recursive: true));

  test(
    'GivenSameObjectAbsoluteAlias_WhenSolutionSelected_ThenReturnCanonicalFile',
    () async {
      final alias = p.join(sandbox.path, 'RUNNER~1');
      await IOOverrides.runWithIOOverrides(() async {
        for (final root in [source.path, alias]) {
          final result = await discovery.find(
            root,
            extension: '.sln',
            selection: p.join(alias, 'Nested', 'Example.sln'),
          );
          expect(result, isA<ChimeraSuccess<String>>());
          expect((result as ChimeraSuccess<String>).value, solution.path);
        }
      }, _PathAliasOverrides(alias, source.path));
    },
  );

  test(
    'GivenWindowsShortAbsolutePath_WhenSolutionSelected_ThenCanonicalFile',
    () async {
      final alias = p.normalize(windowsShortPath(solution.path));
      if (p.equals(alias, solution.path)) {
        markTestSkipped('The Windows test volume does not expose 8.3 aliases.');
        return;
      }
      expect(await FileSystemEntity.identical(alias, solution.path), isTrue);
      final result = await discovery.find(
        source.path,
        extension: '.sln',
        selection: alias,
      );
      expect(result, isA<ChimeraSuccess<String>>());
      expect((result as ChimeraSuccess<String>).value, solution.path);
    },
    skip: !Platform.isWindows,
  );

  test('GivenDifferentObjectAliasAncestor_WhenSelected_ThenRejectBeforeChildResolution', () async {
    final alias = p.join(sandbox.path, 'RUNNER~1');
    final overrides = _PathAliasOverrides(
      alias,
      source.path,
      sameObject: false,
    );
    await IOOverrides.runWithIOOverrides(() async {
      final result = await discovery.find(
        source.path,
        extension: '.sln',
        selection: p.join(alias, 'Nested', 'Example.sln'),
      );
      expect(result, isA<ChimeraFailure<String>>());
      expect((result as ChimeraFailure<String>).code, 'dotnet.invalidPath');
    }, overrides);
    expect(
      overrides.directoryRequests,
      isNot(contains(p.join(alias, 'Nested'))),
    );
  });

  test(
    'GivenOutsideAbsoluteAliasOrTraversal_WhenSelected_ThenReject',
    () async {
      final outside = await Directory(p.join(sandbox.path, 'outside')).create();
      await File(p.join(outside.path, 'Outside.sln')).writeAsString('');
      final alias = p.join(sandbox.path, 'OUTSID~1');
      await IOOverrides.runWithIOOverrides(() async {
        for (final selection in [
          p.join(alias, 'Outside.sln'),
          p.join('..', 'outside', 'Outside.sln'),
        ]) {
          final result = await discovery.find(
            source.path,
            extension: '.sln',
            selection: selection,
          );
          expect(result, isA<ChimeraFailure<String>>());
          expect((result as ChimeraFailure<String>).code, 'dotnet.invalidPath');
        }
      }, _PathAliasOverrides(alias, outside.path));
    },
  );

  test('GivenMissingSelectedFile_WhenDiscover_ThenNoSolution', () async {
    final result = await discovery.find(
      source.path,
      extension: '.sln',
      selection: 'Missing.sln',
    );
    expect((result as ChimeraFailure<String>).code, 'dotnet.noSolution');
  });

  test(
    'GivenLinkedSelectionAncestor_WhenTargetIsInsideRoot_ThenReject',
    () async {
      final linked = p.join(source.path, 'linked');
      await _directoryLink(linked, solution.parent.path);
      final result = await discovery.find(
        source.path,
        extension: '.sln',
        selection: p.join(linked, 'Example.sln'),
      );
      expect(result, isA<ChimeraFailure<String>>());
      expect((result as ChimeraFailure<String>).code, 'dotnet.invalidPath');
    },
  );

  test(
    'GivenLinkedSelectionRootAncestor_WhenTargetIsInsideRoot_ThenReject',
    () async {
      final linked = p.join(sandbox.path, 'linked-root');
      await _directoryLink(linked, source.path);
      final result = await discovery.find(
        source.path,
        extension: '.sln',
        selection: p.join(linked, 'Nested', 'Example.sln'),
      );
      expect(result, isA<ChimeraFailure<String>>());
      expect((result as ChimeraFailure<String>).code, 'dotnet.invalidPath');
    },
  );

  test('GivenSelectedFileLink_WhenTargetIsInsideRoot_ThenReject', () async {
    final link = p.join(source.path, 'Linked.sln');
    try {
      await Link(link).create(solution.path);
    } on FileSystemException catch (error) {
      if (Platform.isWindows && error.osError?.errorCode == 1314) {
        markTestSkipped('Windows file symlink privilege is unavailable.');
        return;
      }
      rethrow;
    }
    final result = await discovery.find(
      source.path,
      extension: '.sln',
      selection: link,
    );
    expect(result, isA<ChimeraFailure<String>>());
    expect((result as ChimeraFailure<String>).code, 'dotnet.invalidPath');
  });
}

Future<void> _directoryLink(String path, String target) async {
  if (Platform.isWindows) {
    final result = await Process.run('cmd.exe', [
      '/d',
      '/c',
      'mklink',
      '/J',
      path,
      target,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not create test junction', path);
    }
  } else {
    await Link(path).create(target);
  }
}

/// Models an OS short spelling of the same real objects without creating links.
final class _PathAliasOverrides extends IOOverrides {
  _PathAliasOverrides(this.alias, this.canonical, {this.sameObject = true});
  final String alias;
  final String canonical;
  final bool sameObject;
  final List<String> directoryRequests = [];
  bool _isAlias(String path) => path == alias || p.isWithin(alias, path);
  String _map(String path) =>
      _isAlias(path) ? p.join(canonical, p.relative(path, from: alias)) : path;
  @override
  Directory createDirectory(String path) {
    directoryRequests.add(path);
    return super.createDirectory(_map(path));
  }

  @override
  File createFile(String path) => super.createFile(_map(path));
  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) =>
      super.fseGetType(_map(path), followLinks);
  @override
  Future<bool> fseIdentical(String first, String second) =>
      !sameObject && (_isAlias(first) || _isAlias(second))
      ? Future.value(false)
      : super.fseIdentical(_map(first), _map(second));
}
