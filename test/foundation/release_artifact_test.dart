import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../../tool/write_checksums.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chimera-release-artifacts-',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('GivenNativeArtifact_WhenSidecarsAreWritten_ThenChecksumAndReleaseMetadataMatch', () async {
    final artifact = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'chimera-gui-windows-x64-1.2.3-portable.zip',
    )..writeAsStringSync('chimera');

    final outputs = await writeReleaseSidecars(
      directory: temporaryDirectory,
      version: '1.2.3',
      repository: 'artur-rios/chimera',
    );

    final expectedDigest = sha256.convert(utf8.encode('chimera')).toString();
    expect(outputs, hasLength(1));
    expect(
      File('${artifact.path}.sha256').readAsStringSync(),
      '$expectedDigest  ${artifact.uri.pathSegments.last}\n',
    );

    final metadata = jsonDecode(
      File('${artifact.path}.release.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(metadata, <String, Object?>{
      'releaseVersion': '1.2.3',
      'platform': 'windows',
      'application': 'desktop',
      'packageType': 'portable',
      'downloadUrl':
          'https://github.com/artur-rios/chimera/releases/download/v1.2.3/'
          'chimera-gui-windows-x64-1.2.3-portable.zip',
      'checksum': expectedDigest,
    });
  });

  test(
    'GivenUnsupportedArtifact_WhenSidecarsAreWritten_ThenItIsIgnored',
    () async {
      File('${temporaryDirectory.path}${Platform.pathSeparator}notes.txt')
          .writeAsStringSync('not an artifact');

      final outputs = await writeReleaseSidecars(
        directory: temporaryDirectory,
        version: '1.2.3',
        repository: 'artur-rios/chimera',
      );

      expect(outputs, isEmpty);
    },
  );
}
