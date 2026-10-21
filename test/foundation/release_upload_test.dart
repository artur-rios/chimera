import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../../tool/validate_release_upload.dart';

void main() {
  late Directory directory;
  late List<Map<String, Object?>> assets;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('chimera-release-upload-');
    assets = <Map<String, Object?>>[];
    for (final entry in <String, String>{
      'artifact.zip': 'artifact',
      'artifact.zip.sha256': 'checksum',
      'artifact.zip.release.json': 'metadata',
    }.entries) {
      final file = File(
        '${directory.path}${Platform.pathSeparator}${entry.key}',
      )..writeAsStringSync(entry.value);
      final digest = (await sha256.bind(file.openRead()).first).toString();
      assets.add(<String, Object?>{
        'name': entry.key,
        'state': 'uploaded',
        'size': file.lengthSync(),
        'digest': 'sha256:$digest',
      });
    }
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test(
    'GivenMatchingRemoteAssets_WhenValidated_ThenDraftCanBePublished',
    () async {
      expect(
        await validateReleaseUpload(directory: directory, assets: assets),
        isEmpty,
      );
    },
  );

  test('GivenMissingUnexpectedOrIncompleteAssets_WhenValidated_ThenDraftStaysPrivate', () async {
    assets.removeAt(0);
    assets[0]['state'] = 'new';
    assets[0]['size'] = 999;
    assets[0]['digest'] = 'sha256:${'0' * 64}';
    assets.add(<String, Object?>{
      'name': 'unexpected.txt',
      'state': 'uploaded',
      'size': 1,
      'digest': 'sha256:${'1' * 64}',
    });

    final issues = await validateReleaseUpload(
      directory: directory,
      assets: assets,
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>[
        'missing-remote-asset',
        'unexpected-remote-asset',
        'remote-state',
        'remote-size',
        'remote-digest',
      ]),
    );
  });
}
