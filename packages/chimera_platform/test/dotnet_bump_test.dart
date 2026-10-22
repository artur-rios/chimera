import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_bump.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late Directory source;
  late File project;
  const original =
      '<Project Sdk="Microsoft.NET.Sdk">\r\n  <!-- keep -->\r\n  <PropertyGroup><Version>1.2.3</Version></PropertyGroup>\r\n</Project>\r\n';
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('chimera-bump-');
    source = await Directory(p.join(sandbox.path, 'src')).create();
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
    if (Platform.isWindows) return; // Real Windows junction coverage belongs to cleanup; file links require privileges.
    await Link(link).create(project.path);
    final result = await service().execute(
      DotnetBumpRequest(project: link, version: '2.0.0'),
    );
    expect(result, isA<ChimeraFailure<DotnetBumpOutput>>());
    expect(await project.readAsString(), original);
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
