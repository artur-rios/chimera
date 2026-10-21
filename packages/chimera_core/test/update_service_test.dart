import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  group('ReleaseMetadataValidator', () {
    test(
      'GivenExactlySixValidFields_WhenValidated_ThenTypedMetadataIsReturned',
      () {
        final result = ReleaseMetadataValidator.validate(_metadata());

        expect(result.isValid, isTrue);
        expect(result.metadata!.releaseVersion.toString(), '1.2.3');
        expect(result.metadata!.platform, ReleasePlatform.windows);
        expect(result.metadata!.application, ReleaseApplication.cli);
        expect(result.metadata!.packageType, ReleasePackageType.installer);
      },
    );

    test('GivenAnUnknownField_WhenValidated_ThenCatalogIsRejected', () {
      final value = _metadata()..['architecture'] = 'x64';

      final result = ReleaseMetadataValidator.validate(value);

      expect(result.isValid, isFalse);
      expect(result.errors, contains('architecture'));
    });

    for (final invalidCase in <({String field, Object? value})>[
      (field: 'releaseVersion', value: '01.2.3'),
      (field: 'platform', value: 'macos'),
      (field: 'application', value: 'server'),
      (field: 'packageType', value: 'archive'),
      (field: 'downloadUrl', value: 'http://github.com/example/file.zip'),
      (field: 'downloadUrl', value: 'https://example.test/file.zip'),
      (field: 'checksum', value: 'not-a-sha256'),
    ]) {
      test(
        'GivenInvalid${invalidCase.field}_${invalidCase.value}_WhenValidated_ThenFieldIsRejected',
        () {
          final value = _metadata()..[invalidCase.field] = invalidCase.value;

          final result = ReleaseMetadataValidator.validate(value);

          expect(result.isValid, isFalse);
          expect(result.errors, contains(invalidCase.field));
        },
      );
    }
  });

  group('SemanticVersion', () {
    test('GivenSemVerPrecedenceCases_WhenCompared_ThenSpecOrderIsUsed', () {
      final ordered = <String>[
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '2.0.0',
      ].map(SemanticVersion.parse).toList();

      for (var index = 0; index < ordered.length - 1; index++) {
        expect(ordered[index].compareTo(ordered[index + 1]), lessThan(0));
      }
    });

    test('GivenBuildMetadata_WhenCompared_ThenItDoesNotAffectPrecedence', () {
      final left = SemanticVersion.parse('1.2.3+build.7');
      final right = SemanticVersion.parse('1.2.3+build.99');

      expect(left.compareTo(right), 0);
      expect(left, right);
    });

    test(
      'GivenDigitPrefixedAlphanumericPrerelease_WhenParsed_ThenItIsValid',
      () {
        final version = SemanticVersion.parse('1.0.0-1alpha.2beta');

        expect(version.toString(), '1.0.0-1alpha.2beta');
        expect(version.compareTo(SemanticVersion.parse('1.0.0')), lessThan(0));
      },
    );

    test('GivenArbitrarilyLargeNumericIdentifiers_WhenCompared_ThenTheyDoNotOverflow', () {
      final lower = SemanticVersion.parse(
        '999999999999999999999999999999.0.0-999999999999999999999999999998',
      );
      final higherCore = SemanticVersion.parse(
        '1000000000000000000000000000000.0.0-1',
      );
      final higherPrerelease = SemanticVersion.parse(
        '999999999999999999999999999999.0.0-999999999999999999999999999999',
      );

      expect(lower.compareTo(higherCore), lessThan(0));
      expect(lower.compareTo(higherPrerelease), lessThan(0));
      expect(
        lower.toString(),
        '999999999999999999999999999999.0.0-999999999999999999999999999998',
      );
    });

    test('GivenInvalidSemVer_WhenParsed_ThenAnArgumentErrorIsThrown', () {
      expect(() => SemanticVersion.parse('1.0'), throwsArgumentError);
      expect(() => SemanticVersion.parse('1.0.0-01'), throwsArgumentError);
    });
  });

  group('UpdateCheckService', () {
    test(
      'GivenCompatibleCandidates_WhenChecked_ThenNewestNewerReleaseIsAvailable',
      () async {
        final source = _FakeSource(
          ChimeraSuccess<List<Map<String, Object?>>>(<Map<String, Object?>>[
            _metadata(version: '1.4.0', platform: 'linux'),
            _metadata(version: '1.3.0'),
            _metadata(version: '2.0.0', application: 'desktop'),
            _metadata(version: '1.5.0'),
            _metadata(version: '9.0.0', packageType: 'portable'),
          ]),
        );
        final service = UpdateCheckService(source);

        final result = await service.check(
          endpoint: Uri.parse('https://api.github.com/repos/example/chimera'),
          installedVersion: '1.2.0',
          target: const UpdateTarget(
            platform: ReleasePlatform.windows,
            application: ReleaseApplication.cli,
            packageType: ReleasePackageType.installer,
          ),
        );

        final output = _success(result);
        expect(output.status, UpdateCheckStatus.available);
        expect(output.installedVersion.toString(), '1.2.0');
        expect(output.availableRelease!.releaseVersion.toString(), '1.5.0');
      },
    );

    test('GivenNoStrictlyNewerCompatibleCandidate_WhenChecked_ThenInstallationIsCurrent', () async {
      final source = _FakeSource(
        ChimeraSuccess<List<Map<String, Object?>>>(<Map<String, Object?>>[
          _metadata(version: '1.2.0+other-build'),
          _metadata(version: '1.1.9'),
          _metadata(version: '3.0.0', application: 'desktop'),
        ]),
      );
      final service = UpdateCheckService(source);

      final result = await service.check(
        endpoint: Uri.parse('https://api.github.com/repos/example/chimera'),
        installedVersion: '1.2.0+installed-build',
        target: const UpdateTarget(
          platform: ReleasePlatform.windows,
          application: ReleaseApplication.cli,
          packageType: ReleasePackageType.installer,
        ),
      );

      final output = _success(result);
      expect(output.status, UpdateCheckStatus.current);
      expect(output.availableRelease, isNull);
    });

    test(
      'GivenInvalidCatalogEntry_WhenChecked_ThenUpdateFailureIsReturned',
      () async {
        final source = _FakeSource(
          ChimeraSuccess<List<Map<String, Object?>>>(<Map<String, Object?>>[
            _metadata(),
            _metadata()..remove('checksum'),
          ]),
        );

        final result = await UpdateCheckService(source).check(
          endpoint: Uri.parse('https://api.github.com/repos/example/chimera'),
          installedVersion: '1.0.0',
          target: const UpdateTarget(
            platform: ReleasePlatform.windows,
            application: ReleaseApplication.cli,
            packageType: ReleasePackageType.installer,
          ),
        );

        final failure = _failure(result);
        expect(failure.kind, FailureKind.update);
        expect(failure.code, 'invalid-release-metadata');
        expect(failure.details, <String, Object?>{
          'index': 1,
          'fields': <String>['checksum'],
        });
      },
    );

    test(
      'GivenSourceFailure_WhenChecked_ThenSafeUpdateFailureIsReturned',
      () async {
        const secret = 'do-not-expose-body';
        final source = _FakeSource(
          const ChimeraFailure<List<Map<String, Object?>>>(
            kind: FailureKind.resource,
            code: 'http-failure',
            messageKey: 'error.httpFailure',
            details: <String, Object?>{'responseBody': secret},
          ),
        );

        final result = await UpdateCheckService(source).check(
          endpoint: Uri.parse('https://api.github.com/repos/example/chimera'),
          installedVersion: '1.0.0',
          target: const UpdateTarget(
            platform: ReleasePlatform.windows,
            application: ReleaseApplication.cli,
            packageType: ReleasePackageType.installer,
          ),
        );

        final failure = _failure(result);
        expect(failure.kind, FailureKind.update);
        expect(failure.code, 'release-metadata-source-failed');
        expect(failure.details.toString(), isNot(contains(secret)));
      },
    );

    test(
      'GivenSourceThrows_WhenChecked_ThenSafeUpdateFailureIsReturned',
      () async {
        const secret = 'transport-secret';

        final result =
            await UpdateCheckService(_ThrowingSource(StateError(secret))).check(
              endpoint: Uri.parse(
                'https://api.github.com/repos/example/chimera',
              ),
              installedVersion: '1.0.0',
              target: const UpdateTarget(
                platform: ReleasePlatform.windows,
                application: ReleaseApplication.cli,
                packageType: ReleasePackageType.installer,
              ),
            );

        final failure = _failure(result);
        expect(failure.kind, FailureKind.update);
        expect(failure.code, 'release-metadata-source-failed');
        expect(failure.details.toString(), isNot(contains(secret)));
      },
    );
  });
}

Map<String, Object?> _metadata({
  String version = '1.2.3',
  String platform = 'windows',
  String application = 'cli',
  String packageType = 'installer',
}) => <String, Object?>{
  'releaseVersion': version,
  'platform': platform,
  'application': application,
  'packageType': packageType,
  'downloadUrl':
      'https://github.com/example/chimera/releases/download/v$version/chimera.zip',
  'checksum':
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
};

UpdateCheckResult _success(ChimeraResult<UpdateCheckResult> result) =>
    result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) =>
          throw TestFailure('Unexpected failure: ${failure.code}'),
    );

ChimeraFailure<UpdateCheckResult> _failure(
  ChimeraResult<UpdateCheckResult> result,
) => result.fold(
  onSuccess: (_) => throw TestFailure('Expected an update failure.'),
  onFailure: (failure) => failure,
);

final class _FakeSource implements ReleaseMetadataSource {
  const _FakeSource(this.result);

  final ChimeraResult<List<Map<String, Object?>>> result;

  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async =>
      result;
}

final class _ThrowingSource implements ReleaseMetadataSource {
  const _ThrowingSource(this.error);

  final Object error;

  @override
  Future<ChimeraResult<List<Map<String, Object?>>>> fetch(Uri endpoint) async {
    throw error;
  }
}
