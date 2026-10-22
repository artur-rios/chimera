import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

final class _Gateway implements DotnetBumpGateway {
  List<int> content = utf8.encode(
    '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>',
  );
  List<int>? backup;
  bool failVerification = false;
  bool failRestore = false;
  bool failWrite = false;
  bool failCleanup = false;
  int backups = 0;
  bool written = false;
  @override
  Future<String> resolveProject(String? selection) async => '/src/App.csproj';
  @override
  Future<List<int>> read(String path) async =>
      failVerification && written ? utf8.encode('<Project/>') : content;
  @override
  Future<String> createBackup(String path, List<int> original) async {
    backups++;
    backup = [...original];
    return '$path.bak';
  }

  @override
  Future<void> replace(
    String path,
    List<int> expectedOriginal,
    List<int> updated,
  ) async {
    if (failWrite) throw StateError('write failed');
    content = [...updated];
    written = true;
  }

  @override
  Future<void> restore(
    String path,
    String backupPath,
    List<int> original,
  ) async {
    if (failRestore) throw StateError('restore failed');
    content = [...backup!];
    written = false;
  }

  @override
  Future<void> removeBackup(String path) async {
    if (failCleanup) throw StateError('cleanup failed');
    backup = null;
  }
}

void main() {
  late _Gateway gateway;
  late DotnetBumpService service;
  setUp(() {
    gateway = _Gateway();
    service = DotnetBumpService(gateway);
  });
  test(
    'GivenValidIncrement_WhenExecuted_ThenVerifiedAndBackupRemoved',
    () async {
      final output = (await service.execute(
        const DotnetBumpRequest(increment: 'minor'),
      ) as ChimeraSuccess<DotnetBumpOutput>).value;
      expect(output.previousVersion, '1.2.3');
      expect(output.version, '1.3.0');
      expect(gateway.backups, 1);
      expect(gateway.backup, isNull);
    },
  );
  test(
    'GivenInvalidVersionOrXml_WhenExecuted_ThenNoBackupOrMutation',
    () async {
      final original = [...gateway.content];
      for (final request in [
        const DotnetBumpRequest(),
        const DotnetBumpRequest(version: '1.2'),
        const DotnetBumpRequest(version: '1.2.3', increment: 'patch'),
      ]) {
        expect(
          await service.execute(request),
          isA<ChimeraFailure<DotnetBumpOutput>>(),
        );
        expect(gateway.content, original);
        expect(gateway.backups, 0);
      }
      gateway.content = utf8.encode('<Project>');
      expect(
        await service.execute(const DotnetBumpRequest(version: '2.0.0')),
        isA<ChimeraFailure<DotnetBumpOutput>>(),
      );
      expect(gateway.backups, 0);
    },
  );
  test('GivenFailedVerification_WhenExecuted_ThenOriginalRestoredAndBackupReported', () async {
    final original = [...gateway.content];
    gateway.failVerification = true;
    final result = await service.execute(
      const DotnetBumpRequest(increment: 'patch'),
    ) as ChimeraFailure<DotnetBumpOutput>;
    expect(result.code, 'dotnet-bump-transaction-failed');
    expect(result.details['backupPath'], '/src/App.csproj.bak');
    expect(result.details['restored'], isTrue);
    expect(gateway.content, original);
    expect(gateway.backup, original);
  });
  test('GivenWriteOrRestoreFailure_WhenExecuted_ThenNeverSuccessAndRecoverableBackupRetained', () async {
    final original = [...gateway.content];
    gateway.failWrite = true;
    gateway.failRestore = true;
    final result = await service.execute(
      const DotnetBumpRequest(increment: 'major'),
    ) as ChimeraFailure<DotnetBumpOutput>;
    expect(result.details['restored'], isFalse);
    expect(gateway.backup, original);
    expect(result.details['backupPath'], isNotNull);
  });
  test('GivenBackupCleanupFailureAfterVerification_WhenExecuted_ThenSuccessfulVersionAndRetainedBackupWarning', () async {
    gateway.failCleanup = true;
    final output = (await service.execute(
      const DotnetBumpRequest(version: '9.0.0'),
    ) as ChimeraSuccess<DotnetBumpOutput>).value;
    expect(output.backupPath, '/src/App.csproj.bak');
    expect(output.version, '9.0.0');
    expect(gateway.backup, isNotNull);
  });
}
