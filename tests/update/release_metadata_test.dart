import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/validate_release_metadata.dart';

void main() {
  late Map<String, Object?> validMetadata;

  setUp(() {
    validMetadata = Map<String, Object?>.from(
      jsonDecode(
        File('tests/update/fixtures/release-metadata.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );
  });

  test(
    'GivenCompatibleReleaseMetadata_WhenValidated_ThenTypedMetadataIsReturned',
    () {
      final result = ReleaseMetadataValidator.validate(validMetadata);

      expect(result.isValid, isTrue);
      expect(result.metadata!.releaseVersion, '1.2.3');
      expect(result.metadata!.platform, ReleasePlatform.windows);
      expect(result.metadata!.application, ReleaseApplication.desktop);
      expect(result.metadata!.packageType, ReleasePackageType.installer);
    },
  );

  for (final invalidCase in <({String field, Object? value})>[
    (field: 'releaseVersion', value: 'version-one'),
    (field: 'platform', value: 'macos'),
    (field: 'application', value: 'server'),
    (field: 'packageType', value: 'archive'),
    (field: 'downloadUrl', value: 'http://example.test/chimera.zip'),
    (field: 'checksum', value: 'not-a-sha256'),
  ]) {
    test(
      'GivenInvalid${invalidCase.field}_WhenValidated_ThenFieldIsRejected',
      () {
        validMetadata[invalidCase.field] = invalidCase.value;

        final result = ReleaseMetadataValidator.validate(validMetadata);

        expect(result.isValid, isFalse);
        expect(result.errors, contains(invalidCase.field));
      },
    );
  }

  test('GivenMissingField_WhenValidated_ThenFieldIsRejected', () {
    validMetadata.remove('checksum');

    final result = ReleaseMetadataValidator.validate(validMetadata);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('checksum'));
  });
}
