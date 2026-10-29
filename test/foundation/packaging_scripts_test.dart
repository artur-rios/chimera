import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory guiDirectory;
  late File cliExecutable;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chimera-package-dry-run-',
    );
    guiDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}gui',
    )..createSync();
    File('${guiDirectory.path}${Platform.pathSeparator}chimera_gui')
        .writeAsStringSync('fixture');
    cliExecutable = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}chimera',
    )..writeAsStringSync('fixture');
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('GivenWindowsInputs_WhenPackagingDryRuns_ThenFourStableArtifactNamesArePlanned', () async {
    if (!Platform.isWindows) {
      return;
    }

    final result = await Process.run('pwsh', <String>[
      '-NoProfile',
      '-File',
      'tool/package_windows.ps1',
      '-Version',
      '1.2.3',
      '-GuiInputDirectory',
      guiDirectory.path,
      '-CliExecutable',
      cliExecutable.path,
      '-OutputDirectory',
      temporaryDirectory.path,
      '-DryRun',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(
      (result.stdout as String).split(RegExp(r'\r?\n')),
      containsAll(<String>[
        'chimera-gui-windows-x64-1.2.3-portable.zip',
        'chimera-gui-windows-x64-1.2.3-installer.exe',
        'chimera-cli-windows-x64-1.2.3-portable.zip',
        'chimera-cli-windows-x64-1.2.3-installer.exe',
      ]),
    );
  });

  test('GivenLinuxInputs_WhenPackagingDryRuns_ThenFourStableArtifactNamesArePlanned', () async {
    final shell = Platform.isWindows
        ? r'C:\Program Files\Git\bin\sh.exe'
        : '/bin/sh';
    final result = await Process.run(shell, <String>[
      'tool/package_linux.sh',
      '--version',
      '1.2.3',
      '--gui-dir',
      guiDirectory.path,
      '--cli',
      cliExecutable.path,
      '--output',
      temporaryDirectory.path,
      '--dry-run',
    ]);

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(
      (result.stdout as String).split(RegExp(r'\r?\n')),
      containsAll(<String>[
        'chimera-gui-linux-x64-1.2.3-portable.tar.gz',
        'chimera-gui-linux-x64-1.2.3-installer.deb',
        'chimera-cli-linux-x64-1.2.3-portable.tar.gz',
        'chimera-cli-linux-x64-1.2.3-installer.deb',
      ]),
    );
  });

  test('GivenLinuxGuiPackage_WhenControlFileIsBuilt_ThenRuntimeDependenciesAreDeclared', () {
    final script = File('tool/package_linux.sh').readAsStringSync();
    final releaseBuild = File('ci/release-build.sh').readAsStringSync();

    expect(
      script,
      contains(
        'Depends: libgtk-3-0, libblkid1, liblzma5, libstdc++6, '
        'pkexec | policykit-1',
      ),
    );
    expect(script, contains('Depends: pkexec | policykit-1'));
    expect(releaseBuild, contains('Smoke-test the installed Linux packages'));
    expect(releaseBuild, contains('dpkg --install'));
    expect(releaseBuild, contains('xvfb-run -a timeout 5s chimera-gui'));
  });

  test(
    'GivenWindowsCliInstaller_WhenDefined_ThenItUsesPerUserInstallation',
    () {
      final installer = File('deploy/windows/chimera_cli.iss')
          .readAsStringSync();

      expect(installer, contains('PrivilegesRequired=lowest'));
      expect(installer, contains(r'DefaultDirName={localappdata}\Programs'));
      expect(installer, contains('Root: HKCU; Subkey: "Environment"'));
      expect(installer, isNot(contains('HKEY_LOCAL_MACHINE')));
    },
  );

  test('GivenLinuxPackages_WhenBuilt_ThenTheyHaveNoMaintainerScripts', () {
    final script = File('tool/package_linux.sh').readAsStringSync();

    for (final maintainerScript in <String>[
      '/DEBIAN/preinst',
      '/DEBIAN/postinst',
      '/DEBIAN/prerm',
      '/DEBIAN/postrm',
    ]) {
      expect(script, isNot(contains(maintainerScript)));
    }
  });
}
