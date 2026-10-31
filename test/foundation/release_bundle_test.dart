import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/validate_release_bundle.dart';
import '../../tool/write_checksums.dart';

void main() {
  late Directory bundle;

  setUp(() async {
    bundle = Directory.systemTemp.createTempSync('chimera-release-bundle-');
    for (final name in expectedReleaseArtifactNames('1.2.3')) {
      File('${bundle.path}${Platform.pathSeparator}$name')
          .writeAsStringSync('fixture:$name');
    }
    await writeReleaseSidecars(
      directory: bundle,
      version: '1.2.3',
      repository: 'artur-rios/chimera',
    );
  });

  tearDown(() {
    bundle.deleteSync(recursive: true);
  });

  test(
    'GivenCompleteNativeBundle_WhenValidated_ThenEveryArtifactAndSidecarPasses',
    () async {
      expect(
        await validateReleaseBundle(
          directory: bundle,
          version: '1.2.3',
          repository: 'artur-rios/chimera',
        ),
        isEmpty,
      );
    },
  );

  test(
    'GivenMissingAndUnexpectedFiles_WhenValidated_ThenBundleIsRejected',
    () async {
      final missing = expectedReleaseArtifactNames('1.2.3').first;
      File('${bundle.path}${Platform.pathSeparator}$missing').deleteSync();
      File('${bundle.path}${Platform.pathSeparator}notes.txt')
          .writeAsStringSync('not publishable');

      final issues = await validateReleaseBundle(
        directory: bundle,
        version: '1.2.3',
        repository: 'artur-rios/chimera',
      );

      expect(
        issues,
        contains(
          isA<ReleaseBundleIssue>()
              .having((issue) => issue.code, 'code', 'missing-file')
              .having((issue) => issue.path, 'path', missing),
        ),
      );
      expect(
        issues,
        contains(
          isA<ReleaseBundleIssue>()
              .having((issue) => issue.code, 'code', 'unexpected-file')
              .having((issue) => issue.path, 'path', 'notes.txt'),
        ),
      );
    },
  );

  test('GivenArtifactChangedAfterSidecars_WhenValidated_ThenChecksumAndMetadataFail', () async {
    final artifact = expectedReleaseArtifactNames('1.2.3').first;
    File('${bundle.path}${Platform.pathSeparator}$artifact')
        .writeAsStringSync('tampered');

    final issues = await validateReleaseBundle(
      directory: bundle,
      version: '1.2.3',
      repository: 'artur-rios/chimera',
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>['checksum-mismatch', 'metadata-checksum']),
    );
  });

  test('GivenMetadataForAnotherRelease_WhenValidated_ThenExactFieldsAreRejected', () async {
    final artifact = expectedReleaseArtifactNames('1.2.3').last;
    final metadataFile = File(
      '${bundle.path}${Platform.pathSeparator}$artifact.release.json',
    );
    final metadata =
        jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>;
    metadata['releaseVersion'] = '9.9.9';
    metadata['downloadUrl'] =
        'https://github.com/artur-rios/chimera/releases/download/v9.9.9/$artifact';
    metadataFile.writeAsStringSync(jsonEncode(metadata));

    final issues = await validateReleaseBundle(
      directory: bundle,
      version: '1.2.3',
      repository: 'artur-rios/chimera',
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>['metadata-version', 'metadata-url']),
    );
  });

  test(
    'GivenMetadataWithUndocumentedField_WhenValidated_ThenSchemaIsRejected',
    () async {
      final artifact = expectedReleaseArtifactNames('1.2.3').first;
      final metadataFile = File(
        '${bundle.path}${Platform.pathSeparator}$artifact.release.json',
      );
      final metadata =
          jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>;
      metadata['credential'] = 'must-not-be-published';
      metadataFile.writeAsStringSync(jsonEncode(metadata));

      final issues = await validateReleaseBundle(
        directory: bundle,
        version: '1.2.3',
        repository: 'artur-rios/chimera',
      );

      expect(issues.map((issue) => issue.code), contains('metadata-fields'));
    },
  );

  test(
    'GivenUppercaseMetadataDigest_WhenValidated_ThenExactChecksumIsRejected',
    () async {
      final artifact = expectedReleaseArtifactNames('1.2.3').first;
      final metadataFile = File(
        '${bundle.path}${Platform.pathSeparator}$artifact.release.json',
      );
      final metadata =
          jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>;
      metadata['checksum'] = (metadata['checksum']! as String).toUpperCase();
      metadataFile.writeAsStringSync(jsonEncode(metadata));

      final issues = await validateReleaseBundle(
        directory: bundle,
        version: '1.2.3',
        repository: 'artur-rios/chimera',
      );

      expect(issues.map((issue) => issue.code), contains('metadata-checksum'));
    },
  );
}
