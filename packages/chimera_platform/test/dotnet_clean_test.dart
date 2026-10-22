import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_clean.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late Directory root;
  late DotnetCleanService service;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('chimera-clean-');
    root = await Directory(p.normalize('${sandbox.path}/src')).create();
    service = DotnetCleanService(
      NativeDotnetCleanGateway(workingDirectory: sandbox.path),
    );
  });
  tearDown(() async {
    await sandbox.delete(recursive: true);
  });
  Future<Directory> artifact(String relative) =>
      Directory(p.normalize('${root.path}/$relative')).create(recursive: true);
  Future<DotnetCleanPreview> preview([String? path]) async =>
      (await service.preview(
        root: path,
      ) as ChimeraSuccess<DotnetCleanPreview>).value;

  test(
    'GivenArtifactTree_WhenPreviewed_ThenNothingIsDeletedAndExactScopeIsShown',
    () async {
      final bin = await artifact('Project/bin');
      await File(p.join(bin.path, 'app.dll')).writeAsString('compiled');
      final source = await File(p.normalize('${root.path}/Project/App.cs'))
          .writeAsString('source');
      await artifact('Project/obj');
      await artifact('Project/bin/nested/obj');
      await artifact('Project/binary');
      final value = await preview();
      expect(value.root, root.path);
      expect(value.paths, [
        p.normalize('${root.path}/Project/bin'),
        p.normalize('${root.path}/Project/obj'),
      ]);
      expect(await bin.exists(), isTrue);
      final refused = await service.clean(value, confirmed: false);
      expect(
        (refused as ChimeraFailure<DotnetCleanReport>).code,
        'dotnet-clean-confirmation-required',
      );
      expect(await bin.exists(), isTrue);
      final report = (await service.clean(
        value,
        confirmed: true,
      ) as ChimeraSuccess<DotnetCleanReport>).value;
      expect(report.removed.length, 2);
      expect(report.retained, isEmpty);
      expect(await source.readAsString(), 'source');
      expect(
        await Directory(p.normalize('${root.path}/Project/binary')).exists(),
        isTrue,
      );
    },
  );
  test('GivenNoArtifacts_WhenCleaned_ThenSuccessfulZeroNoOp', () async {
    final report = (await service.clean(
      await preview(),
      confirmed: true,
    ) as ChimeraSuccess<DotnetCleanReport>).value;
    expect(report.removed, isEmpty);
    expect(report.retained, isEmpty);
  });
  test(
    'GivenInvalidScope_WhenPreviewed_ThenTypedValidationAndNoDeletion',
    () async {
      for (final path in [
        '',
        p.normalize('${sandbox.path}/absent'),
        '${root.path}/../src',
      ]) {
        expect(
          await service.preview(root: path),
          isA<ChimeraFailure<DotnetCleanPreview>>(),
        );
      }
      await File(p.normalize('${sandbox.path}/file')).writeAsString('keep');
      expect(
        await service.preview(root: p.normalize('${sandbox.path}/file')),
        isA<ChimeraFailure<DotnetCleanPreview>>(),
      );
    },
  );
  test('GivenLockedArtifact_WhenCleaned_ThenOtherArtifactsRemovedAndRetainedIdentified', () async {
    await artifact('Project/bin');
    await artifact('Project/obj');
    service = DotnetCleanService(
      NativeDotnetCleanGateway(
        workingDirectory: sandbox.path,
        deleteEntry: (path, directory) async {
          if (p.basename(path) == 'obj') {
            throw FileSystemException('locked', path);
          }
          if (directory) {
            await Directory(path).delete();
          } else {
            await File(path).delete();
          }
        },
      ),
    );
    final report = (await service.clean(
      await preview(),
      confirmed: true,
    ) as ChimeraSuccess<DotnetCleanReport>).value;
    expect(report.removed, [p.normalize('${root.path}/Project/bin')]);
    expect(report.retained.keys, [p.normalize('${root.path}/Project/obj')]);
    expect(report.isPartialFailure, isTrue);
  });
  test('GivenEscapingSymlink_WhenDiscovered_ThenNeverFollowed', () async {
    final outside = await Directory(p.normalize('${sandbox.path}/outside'))
        .create();
    final keep = await File(p.normalize('${outside.path}/keep'))
        .writeAsString('keep');
    await createDirectoryLink(p.normalize('${root.path}/bin'), outside.path);
    expect((await preview()).paths, isEmpty);
    expect(await keep.exists(), isTrue);
    expect(
      await service.preview(root: p.normalize('${root.path}/bin')),
      isA<ChimeraFailure<DotnetCleanPreview>>(),
    );
  });
  test('GivenArtifactReplacedByLinkAfterPreview_WhenConfirmed_ThenRetainedAndOutsideUntouched', () async {
    final bin = await artifact('Project/bin');
    final value = await preview();
    final outside = await Directory(p.normalize('${sandbox.path}/outside'))
        .create();
    final keep = await File(p.normalize('${outside.path}/keep'))
        .writeAsString('keep');
    await bin.delete();
    await createDirectoryLink(bin.path, outside.path);
    final report = (await service.clean(
      value,
      confirmed: true,
    ) as ChimeraSuccess<DotnetCleanReport>).value;
    expect(report.retained.keys, [bin.path]);
    expect(await keep.exists(), isTrue);
  });
  test('GivenLinkedAncestorOrRootSwap_WhenConfirmed_ThenFailClosed', () async {
    final bin = await artifact('Project/bin');
    final value = await preview();
    final moved = p.normalize('${sandbox.path}/original');
    await root.rename(moved);
    await createDirectoryLink(root.path, moved);
    expect(
      await service.clean(value, confirmed: true),
      isA<ChimeraFailure<DotnetCleanReport>>(),
    );
    expect(await Directory('$moved/Project/bin').exists(), isTrue);
    await Link(root.path).delete();
    await Directory(moved).rename(root.path);
    expect(await bin.exists(), isTrue);
  });
  test(
    'GivenSymlinkInsideArtifact_WhenConfirmed_ThenEntireArtifactRetained',
    () async {
      final bin = await artifact('Project/bin');
      await File(p.normalize('${bin.path}/first')).writeAsString('keep');
      await createDirectoryLink(p.normalize('${bin.path}/link'), sandbox.path);
      final report = (await service.clean(
        await preview(),
        confirmed: true,
      ) as ChimeraSuccess<DotnetCleanReport>).value;
      expect(report.retained.keys, [bin.path]);
      expect(await File(p.normalize('${bin.path}/first')).exists(), isTrue);
    },
  );
  test('GivenUnrelatedOrForgedPreview_WhenConfirmed_ThenRejected', () async {
    await artifact('Project/bin');
    final value = await preview();
    final other = DotnetCleanService(NativeDotnetCleanGateway());
    expect(
      await other.clean(value, confirmed: true),
      isA<ChimeraFailure<DotnetCleanReport>>(),
    );
  });
  test('GivenArtifactReplacedWithNewDirectory_WhenConfirmed_ThenReplacementIsRetained', () async {
    final bin = await artifact('Project/bin');
    final value = await preview();
    await bin.rename(p.normalize('${root.path}/Project/old-bin'));
    await bin.create();
    final keep = await File(p.normalize('${bin.path}/new-content'))
        .writeAsString('keep');
    final report = (await service.clean(
      value,
      confirmed: true,
    ) as ChimeraSuccess<DotnetCleanReport>).value;
    expect(report.retained.keys, [bin.path]);
    expect(await keep.exists(), isTrue);
  });
  test('GivenNewArtifactAfterPreview_WhenConfirmed_ThenOnlyPreviewedScopeIsDeleted', () async {
    await artifact('Project/bin');
    final value = await preview();
    final late = await artifact('Project/obj');
    final report = (await service.clean(
      value,
      confirmed: true,
    ) as ChimeraSuccess<DotnetCleanReport>).value;
    expect(report.removed.length, 1);
    expect(await late.exists(), isTrue);
  });
  test('GivenWindowsOrLinuxPaths_WhenScopeCompared_ThenComponentBoundariesAndCaseAreExact', () {
    expect(
      DotnetCleanScope.contains('/work/src', '/work/src/bin', separator: '/'),
      isTrue,
    );
    expect(
      DotnetCleanScope.contains('/work/src', '/work/src2/bin', separator: '/'),
      isFalse,
    );
    expect(
      DotnetCleanScope.contains(
        r'C:\work\src',
        r'C:\work\src\bin',
        separator: r'\',
      ),
      isTrue,
    );
    expect(
      DotnetCleanScope.contains(
        r'C:\work\src',
        r'C:\WORK\src\bin',
        separator: r'\',
      ),
      isFalse,
    );
    expect(
      DotnetCleanScope.contains(
        r'C:\work\src',
        r'C:\work\src2\bin',
        separator: r'\',
      ),
      isFalse,
    );
    expect(
      DotnetCleanScope.contains(
        '/work/src',
        '/work/src/../other/bin',
        separator: '/',
      ),
      isFalse,
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
