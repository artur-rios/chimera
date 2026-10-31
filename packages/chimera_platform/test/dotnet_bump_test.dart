import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_bump.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/native_path_alias.dart';

void main() {
  late Directory sandbox;
  late Directory source;
  late File project;
  const original =
      '<Project Sdk="Microsoft.NET.Sdk">\r\n  <!-- keep -->\r\n  <PropertyGroup><Version>1.2.3</Version></PropertyGroup>\r\n</Project>\r\n';
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('chimera-bump-');
    final createdSource = await Directory(p.join(sandbox.path, 'src')).create();
    source = Directory(await createdSource.resolveSymbolicLinks());
    project = await File(p.join(source.path, 'App.csproj'))
        .writeAsString(original);
  });
  tearDown(() async {
    await sandbox.delete(recursive: true);
  });
  DotnetBumpService service({
    DotnetBumpFileOperations operations = const DotnetBumpFileOperations(),
  }) => DotnetBumpService(
    NativeDotnetBumpGateway(
      workingDirectory: sandbox.path,
      operations: operations,
    ),
  );
  test('GivenSingleProject_WhenDefaultDiscovery_ThenVerifiedReplacementAndNoBackup', () async {
    final result = await service().execute(
      const DotnetBumpRequest(increment: 'patch'),
    ) as ChimeraSuccess<DotnetBumpOutput>;
    expect(result.value.project, project.path);
    expect(
      await project.readAsString(),
      original.replaceFirst('1.2.3', '1.2.4'),
    );
    expect(source.listSync().map((e) => p.basename(e.path)), ['App.csproj']);
  });
  test(
    'GivenExplicitDirectoryOrFile_WhenSelected_ThenSameNativeOperation',
    () async {
      for (final selection in [source.path, project.path]) {
        expect(
          await service().execute(
            DotnetBumpRequest(project: selection, version: '4.0.0'),
          ),
          isA<ChimeraSuccess<DotnetBumpOutput>>(),
        );
      }
    },
  );
  test(
    'GivenWindowsCaseAlias_WhenSelected_ThenCanonicalProjectIsUpdated',
    () async {
      final result = await service().execute(
        DotnetBumpRequest(
          project: project.path.toUpperCase(),
          version: '2.0.0',
        ),
      );
      expect(result, isA<ChimeraSuccess<DotnetBumpOutput>>());
      expect(
        await project.readAsString(),
        contains('<Version>2.0.0</Version>'),
      );
    },
    skip: !Platform.isWindows,
  );
  test('GivenInitialShortAliases_WhenDefaultDirectoryOrFileSelected_ThenCanonicalProjectIsUpdated', () async {
    final createdHome = await Directory(
      p.join(sandbox.path, 'runneradministrator'),
    ).create();
    final home = Directory(await createdHome.resolveSymbolicLinks());
    final directory = await Directory(p.join(home.path, 'src')).create();
    final file = await File(p.join(directory.path, 'App.csproj'))
        .writeAsString(original);
    final alias = p.join(sandbox.path, 'RUNNER~1');
    await IOOverrides.runWithIOOverrides(() async {
      for (final selection in <String?>[
        null,
        p.join(alias, 'src'),
        p.join(alias, 'src', 'App.csproj'),
      ]) {
        final gateway = NativeDotnetBumpGateway(workingDirectory: alias);
        final result = await DotnetBumpService(gateway).execute(
          DotnetBumpRequest(project: selection, version: '2.0.0'),
        ) as ChimeraSuccess<DotnetBumpOutput>;
        expect(result.value.project, file.path);
        expect(
          await file.readAsString(),
          original.replaceFirst('1.2.3', '2.0.0'),
        );
        expect(directory.listSync().map((entry) => p.basename(entry.path)), [
          'App.csproj',
        ]);
      }
    }, NativeDirectoryAliasOverrides(alias, home.path));
  });
  test('GivenFinalFilenameShortAlias_WhenSelected_ThenCanonicalProjectExtensionIsAccepted', () async {
    final createdHome = await Directory(
      p.join(sandbox.path, 'runneradministrator'),
    ).create();
    final home = Directory(await createdHome.resolveSymbolicLinks());
    final directory = await Directory(p.join(home.path, 'src')).create();
    final file = await File(
      p.join(directory.path, 'Application.Library.csproj'),
    ).writeAsString(original);
    final alias = p.join(sandbox.path, 'RUNNER~1');
    await IOOverrides.runWithIOOverrides(
      () async {
        final result =
            await DotnetBumpService(
                  NativeDotnetBumpGateway(workingDirectory: alias),
                ).execute(
                  DotnetBumpRequest(
                    project: p.join(alias, 'src', 'APPLIC~1.CSP'),
                    version: '2.0.0',
                  ),
                )
                as ChimeraSuccess<DotnetBumpOutput>;
        expect(result.value.project, file.path);
        expect(
          await file.readAsString(),
          original.replaceFirst('1.2.3', '2.0.0'),
        );
      },
      NativeDirectoryAliasOverrides(
        alias,
        home.path,
        fileAliases: {p.join(directory.path, 'APPLIC~1.CSP'): file.path},
      ),
    );
  });
  test('GivenAliasWithNonProjectCanonicalExtension_WhenSelected_ThenRejectedWithoutBackup', () async {
    final createdHome = await Directory(
      p.join(sandbox.path, 'runneradministrator'),
    ).create();
    final home = Directory(await createdHome.resolveSymbolicLinks());
    final directory = await Directory(p.join(home.path, 'src')).create();
    final file = await File(p.join(directory.path, 'Application.Library.txt'))
        .writeAsString(original);
    final alias = p.join(sandbox.path, 'RUNNER~1');
    await IOOverrides.runWithIOOverrides(
      () async {
        final result =
            await DotnetBumpService(
                  NativeDotnetBumpGateway(workingDirectory: alias),
                ).execute(
                  DotnetBumpRequest(
                    project: p.join(alias, 'src', 'APPLIC~1.CSP'),
                    version: '2.0.0',
                  ),
                )
                as ChimeraFailure<DotnetBumpOutput>;
        expect(result.code, 'dotnet-bump-discovery');
        expect(await file.readAsString(), original);
        expect(directory.listSync().length, 1);
      },
      NativeDirectoryAliasOverrides(
        alias,
        home.path,
        fileAliases: {p.join(directory.path, 'APPLIC~1.CSP'): file.path},
      ),
    );
  });
  test('GivenWindowsFinalFilenameShortAlias_WhenSelected_ThenCanonicalProjectIsUpdated', () async {
    final alias = await windowsShortFile(project);
    if (alias == null) {
      markTestSkipped('The Windows test volume does not expose 8.3 aliases.');
      return;
    }
    final result = await service().execute(
      DotnetBumpRequest(project: alias, version: '2.0.0'),
    ) as ChimeraSuccess<DotnetBumpOutput>;
    expect(result.value.project, project.path);
    expect(
      await project.readAsString(),
      original.replaceFirst('1.2.3', '2.0.0'),
    );
  }, skip: !Platform.isWindows);
  test('GivenDifferentObjectAliasAncestor_WhenSelected_ThenRejectBeforeResolvingChild', () async {
    final createdHome = await Directory(
      p.join(sandbox.path, 'runneradministrator'),
    ).create();
    final home = Directory(await createdHome.resolveSymbolicLinks());
    final directory = await Directory(p.join(home.path, 'src')).create();
    final file = await File(p.join(directory.path, 'App.csproj'))
        .writeAsString(original);
    final alias = p.join(sandbox.path, 'RUNNER~1');
    final overrides = NativeDirectoryAliasOverrides(
      alias,
      home.path,
      sameObject: false,
    );
    await IOOverrides.runWithIOOverrides(() async {
      final result = await DotnetBumpService(
        NativeDotnetBumpGateway(workingDirectory: alias),
      ).execute(const DotnetBumpRequest(version: '2.0.0'));
      expect(result, isA<ChimeraFailure<DotnetBumpOutput>>());
      expect(await file.readAsString(), original);
    }, overrides);
    expect(overrides.directoryRequests, isNot(contains(p.join(alias, 'src'))));
  });
  test('GivenWindowsTempShortAliases_WhenDefaultDirectoryOrFileSelected_ThenCanonicalProjectIsUpdated', () async {
    final alias = await windowsShortDirectory(sandbox);
    if (alias == null) {
      markTestSkipped('The Windows test volume does not expose 8.3 aliases.');
      return;
    }
    for (final selection in <String?>[
      null,
      p.join(alias, 'src'),
      p.join(alias, 'src', 'App.csproj'),
    ]) {
      final cleaner = DotnetBumpService(
        NativeDotnetBumpGateway(workingDirectory: alias),
      );
      final result = await cleaner.execute(
        DotnetBumpRequest(project: selection, version: '2.0.0'),
      ) as ChimeraSuccess<DotnetBumpOutput>;
      expect(result.value.project, await project.resolveSymbolicLinks());
    }
  }, skip: !Platform.isWindows);
  test('GivenLinkedSelectedDirectoryOrAncestor_WhenBumped_ThenNoProjectOrBackupChanges', () async {
    final outside = await Directory(p.join(sandbox.path, 'outside', 'src'))
        .create(recursive: true);
    final file = await File(p.join(outside.path, 'Outside.csproj'))
        .writeAsString(original);
    final linked = p.join(sandbox.path, 'linked-parent');
    await createDirectoryLink(linked, p.dirname(outside.path));
    for (final selected in [
      linked,
      p.join(linked, 'src'),
      p.join(linked, 'src', 'Outside.csproj'),
    ]) {
      expect(
        await service().execute(
          DotnetBumpRequest(project: selected, version: '2.0.0'),
        ),
        isA<ChimeraFailure<DotnetBumpOutput>>(),
      );
      expect(await file.readAsString(), original);
      expect(outside.listSync().length, 1);
    }
  });
  test('GivenZeroOrMultipleProjects_WhenDiscovered_ThenCandidatesReportedAndNoMutation', () async {
    final other = await File(p.join(source.path, 'Other.csproj'))
        .writeAsString('<Project/>');
    var failure = await service().execute(
      const DotnetBumpRequest(version: '2.0.0'),
    ) as ChimeraFailure<DotnetBumpOutput>;
    expect(failure.code, 'dotnet-bump-discovery');
    expect(failure.details['candidates'], [project.path, other.path]);
    expect(await project.readAsString(), original);
    await project.delete();
    await other.delete();
    await Directory(p.join(source.path, 'nested')).create();
    await File(p.join(source.path, 'nested', 'Nested.csproj'))
        .writeAsString('<Project/>');
    failure = await service().execute(
      const DotnetBumpRequest(version: '2.0.0'),
    ) as ChimeraFailure<DotnetBumpOutput>;
    expect(failure.details['candidates'], isEmpty);
  });
  test('GivenInvalidXmlOrIncrementWithoutVersion_WhenRun_ThenNoBackupOrModification', () async {
    for (final xml in ['<Project>', '<Project/>']) {
      await project.writeAsString(xml);
      expect(
        await service().execute(const DotnetBumpRequest(increment: 'patch')),
        isA<ChimeraFailure<DotnetBumpOutput>>(),
      );
      expect(await project.readAsString(), xml);
      expect(source.listSync().length, 1);
    }
  });
  test(
    'GivenStageWriteFailure_WhenRun_ThenOriginalAndBackupRetained',
    () async {
      final result =
          await service(
                operations: DotnetBumpFileOperations(
                  writeStage: (path, bytes) async {
                    throw const FileSystemException('denied');
                  },
                ),
              ).execute(const DotnetBumpRequest(increment: 'patch'))
              as ChimeraFailure<DotnetBumpOutput>;
      expect(result.code, 'dotnet-bump-transaction-failed');
      expect(result.details['restored'], isTrue);
      expect(await project.readAsString(), original);
      expect(
        await File(result.details['backupPath']! as String).readAsString(),
        original,
      );
    },
  );
  test(
    'GivenCorruptReplacement_WhenVerified_ThenUnknownContentAndBackupRetained',
    () async {
      final result =
          await service(
                operations: DotnetBumpFileOperations(
                  renameStage: (stage, target) async {
                    await File(stage).rename(target);
                    await File(target).writeAsString('<Project/>');
                  },
                ),
              ).execute(const DotnetBumpRequest(increment: 'minor'))
              as ChimeraFailure<DotnetBumpOutput>;
      expect(result.details['restored'], isFalse);
      expect(await project.readAsString(), '<Project/>');
      expect(
        await File(result.details['backupPath']! as String).readAsString(),
        original,
      );
    },
  );
  test('GivenOwnedReplacementAndRollbackDenied_WhenRestoreRequested_ThenRecoverableBackupRemains', () async {
    final gateway = NativeDotnetBumpGateway(
      workingDirectory: sandbox.path,
      operations: DotnetBumpFileOperations(
        restoreBackup: (target, backup) async {
          throw const FileSystemException('locked');
        },
      ),
    );
    final originalBytes = await project.readAsBytes();
    final expected = utf8.encode(original.replaceFirst('1.2.3', '1.2.4'));
    final backup = await gateway.createBackup(project.path, originalBytes);
    await gateway.replace(project.path, originalBytes, expected);
    await expectLater(
      gateway.restore(
        project.path,
        backup,
        originalBytes,
        expectedCurrent: expected,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await project.readAsBytes(), expected);
    expect(await File(backup).readAsBytes(), originalBytes);
  });
  test(
    'GivenOwnedReplacement_WhenRestored_ThenOriginalRecoveredAndBackupRemains',
    () async {
      final gateway = NativeDotnetBumpGateway(workingDirectory: sandbox.path);
      final originalBytes = await project.readAsBytes();
      final expected = utf8.encode(original.replaceFirst('1.2.3', '1.2.4'));
      final backup = await gateway.createBackup(project.path, originalBytes);
      await gateway.replace(project.path, originalBytes, expected);
      await gateway.restore(
        project.path,
        backup,
        originalBytes,
        expectedCurrent: expected,
      );
      expect(await project.readAsBytes(), originalBytes);
      expect(await File(backup).readAsBytes(), originalBytes);
    },
  );
  test('GivenNewerSource_WhenRestoreRequested_ThenExpectedByteGuardPreservesSaveAndBackup', () async {
    final gateway = NativeDotnetBumpGateway(workingDirectory: sandbox.path);
    final originalBytes = await project.readAsBytes();
    final expected = utf8.encode(original.replaceFirst('1.2.3', '1.2.4'));
    final backup = await gateway.createBackup(project.path, originalBytes);
    await gateway.replace(project.path, originalBytes, expected);
    const newer =
        '<Project><PropertyGroup><Version>5.0.0</Version><Description>user save</Description></PropertyGroup></Project>';
    await project.writeAsString(newer);
    await expectLater(
      gateway.restore(
        project.path,
        backup,
        originalBytes,
        expectedCurrent: expected,
      ),
      throwsA(isA<DotnetBumpBoundaryException>()),
    );
    expect(await project.readAsString(), newer);
    expect(await File(backup).readAsBytes(), originalBytes);
  });
  test('GivenLinkedProject_WhenSelected_ThenNoWriteOutsideScope', () async {
    final link = p.join(source.path, 'Link.csproj');
    try {
      await Link(link).create(project.path);
    } on FileSystemException catch (error) {
      if (Platform.isWindows && error.osError?.errorCode == 1314) {
        markTestSkipped('Windows file symlink privilege is unavailable.');
        return;
      }
      rethrow;
    }
    final result = await service().execute(
      DotnetBumpRequest(project: link, version: '2.0.0'),
    );
    expect(result, isA<ChimeraFailure<DotnetBumpOutput>>());
    expect(await project.readAsString(), original);
  });
  test('GivenCanonicalProjectParentSwappedForLink_WhenReadOrBackupRequested_ThenRejected', () async {
    final gateway = NativeDotnetBumpGateway(workingDirectory: sandbox.path);
    final resolved = await gateway.resolveProject(project.path);
    final outside = await Directory(p.join(sandbox.path, 'outside')).create();
    final outsideFile = await File(p.join(outside.path, 'App.csproj'))
        .writeAsString(original);
    final moved = p.join(sandbox.path, 'original-source');
    await source.rename(moved);
    await createDirectoryLink(source.path, outside.path);
    await expectLater(
      gateway.read(resolved),
      throwsA(isA<DotnetBumpBoundaryException>()),
    );
    await expectLater(
      gateway.createBackup(resolved, utf8.encode(original)),
      throwsA(isA<DotnetBumpBoundaryException>()),
    );
    expect(await outsideFile.readAsString(), original);
    expect(outside.listSync().length, 1);
  });
  test('GivenConcurrentSaveAndStagingFailure_WhenBumpFails_ThenNewerSourceAndOriginalBackupRemain', () async {
    const newer =
        '<Project><PropertyGroup><Version>5.0.0</Version><Description>user save</Description></PropertyGroup></Project>';
    final result =
        await service(
              operations: DotnetBumpFileOperations(
                writeStage: (path, bytes) async {
                  await project.writeAsString(newer);
                  throw const FileSystemException('staging write failed');
                },
              ),
            ).execute(const DotnetBumpRequest(increment: 'patch'))
            as ChimeraFailure<DotnetBumpOutput>;
    expect(await project.readAsString(), newer);
    expect(result.details['restored'], isFalse);
    expect(
      await File(result.details['backupPath']! as String).readAsString(),
      original,
    );
  });
  test('GivenConcurrentSaveAfterReplacement_WhenVerificationFails_ThenNewerSourceAndOriginalBackupRemain', () async {
    const newer =
        '<Project><PropertyGroup><Version>5.0.0</Version><Description>user save</Description></PropertyGroup></Project>';
    final result =
        await service(
              operations: DotnetBumpFileOperations(
                renameStage: (stage, target) async {
                  await File(stage).rename(target);
                  await project.writeAsString(newer);
                },
              ),
            ).execute(const DotnetBumpRequest(increment: 'patch'))
            as ChimeraFailure<DotnetBumpOutput>;
    expect(await project.readAsString(), newer);
    expect(result.details['restored'], isFalse);
    expect(
      await File(result.details['backupPath']! as String).readAsString(),
      original,
    );
  });
  test('GivenSourceChangedAfterRead_WhenStageReady_ThenRefuseOverwritingNewContent', () async {
    final result =
        await service(
              operations: DotnetBumpFileOperations(
                writeStage: (path, bytes) async {
                  await File(path).writeAsBytes(bytes, flush: true);
                  await project.writeAsString(
                    original.replaceFirst('1.2.3', '5.0.0'),
                  );
                },
              ),
            ).execute(const DotnetBumpRequest(increment: 'patch'))
            as ChimeraFailure<DotnetBumpOutput>;
    expect(result.code, 'dotnet-bump-transaction-failed');
    expect(
      await project.readAsString(),
      original.replaceFirst('1.2.3', '5.0.0'),
    );
    expect(
      await File(result.details['backupPath']! as String).readAsBytes(),
      utf8.encode(original),
    );
  });
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
