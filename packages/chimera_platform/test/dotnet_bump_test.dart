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
    'GivenCorruptReplacement_WhenVerified_ThenRollbackAndBackupPath',
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
      expect(result.details['restored'], isTrue);
      expect(await project.readAsString(), original);
      expect(
        await File(result.details['backupPath']! as String).readAsString(),
        original,
      );
    },
  );
  test(
    'GivenRollbackDenied_WhenVerificationFails_ThenRecoverableBackupRemains',
    () async {
      final result =
          await service(
                operations: DotnetBumpFileOperations(
                  renameStage: (stage, target) async {
                    await File(stage).rename(target);
                    await File(target).writeAsString('<Project/>');
                  },
                  restoreBackup: (target, backup) async {
                    throw const FileSystemException('locked');
                  },
                ),
              ).execute(const DotnetBumpRequest(increment: 'major'))
              as ChimeraFailure<DotnetBumpOutput>;
      expect(result.details['restored'], isFalse);
      expect(
        await File(result.details['backupPath']! as String).readAsString(),
        original,
      );
    },
  );
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
