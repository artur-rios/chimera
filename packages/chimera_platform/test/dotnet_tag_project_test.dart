import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_tag.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/native_path_alias.dart';

void main() {
  late Directory sandbox;
  late Directory home;
  late File project;
  const original =
      '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>';
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('chimera-tag-project-');
    final createdHome = await Directory(
      p.join(sandbox.path, 'runneradministrator'),
    ).create();
    home = Directory(await createdHome.resolveSymbolicLinks());
    final directory = await Directory(p.join(home.path, 'src', 'Library'))
        .create(recursive: true);
    project = await File(p.join(directory.path, 'App.csproj'))
        .writeAsString(original);
  });
  tearDown(() async {
    await sandbox.delete(recursive: true);
  });

  test('GivenInitialShortAliases_WhenDefaultDirectoryOrFileSelected_ThenCanonicalProjectIsRead', () async {
    final alias = p.join(sandbox.path, 'RUNNER~1');
    await IOOverrides.runWithIOOverrides(() async {
      final gateway = NativeDotnetTagProjectGateway(workingDirectory: alias);
      for (final selection in <String?>[
        null,
        p.join(alias, 'src'),
        p.join(alias, 'src', 'Library', 'App.csproj'),
      ]) {
        final value = await gateway.resolve(selection);
        expect(value.path, project.path);
        expect(value.directory, project.parent.path);
        expect(value.bytes, utf8.encode(original));
      }
    }, NativeDirectoryAliasOverrides(alias, home.path));
    expect(await project.readAsString(), original);
  });
  test(
    'GivenFinalFilenameShortAlias_WhenSelected_ThenCanonicalProjectIsRead',
    () async {
      final file = await File(
        p.join(project.parent.path, 'Application.Library.csproj'),
      ).writeAsString(original);
      final alias = p.join(sandbox.path, 'RUNNER~1');
      await IOOverrides.runWithIOOverrides(
        () async {
          final gateway = NativeDotnetTagProjectGateway(
            workingDirectory: alias,
          );
          final value = await gateway.resolve(
            p.join(alias, 'src', 'Library', 'APPLIC~1.CSP'),
          );
          expect(value.path, file.path);
          expect(value.bytes, utf8.encode(original));
        },
        NativeDirectoryAliasOverrides(
          alias,
          home.path,
          fileAliases: {p.join(file.parent.path, 'APPLIC~1.CSP'): file.path},
        ),
      );
    },
  );
  test(
    'GivenFileLink_WhenSelected_ThenRejectedWithoutReadingOutsideProject',
    () async {
      final linked = p.join(sandbox.path, 'Linked.csproj');
      try {
        await Link(linked).create(project.path);
      } on FileSystemException catch (error) {
        if (Platform.isWindows && error.osError?.errorCode == 1314) {
          markTestSkipped('Windows file symlink privilege is unavailable.');
          return;
        }
        rethrow;
      }
      await expectLater(
        NativeDotnetTagProjectGateway(workingDirectory: home.path)
            .resolve(linked),
        throwsA(isA<DotnetBumpBoundaryException>()),
      );
      expect(await project.readAsString(), original);
    },
  );
  test('GivenWindowsFinalFilenameShortAlias_WhenSelected_ThenCanonicalProjectIsRead', () async {
    final alias = await windowsShortFile(project);
    if (alias == null) {
      markTestSkipped('The Windows test volume does not expose 8.3 aliases.');
      return;
    }
    final value = await NativeDotnetTagProjectGateway(
      workingDirectory: home.path,
    ).resolve(alias);
    expect(value.path, project.path);
    expect(value.directory, project.parent.path);
  }, skip: !Platform.isWindows);
  test('GivenDifferentObjectAliasAncestor_WhenSelected_ThenRejectedBeforeChildResolution', () async {
    final alias = p.join(sandbox.path, 'RUNNER~1');
    final overrides = NativeDirectoryAliasOverrides(
      alias,
      home.path,
      sameObject: false,
    );
    await IOOverrides.runWithIOOverrides(() async {
      final gateway = NativeDotnetTagProjectGateway(workingDirectory: alias);
      await expectLater(
        gateway.resolve(null),
        throwsA(isA<DotnetBumpBoundaryException>()),
      );
    }, overrides);
    expect(overrides.directoryRequests, isNot(contains(p.join(alias, 'src'))));
    expect(await project.readAsString(), original);
  });
  test(
    'GivenLinkedRootOrAncestor_WhenSelected_ThenNoOutsideProjectIsRead',
    () async {
      final linked = p.join(sandbox.path, 'linked-parent');
      await createDirectoryLink(linked, home.path);
      final gateway = NativeDotnetTagProjectGateway(workingDirectory: linked);
      for (final selection in <String?>[
        null,
        linked,
        p.join(linked, 'src'),
        p.join(linked, 'src', 'Library', 'App.csproj'),
      ]) {
        await expectLater(
          gateway.resolve(selection),
          throwsA(isA<DotnetBumpBoundaryException>()),
        );
      }
      expect(await project.readAsString(), original);
    },
  );
  test(
    'GivenEscapingLinkedChild_WhenRecursivelyDiscovered_ThenNeverFollowed',
    () async {
      final outside = await Directory(p.join(sandbox.path, 'outside')).create();
      final other = await File(p.join(outside.path, 'Outside.csproj'))
          .writeAsString(original);
      await createDirectoryLink(
        p.join(home.path, 'src', 'linked-child'),
        outside.path,
      );
      final value = await NativeDotnetTagProjectGateway(
        workingDirectory: home.path,
      ).resolve(null);
      expect(value.path, project.path);
      expect(await other.readAsString(), original);
    },
  );
  test('GivenWindowsTempShortAliases_WhenDefaultDirectoryOrFileSelected_ThenCanonicalProjectIsRead', () async {
    final alias = await windowsShortDirectory(home);
    if (alias == null) {
      markTestSkipped('The Windows test volume does not expose 8.3 aliases.');
      return;
    }
    final gateway = NativeDotnetTagProjectGateway(workingDirectory: alias);
    for (final selection in <String?>[
      null,
      p.join(alias, 'src'),
      p.join(alias, 'src', 'Library', 'App.csproj'),
    ]) {
      final value = await gateway.resolve(selection);
      expect(value.path, project.path);
      expect(value.directory, project.parent.path);
    }
  }, skip: !Platform.isWindows);
}

Future<void> createDirectoryLink(String path, String target) async {
  if (Platform.isWindows) {
    final result = await Process.run('cmd', [
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
